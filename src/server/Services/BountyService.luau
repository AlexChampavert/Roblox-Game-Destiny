-- Daily + weekly bounties: 3 of each per player, rerolled at the UTC day/week boundary.
-- Completed bounties pay out automatically.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Bounties = require(Shared.Config.Bounties)
local Net = require(Shared.Net)

local DataService = require(script.Parent.DataService)
local ProgressionService = require(script.Parent.ProgressionService)
local EnemyService = require(script.Parent.EnemyService)

local BountyService = {}

local DAY = 86400
local WEEK_OFFSET = 4 * DAY -- epoch was a Thursday: weeks reset on Monday 00:00 UTC

local function currentDay(): number
	return math.floor(os.time() / DAY)
end

local function currentWeek(): number
	return math.floor((os.time() - WEEK_OFFSET) / (7 * DAY))
end

local function pick(pool, count: number, seed: number)
	local rng = Random.new(seed)
	local indexes = {}
	for i = 1, #pool do
		table.insert(indexes, i)
	end
	local list = {}
	for _ = 1, math.min(count, #indexes) do
		local idx = table.remove(indexes, rng:NextInteger(1, #indexes)) :: number
		table.insert(list, { id = pool[idx].id, progress = 0, done = false })
	end
	return list
end

local function refresh(player: Player, profile)
	local b = profile.bounties
	local day, week = currentDay(), currentWeek()
	if b.day ~= day then
		b.day = day
		b.daily = pick(Bounties.Daily, Bounties.PerPeriod, day * 7919 + player.UserId)
	end
	if b.week ~= week then
		b.week = week
		b.weekly = pick(Bounties.Weekly, Bounties.PerPeriod, week * 104729 + player.UserId)
	end
end

function BountyService.Track(player: Player, event: string, amount: number, faction: string?)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	refresh(player, profile)
	for _, list in { profile.bounties.daily, profile.bounties.weekly } do
		for _, entry in list do
			local def = Bounties.find(entry.id)
			if def and not entry.done and def.event == event and (def.faction == nil or def.faction == faction) then
				entry.progress = math.min(def.target, entry.progress + amount)
				if entry.progress >= def.target then
					entry.done = true
					ProgressionService.AddXP(player, def.xp)
					ProgressionService.AddShards(player, def.shards)
					Net.event("Notify"):FireClient(
						player,
						("BOUNTY COMPLETE: %s  (+%d XP, +%d Shards)"):format(def.text, def.xp, def.shards),
						"levelup"
					)
				end
			end
		end
	end
end

-- For the Bounties menu
function BountyService.GetList(player: Player)
	local profile = DataService.Get(player)
	if not profile then
		return {}
	end
	refresh(player, profile)
	local out = {}
	for period, list in { daily = profile.bounties.daily, weekly = profile.bounties.weekly } do
		for _, entry in list do
			local def = Bounties.find(entry.id)
			if def then
				table.insert(out, {
					period = period,
					text = def.text,
					progress = entry.progress,
					target = def.target,
					done = entry.done,
					xp = def.xp,
					shards = def.shards,
				})
			end
		end
	end
	table.sort(out, function(a, b)
		return a.period < b.period
	end)
	return out
end

function BountyService.Start()
	DataService.Loaded:Connect(refresh)

	EnemyService.Died:Connect(function(model: Model, def)
		local killer = Players:GetPlayerByUserId(model:GetAttribute("LastHitBy") or 0)
		if killer then
			BountyService.Track(killer, "Kill", 1, def.faction)
			if model:GetAttribute("LastHitHeadshot") then
				BountyService.Track(killer, "Headshot", 1, def.faction)
			end
			if model:GetAttribute("LastHitSource") == "Ability" then
				BountyService.Track(killer, "AbilityKill", 1, def.faction)
			end
		end
		if def.isBoss then
			for _, p in Players:GetPlayers() do -- boss kills count for the whole fireteam
				BountyService.Track(p, "BossKill", 1, def.faction)
			end
		end
	end)
end

return BountyService
