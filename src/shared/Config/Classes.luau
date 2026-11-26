--!strict
-- Class definitions. Pure data: abilities are implemented in server/Services/AbilityService.
-- Keys: Q = ability 1, E = ability 2 (movement/utility), G = grenade, V = melee, F = super.
-- element: the class's elemental damage type (see Config/Elements.luau)

export type AbilityDef = {
	id: string,
	name: string,
	description: string,
	cooldown: number, -- seconds (supers use charge instead, cooldown ignored)
}

export type ClassDef = {
	id: string,
	name: string,
	role: string,
	color: Color3,
	maxHealth: number,
	walkSpeed: number,
	passive: { id: string, name: string, description: string },
	element: string,
	abilities: { Q: AbilityDef, E: AbilityDef, F: AbilityDef, G: AbilityDef, V: AbilityDef },
	startingWeapons: { primary: string, secondary: string, heavy: string },
	hall: { name: string, lore: string, centerpiece: string }, -- class hall on the Meridian
}

local Classes: { [string]: ClassDef } = {
	Bulwark = {
		id = "Bulwark",
		name = "Bulwark",
		role = "Tank / Frontline",
		color = Color3.fromRGB(230, 150, 60),
		maxHealth = 150,
		walkSpeed = 15,
		element = "Ember",
		passive = { id = "IronSkin", name = "Iron Skin", description = "Take 15% less damage." },
		abilities = {
			Q = {
				id = "ShieldBash",
				name = "Shield Bash",
				description = "Smash enemies in front of you and knock them back.",
				cooldown = 8,
			},
			E = {
				id = "Charge",
				name = "Charge",
				description = "Dash forward, damaging enemies in your path.",
				cooldown = 10,
			},
			F = {
				id = "Bastion",
				name = "Bastion",
				description = "Raise a dome. Allies inside take 60% less damage for 10s.",
				cooldown = 0,
			},
			G = {
				id = "FragGrenade",
				name = "Frag Grenade",
				description = "Explodes on impact for heavy area damage.",
				cooldown = 12,
			},
			V = {
				id = "ShoulderCharge",
				name = "Shoulder Charge",
				description = "Lunge forward and slam the first enemy you hit.",
				cooldown = 6,
			},
		},
		startingWeapons = { primary = "AutoRifle", secondary = "Shotgun", heavy = "MachineGun" },
		hall = {
			name = "The Bastion",
			lore = "Bulwarks stand where others fall. Their hall smells of oil and hot steel, and every dent in the shield wall has a story.",
			centerpiece = "Shield",
		},
	},

	Phantom = {
		id = "Phantom",
		name = "Phantom",
		role = "Assassin / Precision",
		color = Color3.fromRGB(150, 110, 255),
		maxHealth = 90,
		walkSpeed = 20,
		element = "Volt",
		passive = { id = "Predator", name = "Predator", description = "+25% headshot damage." },
		abilities = {
			Q = {
				id = "SmokeVeil",
				name = "Smoke Veil",
				description = "Turn invisible for 4s. Enemies lose track of you.",
				cooldown = 14,
			},
			E = { id = "ShadowDash", name = "Shadow Dash", description = "A long, fast dash.", cooldown = 5 },
			F = { id = "Deadeye", name = "Deadeye", description = "Your next 3 shots deal 5x damage.", cooldown = 0 },
			G = {
				id = "ArcboltGrenade",
				name = "Arcbolt Grenade",
				description = "Lightning chains between up to 4 nearby enemies.",
				cooldown = 12,
			},
			V = {
				id = "KnifeThrow",
				name = "Knife Throw",
				description = "Throw a knife up to 45 studs. Headshots hurt.",
				cooldown = 5,
			},
		},
		startingWeapons = { primary = "HandCannon", secondary = "SMG", heavy = "RocketLauncher" },
		hall = {
			name = "The Shadow Gallery",
			lore = "No lights, no names. Phantoms leave a mark on the wall for every target, and nobody has ever counted them all.",
			centerpiece = "Blades",
		},
	},

	Arcanist = {
		id = "Arcanist",
		name = "Arcanist",
		role = "Crowd Control / Burst",
		color = Color3.fromRGB(70, 200, 255),
		maxHealth = 100,
		walkSpeed = 16,
		element = "Null",
		passive = { id = "Overflow", name = "Overflow", description = "Ability cooldowns are 15% shorter." },
		abilities = {
			Q = {
				id = "GravityWell",
				name = "Gravity Well",
				description = "A singularity that pulls in and damages enemies.",
				cooldown = 12,
			},
			E = { id = "Blink", name = "Blink", description = "Teleport 35 studs forward.", cooldown = 6 },
			F = {
				id = "NovaStorm",
				name = "Nova Storm",
				description = "Charge up, then detonate a massive explosion around you.",
				cooldown = 0,
			},
			G = {
				id = "VortexGrenade",
				name = "Vortex Grenade",
				description = "A swirling void that damages enemies inside for 4s.",
				cooldown = 13,
			},
			V = {
				id = "VoidPalm",
				name = "Void Palm",
				description = "Blast the enemies in front of you backwards.",
				cooldown = 5,
			},
		},
		startingWeapons = { primary = "ScoutRifle", secondary = "SMG", heavy = "RocketLauncher" },
		hall = {
			name = "The Starwell",
			lore = "An observatory around a sliver of the Starfall itself. Arcanists study it day and night, and some swear it whispers back.",
			centerpiece = "Orbs",
		},
	},

	Lifebinder = {
		id = "Lifebinder",
		name = "Lifebinder",
		role = "Support / Healer",
		color = Color3.fromRGB(90, 230, 130),
		maxHealth = 110,
		walkSpeed = 17,
		element = "Ember",
		passive = {
			id = "MendingAura",
			name = "Mending Aura",
			description = "Allies within 25 studs regenerate 2 HP/s.",
		},
		abilities = {
			Q = {
				id = "HealingPulse",
				name = "Healing Pulse",
				description = "Heal yourself and allies within 25 studs.",
				cooldown = 12,
			},
			E = {
				id = "Lifeline",
				name = "Lifeline",
				description = "Dash to the nearest ally and shield you both.",
				cooldown = 10,
			},
			F = {
				id = "Sanctuary",
				name = "Sanctuary",
				description = "A healing zone. Allies inside are healed and protected.",
				cooldown = 0,
			},
			G = {
				id = "HealingGrenade",
				name = "Healing Grenade",
				description = "Heals allies in the blast and burns enemies.",
				cooldown = 12,
			},
			V = {
				id = "SiphonStrike",
				name = "Siphon Strike",
				description = "A strike that heals you for 25.",
				cooldown = 5,
			},
		},
		startingWeapons = { primary = "AutoRifle", secondary = "HandCannon", heavy = "MachineGun" },
		hall = {
			name = "The Verdant Sanctum",
			lore = "The only garden left in orbit. Lifebinders grow the ship's medicine here and patch up anyone who walks in bleeding.",
			centerpiece = "Garden",
		},
	},

	Engineer = {
		id = "Engineer",
		name = "Engineer",
		role = "Zone Control / Turrets",
		color = Color3.fromRGB(255, 220, 70),
		maxHealth = 110,
		walkSpeed = 16,
		element = "Volt",
		passive = { id = "Scavenger", name = "Scavenger", description = "Kills refund 10% ammo. Turrets last longer." },
		abilities = {
			Q = {
				id = "SentryTurret",
				name = "Sentry Turret",
				description = "Deploy an auto-turret for 15s.",
				cooldown = 16,
			},
			E = { id = "Thrusters", name = "Thrusters", description = "Jetpack boost up and forward.", cooldown = 6 },
			F = {
				id = "OrbitalStrike",
				name = "Orbital Strike",
				description = "The Meridian fires a laser at your target.",
				cooldown = 0,
			},
			G = {
				id = "ClusterGrenade",
				name = "Cluster Grenade",
				description = "One blast, then four smaller ones around it.",
				cooldown = 14,
			},
			V = {
				id = "ShockWrench",
				name = "Shock Wrench",
				description = "A wrench hit that stuns the enemy for 1.5s.",
				cooldown = 5,
			},
		},
		startingWeapons = { primary = "SMG", secondary = "ScoutRifle", heavy = "RocketLauncher" },
		hall = {
			name = "The Forge Deck",
			lore = "Half workshop, half scrapyard. If something on the Meridian works, an Engineer built it twice.",
			centerpiece = "Forge",
		},
	},
}

-- Display order in the class picker
local Order = { "Bulwark", "Phantom", "Arcanist", "Lifebinder", "Engineer" }

return {
	Defs = Classes,
	Order = Order,
}
