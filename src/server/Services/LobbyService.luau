-- Hub-side systems: fireteams (up to 3), invites, launching missions into reserved servers,
-- and the GetState call the menus use.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Missions = require(Shared.Config.Missions)
local Progression = require(Shared.Config.Progression)
local Story = require(Shared.Config.Story)
local Net = require(Shared.Net)

local DataService = require(script.Parent.DataService)
local StoryService = require(script.Parent.StoryService)
local MissionService = require(script.Parent.MissionService)
local MatchmakingService = require(script.Parent.MatchmakingService)
local BountyService = require(script.Parent.BountyService)
local Security = require(script.Parent.Security)

local LobbyService = {}

type Team = { id: number, leader: Player, members: { Player }, launching: boolean }

local teams: { [number]: Team } = {}
local teamOf: { [Player]: Team } = {}
local invites: { [Player]: { [number]: boolean } } = {}
local nextTeamId = 0

local function notify(player: Player, text: string, kind: string?)
	Net.event("Notify"):FireClient(player, text, kind or "info")
end

local function memberInfo(p: Player)
	return {
		userId = p.UserId,
		name = p.DisplayName,
		level = p:GetAttribute("Level") or 1,
		power = p:GetAttribute("Power") or 10,
		classId = p:GetAttribute("ClassId"),
	}
end

local function teamState(team: Team?)
	if not team then
		return { inTeam = false }
	end
	local list = {}
	for _, m in team.members do
		table.insert(list, memberInfo(m))
	end
	return { inTeam = true, teamId = team.id, leaderId = team.leader.UserId, members = list }
end

local function broadcast(team: Team)
	local state = teamState(team)
	for _, m in team.members do
		Net.event("FireteamUpdate"):FireClient(m, state)
	end
end

local function createTeam(leader: Player): Team
	nextTeamId += 1
	local team = { id = nextTeamId, leader = leader, members = { leader }, launching = false }
	teams[team.id] = team
	teamOf[leader] = team
	return team
end

local function leaveTeam(player: Player)
	local team = teamOf[player]
	if not team then
		return
	end
	teamOf[player] = nil
	local index = table.find(team.members, player)
	if index then
		table.remove(team.members, index)
	end
	Net.event("FireteamUpdate"):FireClient(player, teamState(nil))
	if #team.members <= 1 then
		-- Disband
		for _, m in team.members do
			teamOf[m] = nil
			Net.event("FireteamUpdate"):FireClient(m, teamState(nil))
		end
		teams[team.id] = nil
		return
	end
	if team.leader == player then
		team.leader = team.members[1]
		notify(team.leader, "You are now the fireteam leader.")
	end
	broadcast(team)
end

-- Why a player can't launch a mission (nil = can launch)
function LobbyService.LockReason(player: Player, missionId: string): string?
	local def = Missions.Defs[missionId]
	local profile = DataService.Get(player)
	if not def or not profile then
		return "Unavailable"
	end
	if Story.currentWeek() < def.unlockWeek then
		return ("Unlocks in week %d"):format(def.unlockWeek)
	end
	if def.requires and not profile.completed[def.requires] then
		return ("Complete %s first"):format(Missions.Defs[def.requires].name)
	end
	if profile.level < def.requiredLevel then
		return ("Requires level %d"):format(def.requiredLevel)
	end
	if not profile.classId then
		return "Pick a class first"
	end
	return nil
end

local function getState(player: Player)
	local profile = DataService.WaitFor(player)
	if not profile then
		return nil
	end
	local missions = {}
	for _, id in Missions.Order do
		table.insert(missions, {
			id = id,
			lockReason = LobbyService.LockReason(player, id),
			completed = profile.completed[id] or 0,
		})
	end
	local others = {}
	for _, p in Players:GetPlayers() do
		if p ~= player then
			table.insert(others, memberInfo(p))
		end
	end
	return {
		level = profile.level,
		power = DataService.GetPower(profile),
		shards = profile.shards,
		classId = profile.classId,
		missions = missions,
		chapter = StoryService.GetChapterInfo(),
		fireteam = teamState(teamOf[player]),
		players = others,
		stats = profile.stats,
		maxFireteam = Progression.MaxFireteamSize,
		gear = profile.gear,
		inventory = profile.inventory,
		bounties = BountyService.GetList(player),
		orderRank = DataService.GetOrderRank(profile),
		classXp = profile.classXp,
		cosmetics = profile.cosmetics,
		matchmaking = MatchmakingService.IsQueued(player),
	}
end

local function launch(player: Player, missionId: string)
	if workspace:GetAttribute("Mode") ~= "Hub" or MissionService.IsActive() then
		return
	end
	MatchmakingService.Cancel(player, true)
	local team = teamOf[player]
	if team and team.leader ~= player then
		notify(player, "Only the fireteam leader can launch missions.", "error")
		return
	end
	local reason = LobbyService.LockReason(player, missionId)
	if reason then
		notify(player, reason, "error")
		return
	end
	local members = if team then table.clone(team.members) else { player }
	for _, m in members do
		if not m:GetAttribute("ClassId") then
			notify(player, m.DisplayName .. " needs to pick a class first.", "error")
			return
		end
	end
	if team then
		if team.launching then
			return
		end
		team.launching = true
	end

	local def = Missions.Defs[missionId]
	for _, m in members do
		notify(m, ("Launching %s..."):format(def.name), "info")
	end

	if RunService:IsStudio() then
		-- Teleports don't work in Studio: run the mission in this server instead
		for _, m in members do
			notify(m, "[Studio] Running mission locally.", "info")
		end
		if team then
			team.launching = false
		end
		MissionService.Start(missionId)
		return
	end

	-- Save first so the mission server loads up-to-date data
	for _, m in members do
		MatchmakingService.Cancel(m, true)
		DataService.Save(m, true) -- release the session lock so the mission server can load fast
	end

	local options = Instance.new("TeleportOptions")
	options.ShouldReserveServer = true
	options:SetTeleportData({ missionId = missionId, partySize = #members })
	local ok, err
	for _ = 1, 3 do
		ok, err = pcall(function()
			TeleportService:TeleportAsync(game.PlaceId, members, options)
		end)
		if ok then
			break
		end
		task.wait(2)
	end
	if not ok then
		warn("[LobbyService] launch failed:", err)
		for _, m in members do
			notify(m, "Launch failed, try again.", "error")
		end
		if team then
			team.launching = false
		end
	end
end

local function onAction(player: Player, action: any, arg: any)
	if action == "Invite" then
		local target = type(arg) == "number" and Players:GetPlayerByUserId(arg)
		if not target or target == player then
			return
		end
		local team = teamOf[player] or createTeam(player)
		if team.leader ~= player then
			notify(player, "Only the leader can invite.", "error")
			return
		end
		if #team.members >= Progression.MaxFireteamSize then
			notify(player, "Your fireteam is full.", "error")
			return
		end
		if teamOf[target] == team then
			return
		end
		invites[target] = invites[target] or {}
		invites[target][team.id] = true
		Net.event("FireteamUpdate"):FireClient(target, { invite = { teamId = team.id, fromName = player.DisplayName } })
		notify(player, "Invite sent to " .. target.DisplayName)
		broadcast(team)
	elseif action == "Accept" then
		local team = type(arg) == "number" and teams[arg]
		if not team or not (invites[player] and invites[player][team.id]) then
			notify(player, "That invite expired.", "error")
			return
		end
		invites[player][team.id] = nil
		if #team.members >= Progression.MaxFireteamSize then
			notify(player, "That fireteam is full.", "error")
			return
		end
		leaveTeam(player)
		table.insert(team.members, player)
		teamOf[player] = team
		for _, m in team.members do
			notify(m, player.DisplayName .. " joined the fireteam.")
		end
		broadcast(team)
	elseif action == "Decline" then
		if type(arg) == "number" and invites[player] then
			invites[player][arg] = nil
		end
	elseif action == "Leave" then
		leaveTeam(player)
	elseif action == "Kick" then
		local team = teamOf[player]
		local target = type(arg) == "number" and Players:GetPlayerByUserId(arg)
		if team and target and team.leader == player and teamOf[target] == team then
			leaveTeam(target)
			notify(target, "You were removed from the fireteam.")
		end
	end
end

function LobbyService.Start()
	Net.func("GetState").OnServerInvoke = getState
	Net.event("FireteamAction").OnServerEvent:Connect(Security.Guard("FireteamAction", 3, onAction))
	Net.event("LaunchMission").OnServerEvent:Connect(Security.Guard("LaunchMission", 1, function(player, missionId)
		if type(missionId) == "string" then
			launch(player, missionId)
		end
	end))

	-- Matchmaking needs these, injected here to avoid a require cycle
	MatchmakingService.LockReason = LobbyService.LockReason
	MatchmakingService.IsInFireteam = function(player: Player): boolean
		local team = teamOf[player]
		return team ~= nil and #team.members > 1
	end
	MatchmakingService.LaunchLocal = function(missionId: string)
		MissionService.Start(missionId)
	end
	Players.PlayerRemoving:Connect(function(player)
		leaveTeam(player)
		invites[player] = nil
	end)
	TeleportService.TeleportInitFailed:Connect(function(player, result, message)
		warn("[LobbyService] teleport failed for", player.Name, result, message)
		notify(player, "Teleport failed: " .. tostring(message), "error")
		local team = teamOf[player]
		if team then
			team.launching = false
		end
	end)
end

return LobbyService
