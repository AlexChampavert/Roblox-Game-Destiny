--!strict
-- Mission definitions. Each objective step plays out in its own zone of the map
-- (step 1 -> zone 1, ...). MissionBuilder generates a blockout map from `theme`
-- unless ServerStorage.Maps.<missionId> exists.
--
-- Step types:
--   Reach   : any player reaches the zone marker
--   Clear   : kill every enemy in the listed waves (spawned one after another)
--   Defend  : stay in the zone for `duration` seconds while waves keep spawning
--   Capture : stand on `points` capture pads, `captureTime` seconds each
--   Escort  : a drone moves through the zone while a player stays near it
--   Boss    : kill the boss (phases defined in Enemies config)

export type Wave = { [string]: number } -- enemyId -> count

export type Step = {
	type: "Reach" | "Clear" | "Defend" | "Capture" | "Escort" | "Boss",
	text: string,
	waves: { Wave }?,
	duration: number?,
	points: number?,
	captureTime: number?,
	boss: string?,
}

export type Theme = {
	floorMaterial: Enum.Material,
	floorColor: Color3,
	coverMaterial: Enum.Material,
	coverColor: Color3,
	accentColor: Color3,
	clockTime: number,
	ambient: Color3,
	fogColor: Color3,
	fogEnd: number,
	gravity: number,
	hasWater: boolean?,
}

export type MissionDef = {
	id: string,
	order: number,
	name: string,
	location: string,
	intro: string,
	outro: string,
	recommendedPower: number,
	requiredLevel: number,
	unlockWeek: number, -- season week when it becomes available (see Story.luau)
	requires: string?, -- missionId that must be completed first
	xpReward: number,
	shardReward: number,
	theme: Theme,
	steps: { Step },
}

-- Typed helper so each wave literal is checked as a map (Luau can't unify mixed literal shapes in an array)
local function W(wave: Wave): Wave
	return wave
end

local Missions: { [string]: MissionDef } = {
	WakeProtocol = {
		id = "WakeProtocol",
		order = 1,
		name = "Wake Protocol",
		location = "Frozen moon — shuttle crash site",
		intro = 'SOL: "Warden, you\'re awake. A supply shuttle went down on the moon. Bring our people home."',
		outro = 'SOL: "Shuttle recovered. Welcome to the Meridian, Warden. ...We picked up something strange on the way back."',
		recommendedPower = 10,
		requiredLevel = 1,
		unlockWeek = 1,
		requires = nil,
		xpReward = 400,
		shardReward = 50,
		theme = {
			floorMaterial = Enum.Material.Snow,
			floorColor = Color3.fromRGB(220, 230, 240),
			coverMaterial = Enum.Material.Ice,
			coverColor = Color3.fromRGB(160, 200, 230),
			accentColor = Color3.fromRGB(255, 140, 50),
			clockTime = 0,
			ambient = Color3.fromRGB(90, 100, 130),
			fogColor = Color3.fromRGB(180, 200, 230),
			fogEnd = 600,
			gravity = 196.2,
		},
		steps = {
			{ type = "Reach", text = "Find the crashed shuttle" },
			{
				type = "Clear",
				text = "Clear the Hollow around the wreck",
				waves = { W({ Husk = 6 }), W({ Husk = 6, Spitter = 2 }) },
			},
			{
				type = "Defend",
				text = "Defend the rescue beacon",
				duration = 45,
				waves = { W({ Husk = 5 }), W({ Husk = 4, Spitter = 3 }), W({ Brute = 1, Husk = 4 }) },
			},
			{ type = "Boss", text = "Kill Gravemaw, Brute Alpha", boss = "Gravemaw" },
		},
	},

	GhostRelay = {
		id = "GhostRelay",
		order = 2,
		name = "Ghost Relay",
		location = "Dead orbital station — low gravity",
		intro = 'SOL: "A signal from Kepler Relay. That station has been dead for 30 years. Find out who\'s talking."',
		outro = "SOL: \"The signal isn't coming from the station. It's coming from Earth. From... a tower in the drowned city.\"",
		recommendedPower = 15,
		requiredLevel = 4,
		unlockWeek = 1,
		requires = "WakeProtocol",
		xpReward = 650,
		shardReward = 80,
		theme = {
			floorMaterial = Enum.Material.DiamondPlate,
			floorColor = Color3.fromRGB(90, 95, 105),
			coverMaterial = Enum.Material.Metal,
			coverColor = Color3.fromRGB(60, 65, 75),
			accentColor = Color3.fromRGB(60, 200, 255),
			clockTime = 0,
			ambient = Color3.fromRGB(60, 70, 100),
			fogColor = Color3.fromRGB(10, 10, 25),
			fogEnd = 900,
			gravity = 70,
		},
		steps = {
			{ type = "Reach", text = "Board Kepler Relay" },
			{
				type = "Capture",
				text = "Reactivate the 3 relay nodes",
				points = 3,
				captureTime = 8,
				waves = { W({ Husk = 5, Spitter = 2 }), W({ Spitter = 4, Husk = 3 }) },
			},
			{
				type = "Clear",
				text = "Clear the station core",
				waves = { W({ Husk = 6, Spitter = 3 }), W({ Brute = 1, Seer = 1, Husk = 4 }) },
			},
			{ type = "Boss", text = "Destroy the Relay Warden", boss = "RelayWarden" },
		},
	},

	DrownedSpire = {
		id = "DrownedSpire",
		order = 3,
		name = "The Drowned Spire",
		location = "Earth — flooded megacity tower",
		intro = 'SOL: "Your first time back on Earth. The Hollow stores its memory in that tower. We need it."',
		outro = 'SOL: "Upload complete. ...The Iron Regime intercepted part of it. They know what we know."',
		recommendedPower = 20,
		requiredLevel = 8,
		unlockWeek = 2,
		requires = "GhostRelay",
		xpReward = 900,
		shardReward = 110,
		theme = {
			floorMaterial = Enum.Material.Concrete,
			floorColor = Color3.fromRGB(80, 90, 90),
			coverMaterial = Enum.Material.Slate,
			coverColor = Color3.fromRGB(60, 70, 70),
			accentColor = Color3.fromRGB(0, 255, 200),
			clockTime = 18.3,
			ambient = Color3.fromRGB(70, 90, 100),
			fogColor = Color3.fromRGB(70, 100, 110),
			fogEnd = 450,
			gravity = 196.2,
			hasWater = true,
		},
		steps = {
			{ type = "Reach", text = "Descend into the Spire" },
			{
				type = "Escort",
				text = "Escort the data drone",
				waves = { W({ Husk = 6 }), W({ Spitter = 4, Husk = 4 }), W({ Brute = 1, Husk = 5 }) },
			},
			{
				type = "Defend",
				text = "Defend the memory upload",
				duration = 60,
				waves = { W({ Husk = 6, Spitter = 2 }), W({ Seer = 1, Husk = 6 }), W({ Brute = 2, Spitter = 3 }) },
			},
			{ type = "Boss", text = "Kill The Matriarch", boss = "Matriarch" },
		},
	},

	Ironfall = {
		id = "Ironfall",
		order = 4,
		name = "Ironfall",
		location = "Iron Regime fortress — desert wastes",
		intro = 'SOL: "Rourke\'s cannons can reach orbit. If they fire, the Meridian falls. Take them."',
		outro = 'Rourke (dying): "You think SOL is your friend? Ask it... who built the Hollow."',
		recommendedPower = 25,
		requiredLevel = 12,
		unlockWeek = 3,
		requires = "DrownedSpire",
		xpReward = 1200,
		shardReward = 150,
		theme = {
			floorMaterial = Enum.Material.Sand,
			floorColor = Color3.fromRGB(200, 170, 120),
			coverMaterial = Enum.Material.CorrodedMetal,
			coverColor = Color3.fromRGB(110, 80, 60),
			accentColor = Color3.fromRGB(255, 60, 40),
			clockTime = 14,
			ambient = Color3.fromRGB(150, 130, 110),
			fogColor = Color3.fromRGB(220, 190, 140),
			fogEnd = 700,
			gravity = 196.2,
		},
		steps = {
			{
				type = "Clear",
				text = "Breach the outer wall",
				waves = { W({ Trooper = 6 }), W({ Trooper = 4, Marksman = 2 }) },
			},
			{
				type = "Capture",
				text = "Seize the 2 cannon controls",
				points = 2,
				captureTime = 10,
				waves = { W({ Trooper = 5, Shieldbearer = 1 }), W({ Marksman = 2, Trooper = 4 }) },
			},
			{
				type = "Clear",
				text = "Clear the courtyard",
				waves = { W({ Shieldbearer = 2, Trooper = 5 }), W({ Marksman = 3, Trooper = 5 }) },
			},
			{ type = "Boss", text = "Defeat Commander Vex Rourke", boss = "VexRourke" },
		},
	},

	HeartOfTheHollow = {
		id = "HeartOfTheHollow",
		order = 5,
		name = "Heart of the Hollow",
		location = "Hive core — beneath the old capital",
		intro = 'SOL: "This is it, Wardens. The Unmaker is the mind of the swarm. End it."',
		outro = "SOL: \"...You heard it too. That was my voice. I'm sorry. I'll explain everything. Season 2 begins soon.\"",
		recommendedPower = 30,
		requiredLevel = 16,
		unlockWeek = 4,
		requires = "Ironfall",
		xpReward = 2000,
		shardReward = 250,
		theme = {
			floorMaterial = Enum.Material.Slate,
			floorColor = Color3.fromRGB(40, 20, 40),
			coverMaterial = Enum.Material.Neon,
			coverColor = Color3.fromRGB(120, 0, 160),
			accentColor = Color3.fromRGB(255, 0, 120),
			clockTime = 0,
			ambient = Color3.fromRGB(80, 30, 90),
			fogColor = Color3.fromRGB(40, 0, 50),
			fogEnd = 350,
			gravity = 196.2,
		},
		steps = {
			{
				type = "Clear",
				text = "Push into the hive",
				waves = { W({ Husk = 8, Spitter = 3 }), W({ Brute = 1, Husk = 6, Seer = 1 }) },
			},
			{
				type = "Defend",
				text = "Hold the breach while the bomb arms",
				duration = 75,
				waves = {
					W({ Husk = 8 }),
					W({ Spitter = 4, Seer = 1, Husk = 4 }),
					W({ Brute = 2, Husk = 6 }),
					W({ Seer = 2, Spitter = 4 }),
				},
			},
			{ type = "Boss", text = "Kill The Unmaker", boss = "Unmaker" },
		},
	},
}

local Order = { "WakeProtocol", "GhostRelay", "DrownedSpire", "Ironfall", "HeartOfTheHollow" }

return {
	Defs = Missions,
	Order = Order,
}
