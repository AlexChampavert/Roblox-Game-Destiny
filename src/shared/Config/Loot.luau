--!strict
-- Loot: rarities, weapon perks, dismantle values, order vendor prices.

local Loot = {}

export type Rarity = { id: string, name: string, color: Color3, perks: number, dismantle: number }

Loot.Rarities = {
	Common = { id = "Common", name = "Common", color = Color3.fromRGB(200, 200, 200), perks = 0, dismantle = 5 },
	Rare = { id = "Rare", name = "Rare", color = Color3.fromRGB(80, 140, 255), perks = 1, dismantle = 15 },
	Legendary = { id = "Legendary", name = "Legendary", color = Color3.fromRGB(190, 90, 255), perks = 2, dismantle = 40 },
	Exotic = { id = "Exotic", name = "Exotic", color = Color3.fromRGB(255, 205, 60), perks = 1, dismantle = 100 },
} :: { [string]: Rarity }

Loot.RarityOrder = { "Common", "Rare", "Legendary", "Exotic" }

-- Drop weights (higher = more likely)
Loot.Weights = {
	normal = { Common = 60, Rare = 30, Legendary = 9, Exotic = 1 },
	pinnacle = { Common = 10, Rare = 40, Legendary = 44, Exotic = 6 },
}

-- Weapon perks. Effects are implemented in CombatService (search for the perk id).
Loot.Perks = {
	DeepMag = { name = "Deep Mag", description = "+30% magazine size." },
	Outlaw = { name = "Outlaw", description = "Reload 25% faster." },
	Rampage = { name = "Rampage", description = "Kills grant +10% damage for 5s (stacks 3x)." },
	Headseeker = { name = "Headseeker", description = "+30% headshot damage." },
	ExplosivePayload = { name = "Explosive Payload", description = "Hits splash 25% damage to nearby enemies." },
	KillClip = { name = "Kill Clip", description = "Reloading after a kill gives +25% damage for 5s." },
}
Loot.PerkPool = { "DeepMag", "Outlaw", "Rampage", "Headseeker", "ExplosivePayload", "KillClip" }

-- Exotic-only perk
Loot.ExoticPerks = {
	StarfallRound = { name = "Starfall Round", description = "Every 6th hit calls down a star fragment (80 dmg, small area)." },
}

Loot.InventoryCap = 40

-- Order vendors (one per class hall)
Loot.Vendor = {
	EngramCost = 200, -- random gear at your power +1..3
	ArmorStyleCost = 500, -- order armor colors (cosmetic)
}

return Loot
