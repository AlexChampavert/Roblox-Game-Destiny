-- Player save data with SESSION LOCKING (no data loss / duplication when teleporting
-- between the hub and mission servers).
--
-- How the lock works: the saved record is { profile = {...}, lock = { jobId, time } }.
-- A server only loads a record if nobody else holds a fresh lock; it then writes its own lock.
-- Saves refresh the lock, leaving releases it. Locks older than LOCK_STALE are stolen
-- (crashed server). Same idea as ProfileStore, with no dependency.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Progression = require(Shared.Config.Progression)

local STORE_NAME = "StarfallProfiles_v2"
local AUTOSAVE_INTERVAL = 60
local LOCK_STALE = 150 -- seconds: a lock older than this belongs to a dead server
local LOAD_ATTEMPTS = 12 -- ~18s of waiting for the previous server to release

local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[DataService] DataStore unavailable (enable Studio API access to test saving):", result)
	end
end

local DataService = {}

local profiles: { [Player]: any } = {}
local noSave: { [Player]: boolean } = {}
local loadedEvent = Instance.new("BindableEvent")
DataService.Loaded = loadedEvent.Event -- fires (player, profile)

local function starterItem(slot: string)
	return { uid = slot .. "_starter", slot = slot, weaponId = nil, power = Progression.StartPower, rarity = "Common", perks = {} }
end

local function defaultProfile()
	return {
		version = 2,
		level = 1,
		xp = 0,
		shards = 0,
		classId = nil,
		classXp = {}, -- [classId] = xp → Order Rank
		gear = { -- equipped items (weaponId nil = class starting weapon)
			primary = starterItem("primary"),
			secondary = starterItem("secondary"),
			armor = starterItem("armor"),
		},
		inventory = {}, -- unequipped items (see Loot.InventoryCap)
		nextUid = 1,
		completed = {}, -- [missionId] = clears
		storyFlags = {}, -- [flag] = true
		bounties = { day = 0, daily = {}, week = 0, weekly = {} },
		cosmetics = { orderArmor = {} }, -- [classId] = true
		stats = { kills = 0, missions = 0, deaths = 0, revives = 0 },
	}
end

-- Fill missing keys from the default (keeps old saves working when fields are added)
local function reconcile(data: any, template: any)
	for key, value in template do
		if data[key] == nil then
			if type(value) == "table" then
				data[key] = table.clone(value)
				reconcile(data[key], value)
			else
				data[key] = value
			end
		elseif type(value) == "table" and type(data[key]) == "table" and next(value) ~= nil then
			reconcile(data[key], value)
		end
	end
	return data
end

local function keyFor(player: Player): string
	return "u_" .. player.UserId
end

function DataService.GetPower(profile): number
	local g = profile.gear
	return math.floor((g.primary.power + g.secondary.power + g.armor.power) / 3)
end

function DataService.GetOrderRank(profile, classId: string?): number
	local id = classId or profile.classId
	if not id then
		return 0
	end
	return Progression.orderRank(profile.classXp[id] or 0)
end

-- Mirror the fields the HUD needs onto Player attributes (auto-replicated)
function DataService.Sync(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	player:SetAttribute("Level", profile.level)
	player:SetAttribute("XP", profile.xp)
	player:SetAttribute("XPNext", Progression.xpForLevel(profile.level))
	player:SetAttribute("Shards", profile.shards)
	player:SetAttribute("Power", DataService.GetPower(profile))
	player:SetAttribute("ClassId", profile.classId)
	player:SetAttribute("OrderRank", DataService.GetOrderRank(profile))
end

function DataService.Get(player: Player)
	return profiles[player]
end

function DataService.WaitFor(player: Player)
	while player.Parent and not profiles[player] do
		task.wait(0.1)
	end
	return profiles[player]
end

local function isLockedByOther(record: any): boolean
	local lock = record and record.lock
	return lock ~= nil and lock.jobId ~= game.JobId and (os.time() - (lock.time or 0)) < LOCK_STALE
end

local function load(player: Player)
	local profile = nil
	local failed = false
	if store then
		for attempt = 1, LOAD_ATTEMPTS do
			local steal = attempt == LOAD_ATTEMPTS
			local lockedOut = false
			local ok, result = pcall(function()
				return (store :: DataStore):UpdateAsync(keyFor(player), function(record)
					record = record or {}
					if isLockedByOther(record) and not steal then
						lockedOut = true
						return nil -- cancel: another server still owns this player
					end
					record.lock = { jobId = game.JobId, time = os.time() }
					return record
				end)
			end)
			if ok and not lockedOut then
				profile = result and result.profile
				failed = false
				break
			end
			failed = not ok
			if not ok then
				warn(("[DataService] load attempt %d failed for %s: %s"):format(attempt, player.Name, tostring(result)))
			end
			task.wait(1.5)
			if not player.Parent then
				return
			end
		end
	end
	if failed then
		noSave[player] = true -- never overwrite a save we couldn't read
		warn("[DataService] Using a temporary profile for", player.Name, "(won't be saved)")
	end
	if not player.Parent then
		return
	end
	profile = reconcile(profile or {}, defaultProfile())
	profiles[player] = profile
	DataService.Sync(player)
	loadedEvent:Fire(player, profile)
end

-- release = true when the player is leaving this server
function DataService.Save(player: Player, release: boolean?)
	local profile = profiles[player]
	if not profile or not store or noSave[player] then
		return
	end
	for attempt = 1, 3 do
		local ok, err = pcall(function()
			(store :: DataStore):UpdateAsync(keyFor(player), function(record)
				record = record or {}
				if isLockedByOther(record) then
					return nil -- someone stole the session; don't clobber their newer data
				end
				record.profile = profile
				record.lock = if release then nil else { jobId = game.JobId, time = os.time() }
				return record
			end)
		end)
		if ok then
			return
		end
		warn(("[DataService] save attempt %d failed for %s: %s"):format(attempt, player.Name, tostring(err)))
		task.wait(1)
	end
end

function DataService.NewUid(profile): string
	local uid = "i" .. profile.nextUid
	profile.nextUid += 1
	return uid
end

function DataService.Start()
	Players.PlayerAdded:Connect(load)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		DataService.Save(player, true)
		profiles[player] = nil
		noSave[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for player in profiles do
				task.spawn(DataService.Save, player)
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				DataService.Save(player, true)
				pending -= 1
			end)
		end
		local start = os.clock()
		while pending > 0 and os.clock() - start < 25 do
			task.wait(0.1)
		end
	end)
end

return DataService
