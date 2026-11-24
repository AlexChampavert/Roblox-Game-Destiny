-- XP, levels, shards, Order Rank, and loot (rarity + perks + inventory).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Progression = require(Shared.Config.Progression)
local Weapons = require(Shared.Config.Weapons)
local Loot = require(Shared.Config.Loot)
local Net = require(Shared.Net)

local DataService = require(script.Parent.DataService)

local ProgressionService = {}

local rng = Random.new()
local gearChanged = Instance.new("BindableEvent")
ProgressionService.GearChanged = gearChanged.Event -- (player, slot)
local leveledUp = Instance.new("BindableEvent")
ProgressionService.LeveledUp = leveledUp.Event -- (player, level)

function ProgressionService.AddXP(player: Player, amount: number)
	local profile = DataService.Get(player)
	if not profile or amount <= 0 then
		return
	end
	amount = math.floor(amount)
	if profile.classId then
		local before = DataService.GetOrderRank(profile)
		profile.classXp[profile.classId] = (profile.classXp[profile.classId] or 0) + amount
		local after = DataService.GetOrderRank(profile)
		if after > before then
			Net.event("Notify"):FireClient(player, ("ORDER RANK %d reached!"):format(after), "levelup")
			for _, upgrade in Progression.OrderUpgrades do
				if upgrade.rank == after then
					Net.event("Notify"):FireClient(player, "Unlocked: " .. upgrade.text, "levelup")
				end
			end
		end
	end

	profile.xp += amount
	local leveled = false
	while profile.level < Progression.MaxLevel and profile.xp >= Progression.xpForLevel(profile.level) do
		profile.xp -= Progression.xpForLevel(profile.level)
		profile.level += 1
		leveled = true
	end
	if profile.level >= Progression.MaxLevel then
		profile.xp = math.min(profile.xp, Progression.xpForLevel(profile.level))
	end
	DataService.Sync(player)
	if leveled then
		Net.event("Notify"):FireClient(player, ("LEVEL UP! You are now level %d"):format(profile.level), "levelup")
		leveledUp:Fire(player, profile.level)
	end
end

function ProgressionService.AddShards(player: Player, amount: number): boolean
	local profile = DataService.Get(player)
	if not profile or profile.shards + amount < 0 then
		return false
	end
	profile.shards += amount
	DataService.Sync(player)
	return true
end

-- ===== Loot =====

local weaponIds = {}
for id in Weapons do
	table.insert(weaponIds, id)
end
table.sort(weaponIds)

local function rollRarity(pinnacle: boolean): string
	local weights = if pinnacle then Loot.Weights.pinnacle else Loot.Weights.normal
	local total = 0
	for _, w in weights do
		total += w
	end
	local roll = rng:NextNumber(0, total)
	for _, id in Loot.RarityOrder do
		roll -= weights[id]
		if roll <= 0 then
			return id
		end
	end
	return "Common"
end

local function rollPerks(rarity: string): { string }
	local perks = {}
	if rarity == "Exotic" then
		table.insert(perks, "StarfallRound")
	end
	local count = Loot.Rarities[rarity].perks - (if rarity == "Exotic" then 1 else 0)
	local pool = table.clone(Loot.PerkPool)
	for _ = 1, count do
		if #pool == 0 then
			break
		end
		table.insert(perks, table.remove(pool, rng:NextInteger(1, #pool)) :: string)
	end
	return perks
end

local function addToInventory(profile, item)
	table.insert(profile.inventory, item)
	-- Over the cap: auto-dismantle the weakest common/rare items
	while #profile.inventory > Loot.InventoryCap do
		local worst, worstIndex = nil, nil
		for i, it in profile.inventory do
			if not worst or it.power < worst.power then
				worst, worstIndex = it, i
			end
		end
		table.remove(profile.inventory, worstIndex)
		profile.shards += Loot.Rarities[worst.rarity].dismantle
	end
end

-- Roll a gear drop. pinnacle = boss / mission completion reward.
-- Upgrades auto-equip (the old item goes to the inventory); others go to the inventory.
function ProgressionService.GrantGear(player: Player, pinnacle: boolean, bonusPower: number?)
	local profile = DataService.Get(player)
	if not profile then
		return nil
	end
	local slot = Progression.GearSlots[rng:NextInteger(1, #Progression.GearSlots)]
	local bonusRange = if pinnacle then Progression.PinnacleDropBonus else Progression.NormalDropBonus
	local current = DataService.GetPower(profile)
	local power =
		math.min(current + rng:NextInteger(bonusRange[1], bonusRange[2]) + (bonusPower or 0), Progression.MaxPower)
	local rarity = rollRarity(pinnacle)
	if slot == "armor" and rarity == "Exotic" then
		rarity = "Legendary" -- exotics are weapons only (for now)
	end

	local item = {
		uid = DataService.NewUid(profile),
		slot = slot,
		weaponId = if slot ~= "armor" then weaponIds[rng:NextInteger(1, #weaponIds)] else nil,
		power = power,
		rarity = rarity,
		perks = if slot ~= "armor" then rollPerks(rarity) else {},
	}

	local equipped = false
	if power > profile.gear[slot].power then
		addToInventory(profile, profile.gear[slot])
		profile.gear[slot] = item
		equipped = true
	else
		addToInventory(profile, item)
	end
	DataService.Sync(player)
	if equipped then
		gearChanged:Fire(player, slot)
	end

	Net.event("Loot"):FireClient(player, {
		slot = slot,
		power = power,
		rarity = rarity,
		perks = item.perks,
		weaponName = if item.weaponId then Weapons[item.weaponId].name else "Armor",
		pinnacle = pinnacle,
		equipped = equipped,
	})
	return item
end

local function findItem(profile, uid: string): (any, number?)
	for i, it in profile.inventory do
		if it.uid == uid then
			return it, i
		end
	end
	return nil, nil
end

function ProgressionService.Equip(player: Player, uid: string): boolean
	local profile = DataService.Get(player)
	if not profile then
		return false
	end
	local item, index = findItem(profile, uid)
	if not item or not index then
		return false
	end
	table.remove(profile.inventory, index)
	table.insert(profile.inventory, profile.gear[item.slot])
	profile.gear[item.slot] = item
	DataService.Sync(player)
	gearChanged:Fire(player, item.slot)
	return true
end

function ProgressionService.Dismantle(player: Player, uid: string): boolean
	local profile = DataService.Get(player)
	if not profile then
		return false
	end
	local item, index = findItem(profile, uid)
	if not item or not index then
		return false
	end
	table.remove(profile.inventory, index)
	local value = Loot.Rarities[item.rarity].dismantle
	profile.shards += value
	DataService.Sync(player)
	Net.event("Notify"):FireClient(player, ("Dismantled for %d Shards"):format(value), "loot")
	return true
end

return ProgressionService
