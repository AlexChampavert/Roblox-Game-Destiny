-- "Find Fireteam": cross-server matchmaking for solo players.
--  * Each queued player is an entry in a MemoryStore sorted map per mission (expires after 2 min,
--    refreshed while waiting).
--  * Every few seconds ONE hub server (claimed with a short MemoryStore lock) groups up to 3
--    entries, reserves a mission server and publishes the match with MessagingService.
--  * Every hub server listens and teleports its own matched players.
--  * Nobody else after MatchmakingSoloAfter seconds → launch solo.

local MemoryStoreService = game:GetService("MemoryStoreService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Missions = require(Shared.Config.Missions)
local Progression = require(Shared.Config.Progression)
local Net = require(Shared.Net)

local DataService = require(script.Parent.DataService)
local Security = require(script.Parent.Security)

local MatchmakingService = {}

local TOPIC = "StarfallMatch"
local ENTRY_TTL = 120
local LOOP_INTERVAL = 4

-- Injected by LobbyService (avoids a require cycle)
MatchmakingService.LockReason = function(_player: Player, _missionId: string): string?
	return nil
end
MatchmakingService.IsInFireteam = function(_player: Player): boolean
	return false
end
MatchmakingService.LaunchLocal = function(_missionId: string) end

local queued: { [Player]: { missionId: string, since: number, refreshed: number } } = {}

local function notify(player: Player, text: string, kind: string?)
	Net.event("Notify"):FireClient(player, text, kind or "info")
end

local function mapFor(missionId: string): MemoryStoreSortedMap
	return MemoryStoreService:GetSortedMap("MM_" .. missionId)
end

function MatchmakingService.IsQueued(player: Player): string?
	local q = queued[player]
	return q and q.missionId
end

local function writeEntry(player: Player, missionId: string, since: number)
	pcall(function()
		mapFor(missionId):SetAsync(tostring(player.UserId), { userId = player.UserId, jobId = game.JobId, t = since }, ENTRY_TTL)
	end)
end

function MatchmakingService.Join(player: Player, missionId: string)
	if workspace:GetAttribute("Mode") ~= "Hub" or not Missions.Defs[missionId] or queued[player] then
		return
	end
	local reason = MatchmakingService.LockReason(player, missionId)
	if reason then
		notify(player, reason, "error")
		return
	end
	if MatchmakingService.IsInFireteam(player) then
		notify(player, "You're in a fireteam: launch together from the Mission Table instead.", "error")
		return
	end
	if RunService:IsStudio() then
		notify(player, "[Studio] No other servers to match with: launching solo.")
		MatchmakingService.LaunchLocal(missionId)
		return
	end
	local now = os.time()
	queued[player] = { missionId = missionId, since = now, refreshed = now }
	writeEntry(player, missionId, now)
	notify(player, ("Searching for a fireteam: %s..."):format(Missions.Defs[missionId].name))
	player:SetAttribute("Matchmaking", missionId)
end

function MatchmakingService.Cancel(player: Player, silent: boolean?)
	local q = queued[player]
	if not q then
		return
	end
	queued[player] = nil
	player:SetAttribute("Matchmaking", nil)
	pcall(function()
		mapFor(q.missionId):RemoveAsync(tostring(player.UserId))
	end)
	if not silent then
		notify(player, "Matchmaking cancelled.")
	end
end

-- Try to become the matchmaker for this mission for a few seconds
local function claim(missionId: string): boolean
	local ok, owner = pcall(function()
		return MemoryStoreService:GetSortedMap("MM_Lock"):UpdateAsync(missionId, function(old)
			if old ~= nil and old ~= game.JobId then
				return nil
			end
			return game.JobId
		end, LOOP_INTERVAL + 2)
	end)
	return ok and owner == game.JobId
end

local function matchmake(missionId: string)
	if not claim(missionId) then
		return
	end
	local ok, entries = pcall(function()
		return mapFor(missionId):GetRangeAsync(Enum.SortDirection.Ascending, Progression.MaxFireteamSize)
	end)
	if not ok or not entries or #entries == 0 then
		return
	end
	local oldest = math.huge
	for _, e in entries do
		oldest = math.min(oldest, e.value.t or os.time())
	end
	local enough = #entries >= 2 or os.time() - oldest >= Progression.MatchmakingSoloAfter
	if not enough then
		return
	end
	local userIds = {}
	for _, e in entries do
		table.insert(userIds, e.value.userId)
		pcall(function()
			mapFor(missionId):RemoveAsync(e.key)
		end)
	end
	local reserved, code = pcall(function()
		return TeleportService:ReserveServer(game.PlaceId)
	end)
	if not reserved then
		warn("[Matchmaking] ReserveServer failed:", code)
		return
	end
	pcall(function()
		MessagingService:PublishAsync(TOPIC, { code = code, missionId = missionId, userIds = userIds })
	end)
end

local function onMatch(message)
	local data = message.Data
	if type(data) ~= "table" or type(data.userIds) ~= "table" then
		return
	end
	local group = {}
	for _, userId in data.userIds do
		local p = Players:GetPlayerByUserId(userId)
		if p and queued[p] and queued[p].missionId == data.missionId then
			queued[p] = nil
			p:SetAttribute("Matchmaking", nil)
			table.insert(group, p)
		end
	end
	if #group == 0 then
		return
	end
	for _, p in group do
		notify(p, ("Fireteam found (%d players)! Launching..."):format(#data.userIds), "levelup")
		DataService.Save(p, true)
	end
	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = data.code
	options:SetTeleportData({ missionId = data.missionId, partySize = #data.userIds })
	local ok, err = pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, group, options)
	end)
	if not ok then
		warn("[Matchmaking] teleport failed:", err)
		for _, p in group do
			notify(p, "Couldn't join the fireteam, try again.", "error")
		end
	end
end

function MatchmakingService.Start()
	Net.event("Matchmaking").OnServerEvent:Connect(Security.Guard("Matchmaking", 2, function(player, action, missionId)
		if action == "Join" and type(missionId) == "string" then
			MatchmakingService.Join(player, missionId)
		elseif action == "Cancel" then
			MatchmakingService.Cancel(player)
		end
	end))
	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.Cancel(player, true)
	end)

	if workspace:GetAttribute("Mode") ~= "Hub" or RunService:IsStudio() then
		return
	end
	pcall(function()
		MessagingService:SubscribeAsync(TOPIC, onMatch)
	end)

	task.spawn(function()
		while true do
			task.wait(LOOP_INTERVAL)
			local missionsHere: { [string]: boolean } = {}
			local now = os.time()
			for player, q in queued do
				missionsHere[q.missionId] = true
				if now - q.refreshed > 30 then -- keep the entry alive while waiting
					q.refreshed = now
					writeEntry(player, q.missionId, q.since)
				end
			end
			for missionId in missionsHere do
				task.spawn(matchmake, missionId)
			end
		end
	end)
end

return MatchmakingService
