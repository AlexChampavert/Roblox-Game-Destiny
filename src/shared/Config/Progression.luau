--!strict
-- Levels, power, rewards and super charge tuning.

local Progression = {}

Progression.MaxLevel = 30
Progression.StartPower = 10
Progression.MaxPower = 50 -- Season 1 cap

-- XP needed to go from level n to n+1
function Progression.xpForLevel(level: number): number
	return math.floor(100 * level ^ 1.5)
end

-- Damage multiplier from power difference (player vs mission)
function Progression.powerMultiplier(playerPower: number, missionPower: number): number
	return math.clamp(1 + (playerPower - missionPower) * 0.02, 0.5, 1.3)
end

-- Gear drops: new item power = current power + random in range, capped
Progression.NormalDropBonus = { 0, 2 }
Progression.PinnacleDropBonus = { 3, 5 }
Progression.DropChancePerKill = 0.04 -- chance an enemy kill drops gear (non-boss)

Progression.GearSlots = { "primary", "secondary", "armor" }

-- Super charge (0-100)
Progression.SuperChargePerKill = 4
Progression.SuperChargePerBossDamagePct = 25 -- dealing 1% boss health gives 0.25 charge
Progression.SuperChargePerSecond = 0.6

-- Enemy scaling per extra fireteam member
Progression.HealthScalePerExtraPlayer = 0.6
Progression.ExtraEnemiesPerExtraPlayer = 1

-- Fireteam
Progression.MaxFireteamSize = 3

-- Order Rank (per class, from class XP). Upgrades unlock at these ranks.
Progression.MaxOrderRank = 20
function Progression.xpForOrderRank(rank: number): number
	return math.floor(300 * rank ^ 1.7) -- cumulative class XP needed
end
function Progression.orderRank(classXp: number): number
	local rank = 0
	while rank < Progression.MaxOrderRank and classXp >= Progression.xpForOrderRank(rank + 1) do
		rank += 1
	end
	return rank
end
Progression.OrderUpgrades = {
	{ rank = 5, id = "QCooldown", text = "Ability 1 (Q) cooldown -15%" },
	{ rank = 10, id = "ECooldown", text = "Ability 2 (E) cooldown -15%" },
	{ rank = 15, id = "AbilityDamage", text = "Ability damage +20%" },
	{ rank = 20, id = "SuperGain", text = "Super charges 25% faster" },
}

-- Revive
Progression.DownedTime = 15 -- seconds before bleeding out
Progression.ReviveHold = 3
Progression.ReviveHealth = 0.4 -- fraction of max health after revive

-- Matchmaking
Progression.MatchmakingSoloAfter = 45 -- launch alone if nobody joins after this many seconds

return Progression
