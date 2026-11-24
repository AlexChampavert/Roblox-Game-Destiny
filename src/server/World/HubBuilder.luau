-- Builds the Meridian hub: an ISS-style starship in orbit with an open-air Skydeck.
-- Blockout geometry generated from code so the game is playable immediately.
-- To use a hand-built hub, put a Model named "Hub" in ServerStorage.Maps; it must contain
-- parts named MissionTable, ClassTerminal, SolCore and a SpawnLocation.

local Lighting = game:GetService("Lighting")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Story = require(Shared.Config.Story)
local Classes = require(Shared.Config.Classes)

local Build = require(script.Parent.Build)
local P = Build.part

local HubBuilder = {}

local DECK_Y = 100 -- walkable top surface of the ship

local HULL = Color3.fromRGB(205, 210, 220)
local HULL_DARK = Color3.fromRGB(120, 125, 140)
local TRIM = Color3.fromRGB(60, 200, 255)
local GOLD = Color3.fromRGB(210, 170, 80)
local PANEL = Color3.fromRGB(25, 45, 110)

local function addPrompt(part: BasePart, action: string, object: string, menu: string, arg: any?)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt.Parent = part
	prompt.Triggered:Connect(function(player)
		Net.event("OpenMenu"):FireClient(player, menu, arg)
	end)
end

local function room(parent: Instance, name: string, center: Vector3, size: Vector3, doorSide: string, doorWidth: number)
	-- Floor-less box (sits on the hull) with walls, roof, window strips and one doorway.
	local m = Build.model(name, parent)
	local h = size.Y
	local base = center - Vector3.new(0, h / 2, 0)
	P({ name = "Roof", size = Vector3.new(size.X, 2, size.Z), position = base + Vector3.new(0, h + 1, 0), color = HULL, material = Enum.Material.Metal, parent = m })
	P({ name = "RoofTrim", size = Vector3.new(size.X + 1, 0.6, size.Z + 1), position = base + Vector3.new(0, h + 0.3, 0), color = TRIM, material = Enum.Material.Neon, collide = false, parent = m })

	local function wall(cf: CFrame, length: number, hasDoor: boolean)
		if hasDoor then
			local side = (length - doorWidth) / 2
			P({ size = Vector3.new(side, h, 2), cframe = cf * CFrame.new(-(doorWidth + side) / 2, 0, 0), color = HULL, material = Enum.Material.Metal, parent = m })
			P({ size = Vector3.new(side, h, 2), cframe = cf * CFrame.new((doorWidth + side) / 2, 0, 0), color = HULL, material = Enum.Material.Metal, parent = m })
			P({ size = Vector3.new(doorWidth, h - 14, 2), cframe = cf * CFrame.new(0, 7, 0), color = HULL, material = Enum.Material.Metal, parent = m })
			P({ size = Vector3.new(doorWidth, 0.6, 2.2), cframe = cf * CFrame.new(0, -h / 2 + 14, 0), color = TRIM, material = Enum.Material.Neon, collide = false, parent = m })
		else
			P({ size = Vector3.new(length, h, 2), cframe = cf, color = HULL, material = Enum.Material.Metal, parent = m })
			P({ name = "Window", size = Vector3.new(length - 8, 5, 2.2), cframe = cf * CFrame.new(0, h / 4, 0), color = Color3.fromRGB(120, 180, 255), material = Enum.Material.Glass, transparency = 0.5, parent = m })
		end
	end
	local mid = base + Vector3.new(0, h / 2, 0)
	wall(CFrame.new(mid + Vector3.new(0, 0, size.Z / 2)), size.X, doorSide == "+Z")
	wall(CFrame.new(mid - Vector3.new(0, 0, size.Z / 2)), size.X, doorSide == "-Z")
	wall(CFrame.new(mid + Vector3.new(size.X / 2, 0, 0)) * CFrame.Angles(0, math.rad(90), 0), size.Z, doorSide == "+X")
	wall(CFrame.new(mid - Vector3.new(size.X / 2, 0, 0)) * CFrame.Angles(0, math.rad(90), 0), size.Z, doorSide == "-X")
	-- interior floor plating + light
	P({ name = "Floor", size = Vector3.new(size.X - 2, 0.4, size.Z - 2), position = base + Vector3.new(0, 0.2, 0), color = Color3.fromRGB(70, 75, 90), material = Enum.Material.DiamondPlate, parent = m })
	P({ name = "Light", size = Vector3.new(size.X * 0.6, 0.4, 3), position = base + Vector3.new(0, h - 0.3, 0), color = Color3.fromRGB(220, 240, 255), material = Enum.Material.Neon, collide = false, light = { color = Color3.fromRGB(200, 230, 255), range = 60, brightness = 1.5 }, parent = m })
	return m
end

local function buildShip(hub: Model)
	-- HULL (main spine)
	P({ name = "Hull", size = Vector3.new(520, 40, 80), position = Vector3.new(0, DECK_Y - 20, 0), color = HULL, material = Enum.Material.Metal, parent = hub })
	P({ name = "HullBelly", size = Vector3.new(440, 24, 60), position = Vector3.new(0, DECK_Y - 52, 0), color = HULL_DARK, material = Enum.Material.Metal, parent = hub })
	for _, z in { -40.2, 40.2 } do
		P({ name = "HullStripe", size = Vector3.new(520, 1.2, 0.4), position = Vector3.new(0, DECK_Y - 6, z), color = TRIM, material = Enum.Material.Neon, collide = false, parent = hub })
	end
	-- Greebles under the hull
	local rng = Random.new(42)
	for _ = 1, 30 do
		P({
			name = "Greeble",
			size = Vector3.new(rng:NextNumber(10, 40), rng:NextNumber(4, 10), rng:NextNumber(8, 20)),
			position = Vector3.new(rng:NextNumber(-220, 220), DECK_Y - rng:NextNumber(60, 68), rng:NextNumber(-25, 25)),
			color = if rng:NextNumber() < 0.5 then HULL else HULL_DARK,
			material = Enum.Material.Metal,
			parent = hub,
		})
	end

	-- BOW (front, -X)
	P({ name = "Bow", wedge = true, size = Vector3.new(80, 40, 90), cframe = CFrame.new(-305, DECK_Y - 20, 0) * CFrame.Angles(0, math.rad(90), 0), color = HULL, material = Enum.Material.Metal, parent = hub })
	P({ name = "BowLight", size = Vector3.new(4, 4, 4), shape = Enum.PartType.Ball, position = Vector3.new(-340, DECK_Y - 30, 0), color = Color3.fromRGB(255, 80, 80), material = Enum.Material.Neon, collide = false, light = { color = Color3.fromRGB(255, 80, 80), range = 40, brightness = 3 }, parent = hub })

	-- ENGINES (rear, +X)
	for _, z in { -24, 0, 24 } do
		P({ name = "Engine", shape = Enum.PartType.Cylinder, size = Vector3.new(60, 22, 22), position = Vector3.new(290, DECK_Y - 30, z), color = HULL_DARK, material = Enum.Material.Metal, parent = hub })
		P({ name = "EngineGlow", shape = Enum.PartType.Cylinder, size = Vector3.new(2, 18, 18), position = Vector3.new(321, DECK_Y - 30, z), color = Color3.fromRGB(80, 170, 255), material = Enum.Material.Neon, collide = false, light = { color = Color3.fromRGB(80, 170, 255), range = 60, brightness = 4 }, parent = hub })
	end
end

local function buildSkydeck(hub: Model)
	local deck = Build.model("Skydeck", hub)
	P({ name = "DeckFloor", size = Vector3.new(240, 1, 78), position = Vector3.new(0, DECK_Y + 0.5, 0), color = Color3.fromRGB(235, 238, 245), material = Enum.Material.SmoothPlastic, parent = deck })
	for x = -100, 100, 25 do
		P({ name = "FloorLine", size = Vector3.new(0.5, 0.2, 78), position = Vector3.new(x, DECK_Y + 1.05, 0), color = TRIM, material = Enum.Material.Neon, collide = false, parent = deck })
	end
	-- Glass railings (open sky above — no roof)
	for _, z in { -39, 39 } do
		P({ name = "Railing", size = Vector3.new(240, 4, 0.6), position = Vector3.new(0, DECK_Y + 3, z), color = Color3.fromRGB(170, 220, 255), material = Enum.Material.Glass, transparency = 0.55, parent = deck })
		P({ name = "RailTop", size = Vector3.new(240, 0.4, 1), position = Vector3.new(0, DECK_Y + 5.2, z), color = TRIM, material = Enum.Material.Neon, collide = false, parent = deck })
	end
	-- Gaps in the railings where the trusses connect
	for _, child in deck:GetChildren() do
		if child.Name == "Railing" then
			local r = child :: BasePart
			local z = r.Position.Z
			r:Destroy()
			for _, x in { -66, 66 } do
				P({ name = "Railing", size = Vector3.new(108, 4, 0.6), position = Vector3.new(x, DECK_Y + 3, z), color = Color3.fromRGB(170, 220, 255), material = Enum.Material.Glass, transparency = 0.55, parent = deck })
			end
		end
	end
	-- Shield emitter pylons (energy bubble keeping the air in)
	for _, x in { -115, 115 } do
		for _, z in { -36, 36 } do
			P({ name = "Pylon", size = Vector3.new(2, 18, 2), position = Vector3.new(x, DECK_Y + 10, z), color = HULL_DARK, material = Enum.Material.Metal, parent = deck })
			P({ name = "PylonTip", shape = Enum.PartType.Ball, size = Vector3.new(4, 4, 4), position = Vector3.new(x, DECK_Y + 20, z), color = TRIM, material = Enum.Material.Neon, collide = false, light = { color = TRIM, range = 30, brightness = 2 }, parent = deck })
		end
	end
	-- Benches / social spots
	for _, x in { -60, -30, 30, 60 } do
		for _, z in { -28, 28 } do
			P({ name = "Bench", size = Vector3.new(14, 1.5, 4), position = Vector3.new(x, DECK_Y + 1.75, z), color = Color3.fromRGB(60, 70, 90), material = Enum.Material.Metal, parent = deck })
		end
	end
	-- Season board
	local board = P({ name = "SeasonBoard", size = Vector3.new(40, 14, 1), cframe = CFrame.new(0, DECK_Y + 10, -30) * CFrame.Angles(0, math.pi, 0), color = Color3.fromRGB(10, 15, 30), material = Enum.Material.SmoothPlastic, parent = deck })
	local chapter = Story.currentChapter()
	Build.sign(board, ("%s\nWeek %d — %s\n\n%s"):format(Story.SeasonName, chapter.week, chapter.title, chapter.solMessage))

	-- Spawn on the Skydeck: first thing a player sees is space + Earth
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(16, 1, 16)
	spawn.Position = Vector3.new(-80, DECK_Y + 1.1, 0)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = TRIM
	spawn.Material = Enum.Material.Neon
	spawn.Transparency = 0.4
	spawn.CanCollide = false
	spawn.Parent = deck
end

local function buildModules(hub: Model)
	-- COMMAND DECK (front): mission table, SOL core, class terminal
	local cmd = room(hub, "CommandDeck", Vector3.new(-185, DECK_Y + 15, 0), Vector3.new(110, 30, 76), "+X", 20)
	local tableBase = P({ name = "MissionTable", shape = Enum.PartType.Cylinder, size = Vector3.new(3, 18, 18), cframe = CFrame.new(-185, DECK_Y + 1.5, 0) * CFrame.Angles(0, 0, math.rad(90)), color = Color3.fromRGB(40, 45, 60), material = Enum.Material.Metal, parent = cmd })
	P({ name = "Hologram", shape = Enum.PartType.Ball, size = Vector3.new(9, 9, 9), position = Vector3.new(-185, DECK_Y + 9, 0), color = Color3.fromRGB(70, 150, 255), material = Enum.Material.ForceField, collide = false, light = { color = Color3.fromRGB(70, 150, 255), range = 30, brightness = 2 }, parent = cmd })
	addPrompt(tableBase, "Open Missions", "Mission Table", "Missions")

	local sol = P({ name = "SolCore", shape = Enum.PartType.Ball, size = Vector3.new(10, 10, 10), position = Vector3.new(-232, DECK_Y + 12, 0), color = Color3.fromRGB(255, 200, 90), material = Enum.Material.Neon, collide = false, light = { color = Color3.fromRGB(255, 200, 90), range = 50, brightness = 3 }, parent = cmd })
	P({ name = "SolPedestal", size = Vector3.new(8, 6, 8), position = Vector3.new(-232, DECK_Y + 3, 0), color = HULL_DARK, material = Enum.Material.Metal, parent = cmd })
	addPrompt(sol, "Talk to SOL", "SOL", "Story")

	local terminal = P({ name = "ClassTerminal", size = Vector3.new(10, 8, 3), cframe = CFrame.new(-185, DECK_Y + 4, 33), color = Color3.fromRGB(40, 45, 60), material = Enum.Material.Metal, parent = cmd })
	local screen = P({ name = "Screen", size = Vector3.new(8.5, 5, 0.2), cframe = terminal.CFrame * CFrame.new(0, 0.5, -1.6), color = Color3.fromRGB(20, 30, 50), material = Enum.Material.Neon, collide = false, parent = cmd })
	Build.sign(screen, "WARDEN CLASSES", TRIM)
	addPrompt(terminal, "Change Class", "Class Terminal", "Classes")

	-- HANGAR (rear): docked shuttle, opens to space on +Z
	local hangar = room(hub, "Hangar", Vector3.new(185, DECK_Y + 15, 0), Vector3.new(110, 30, 76), "-X", 20)
	for _, child in hangar:GetChildren() do
		-- open the +Z wall entirely (hangar door to space)
		if child:IsA("BasePart") and math.abs(child.Position.Z - 38) < 1.5 then
			child:Destroy()
		end
	end
	P({ name = "HangarField", size = Vector3.new(108, 28, 0.4), position = Vector3.new(185, DECK_Y + 14, 38), color = TRIM, material = Enum.Material.ForceField, transparency = 0.6, parent = hangar })
	local shuttle = Build.model("Shuttle", hangar)
	P({ size = Vector3.new(34, 8, 14), position = Vector3.new(185, DECK_Y + 6, 0), color = Color3.fromRGB(230, 230, 235), material = Enum.Material.Metal, parent = shuttle })
	P({ wedge = true, size = Vector3.new(14, 8, 12), cframe = CFrame.new(208, DECK_Y + 6, 0) * CFrame.Angles(0, math.rad(-90), 0), color = Color3.fromRGB(230, 230, 235), material = Enum.Material.Metal, parent = shuttle })
	P({ size = Vector3.new(16, 1, 34), position = Vector3.new(180, DECK_Y + 4, 0), color = Color3.fromRGB(200, 200, 210), material = Enum.Material.Metal, parent = shuttle })
	P({ size = Vector3.new(6, 3, 12.2), position = Vector3.new(198, DECK_Y + 8, 0), color = Color3.fromRGB(90, 160, 230), material = Enum.Material.Glass, transparency = 0.3, parent = shuttle })
end

local function buildTrusses(hub: Model)
	-- ISS-style truss arms sticking out sideways, walkable, with solar wings
	local truss = Build.model("Trusses", hub)
	for _, sign in { -1, 1 } do
		local zCenter = sign * 190
		P({ name = "TrussBeam", size = Vector3.new(10, 6, 300), position = Vector3.new(0, DECK_Y - 2.5, zCenter), color = HULL, material = Enum.Material.Metal, parent = truss })
		P({ name = "TrussWalk", size = Vector3.new(8, 0.5, 300), position = Vector3.new(0, DECK_Y + 0.75, zCenter), color = Color3.fromRGB(90, 95, 110), material = Enum.Material.DiamondPlate, parent = truss })
		-- lattice
		for i = 0, 14 do
			local z = sign * (45 + i * 20)
			P({ name = "Lattice", size = Vector3.new(0.6, 9, 0.6), cframe = CFrame.new(-5.4, DECK_Y - 5, z) * CFrame.Angles(math.rad(35), 0, 0), color = GOLD, material = Enum.Material.Metal, collide = false, parent = truss })
			P({ name = "Lattice", size = Vector3.new(0.6, 9, 0.6), cframe = CFrame.new(5.4, DECK_Y - 5, z) * CFrame.Angles(math.rad(-35), 0, 0), color = GOLD, material = Enum.Material.Metal, collide = false, parent = truss })
		end
		-- solar wings (walkable, part of the jumping puzzle)
		for _, zOff in { 130, 250 } do
			local z = sign * zOff
			for _, x in { -1, 1 } do
				local wing = P({ name = "SolarWing", size = Vector3.new(150, 0.6, 32), position = Vector3.new(x * 84, DECK_Y - 1, z), color = PANEL, material = Enum.Material.Glass, parent = truss })
				P({ name = "WingFrame", size = Vector3.new(152, 0.5, 1), position = wing.Position + Vector3.new(0, 0.3, 16), color = GOLD, material = Enum.Material.Metal, collide = false, parent = truss })
				P({ name = "WingFrame", size = Vector3.new(152, 0.5, 1), position = wing.Position + Vector3.new(0, 0.3, -16), color = GOLD, material = Enum.Material.Metal, collide = false, parent = truss })
				P({ name = "WingArm", size = Vector3.new(12, 1, 2), position = Vector3.new(x * 8, DECK_Y - 1, z), color = HULL_DARK, material = Enum.Material.Metal, parent = truss })
			end
		end
	end

	-- Jumping puzzle at the end of the +Z truss, up to a hidden lore cache
	local puzzle = Build.model("JumpPuzzle", hub)
	local pos = Vector3.new(0, DECK_Y, 342)
	local prng = Random.new(7)
	local dir = 1
	for i = 1, 12 do
		pos += Vector3.new(prng:NextNumber(-4, 4), 4, 8 * dir)
		if i % 4 == 0 then
			dir = -dir -- zigzag so the tower stays compact
		end
		P({ name = "Step" .. i, size = Vector3.new(6, 1, 6), position = pos, color = Color3.fromRGB(230, 230, 240), material = Enum.Material.Metal, parent = puzzle })
		P({ name = "StepGlow", size = Vector3.new(6.2, 0.2, 6.2), position = pos - Vector3.new(0, 0.55, 0), color = TRIM, material = Enum.Material.Neon, collide = false, parent = puzzle })
	end
	local top = P({ name = "LoreCachePlatform", size = Vector3.new(14, 1, 14), position = pos + Vector3.new(0, 4, 10 * dir),color = GOLD, material = Enum.Material.Metal, parent = puzzle })
	local cache = P({ name = "LoreCache", size = Vector3.new(3, 3, 3), position = top.Position + Vector3.new(0, 3, 0), color = Color3.fromRGB(255, 200, 90), material = Enum.Material.Neon, collide = false, light = { color = Color3.fromRGB(255, 200, 90), range = 20, brightness = 3 }, parent = puzzle })
	addPrompt(cache, "Read", "Lore Cache", "Lore")
end

-- ===== CLASS HALLS =====
-- One small hall per class, hanging off the truss arms ("Warden Row").
-- Generated from Classes config: add a class there and it gets a hall automatically.

-- Free slots along the trusses (avoiding the solar wings). side: -1 = left of the walkway, 1 = right
local HALL_SLOTS = {
	{ z = -78, side = -1 }, { z = -78, side = 1 },
	{ z = -190, side = -1 }, { z = -190, side = 1 },
	{ z = -305, side = -1 }, { z = -305, side = 1 },
	{ z = 78, side = -1 }, { z = 78, side = 1 },
	{ z = 190, side = -1 }, { z = 190, side = 1 },
}
local HALL_SIZE = Vector3.new(26, 16, 22)

local function centerpiece(m: Model, kind: string, pos: Vector3, color: Color3): BasePart
	local pedestal = P({ name = "Pedestal", size = Vector3.new(6, 2, 6), position = pos + Vector3.new(0, 1, 0), color = HULL_DARK, material = Enum.Material.Metal, parent = m })
	local top = pos + Vector3.new(0, 2, 0)
	if kind == "Shield" then
		for i = -1, 1 do
			P({ name = "ShieldWall", size = Vector3.new(5, 8, 1), cframe = CFrame.new(top + Vector3.new(i * 5, 4, 2 - math.abs(i) * 2)) * CFrame.Angles(0, math.rad(-i * 25), 0), color = Color3.fromRGB(150, 150, 160), material = Enum.Material.Metal, parent = m })
			P({ name = "ShieldTrim", size = Vector3.new(5.2, 0.4, 1.2), cframe = CFrame.new(top + Vector3.new(i * 5, 7.5, 2 - math.abs(i) * 2)) * CFrame.Angles(0, math.rad(-i * 25), 0), color = color, material = Enum.Material.Neon, collide = false, parent = m })
		end
	elseif kind == "Blades" then
		for _, angle in { 35, -35 } do
			P({ name = "Blade", size = Vector3.new(0.4, 9, 1), cframe = CFrame.new(top + Vector3.new(0, 4.5, 0)) * CFrame.Angles(0, 0, math.rad(angle)), color = color, material = Enum.Material.Neon, collide = false, parent = m })
		end
	elseif kind == "Orbs" then
		P({ name = "StarShard", size = Vector3.new(2, 2, 2), cframe = CFrame.new(top + Vector3.new(0, 5, 0)) * CFrame.Angles(math.rad(45), math.rad(45), 0), color = Color3.new(1, 1, 1), material = Enum.Material.Neon, collide = false, light = { color = color, range = 25, brightness = 3 }, parent = m })
		for i = 1, 3 do
			local a = i / 3 * math.pi * 2
			P({ name = "Orb", shape = Enum.PartType.Ball, size = Vector3.new(1.2, 1.2, 1.2), position = top + Vector3.new(math.cos(a) * 3.5, 5 + i * 0.6, math.sin(a) * 3.5), color = color, material = Enum.Material.Neon, collide = false, parent = m })
		end
	elseif kind == "Garden" then
		for _, off in { Vector3.new(-8, 0, -6), Vector3.new(8, 0, -6), Vector3.new(-8, 0, 6), Vector3.new(8, 0, 6) } do
			P({ name = "Planter", size = Vector3.new(4, 2, 4), position = pos + off + Vector3.new(0, 1, 0), color = Color3.fromRGB(90, 70, 50), material = Enum.Material.Wood, parent = m })
			P({ name = "Plant", shape = Enum.PartType.Ball, size = Vector3.new(4, 4, 4), position = pos + off + Vector3.new(0, 4, 0), color = Color3.fromRGB(60, 160, 70), material = Enum.Material.Grass, collide = false, parent = m })
		end
		P({ name = "Tree", shape = Enum.PartType.Ball, size = Vector3.new(5, 5, 5), position = top + Vector3.new(0, 4, 0), color = color, material = Enum.Material.Neon, collide = false, light = { color = color, range = 25, brightness = 2 }, parent = m })
	elseif kind == "Forge" then
		P({ name = "Anvil", size = Vector3.new(4, 2, 2.5), position = top + Vector3.new(0, 1, 0), color = Color3.fromRGB(60, 60, 65), material = Enum.Material.Metal, parent = m })
		P({ name = "Embers", size = Vector3.new(3, 0.6, 3), position = top + Vector3.new(6, -1, -4), color = Color3.fromRGB(255, 120, 30), material = Enum.Material.Neon, collide = false, light = { color = Color3.fromRGB(255, 120, 30), range = 20, brightness = 3 }, parent = m })
		P({ name = "TurretDisplay", size = Vector3.new(2, 2, 2), position = top + Vector3.new(0, 3, 0), color = color, material = Enum.Material.Neon, collide = false, parent = m })
	else
		-- Default for new classes: a glowing emblem cube
		P({ name = "Emblem", size = Vector3.new(2.5, 2.5, 2.5), cframe = CFrame.new(top + Vector3.new(0, 3, 0)) * CFrame.Angles(math.rad(45), math.rad(45), 0), color = color, material = Enum.Material.Neon, collide = false, parent = m })
	end
	return pedestal
end

local function buildClassHalls(hub: Model)
	local row = Build.model("ClassHalls", hub)
	for i, classId in Classes.Order do
		local slot = HALL_SLOTS[i]
		if not slot then
			warn("[HubBuilder] No free hall slot for class", classId, "- add one to HALL_SLOTS")
			continue
		end
		local class = Classes.Defs[classId]
		local hall = class.hall or { name = class.name .. " Hall", lore = "", centerpiece = "" }
		local x = slot.side * (6 + HALL_SIZE.X / 2)
		local base = Vector3.new(x, DECK_Y + 1, slot.z)
		local center = base + Vector3.new(0, HALL_SIZE.Y / 2, 0)

		-- Floor slab that bridges to the truss walkway
		P({ name = "HallFloor", size = Vector3.new(HALL_SIZE.X + 4, 2, HALL_SIZE.Z), position = Vector3.new(x - slot.side * 2, DECK_Y, slot.z), color = HULL_DARK, material = Enum.Material.Metal, parent = row })
		local m = room(row, classId .. "Hall", center, HALL_SIZE, if slot.side < 0 then "+X" else "-X", 10)

		-- Tint the hall in the class color
		for _, d in m:GetDescendants() do
			if d.Name == "RoofTrim" and d:IsA("BasePart") then
				d.Color = class.color
			elseif d:IsA("PointLight") then
				d.Color = class.color
			end
		end
		for _, z in { -HALL_SIZE.Z / 2 + 1.2, HALL_SIZE.Z / 2 - 1.2 } do
			P({ name = "WallGlow", size = Vector3.new(HALL_SIZE.X - 4, 0.4, 0.3), position = Vector3.new(x, DECK_Y + 2, slot.z + z), color = class.color, material = Enum.Material.Neon, collide = false, parent = m })
		end

		-- Banner on the back wall
		local backX = x + slot.side * (HALL_SIZE.X / 2 - 1.3)
		local banner = P({ name = "Banner", size = Vector3.new(14, 6, 0.4), cframe = CFrame.lookAt(Vector3.new(backX, DECK_Y + 10, slot.z), Vector3.new(x, DECK_Y + 10, slot.z)), color = Color3.fromRGB(15, 18, 28), parent = m })
		Build.sign(banner, ("%s\n%s Order"):format(hall.name:upper(), class.name), class.color)

		-- Sign over the door, readable from the walkway
		local doorX = x - slot.side * (HALL_SIZE.X / 2 + 0.6)
		local doorSign = P({ name = "DoorSign", size = Vector3.new(12, 2.5, 0.3), cframe = CFrame.lookAt(Vector3.new(doorX, DECK_Y + 14, slot.z), Vector3.new(doorX - slot.side * 10, DECK_Y + 14, slot.z)), color = Color3.fromRGB(15, 18, 28), parent = m })
		Build.sign(doorSign, hall.name, class.color)

		-- Centerpiece + prompt
		local pedestal = centerpiece(m, hall.centerpiece, base + Vector3.new(slot.side * 2, 0, 0), class.color)
		addPrompt(pedestal, "Order Info", hall.name, "ClassHall", classId)
	end
end

local function buildSpace(hub: Model, flags: { [string]: boolean })
	local space = Build.model("Space", hub)
	space.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- Earth/moon always visible with StreamingEnabled
	-- Broken Earth below
	P({ name = "Earth", shape = Enum.PartType.Ball, size = Vector3.new(2048, 2048, 2048), position = Vector3.new(0, -1500, 0), color = Color3.fromRGB(35, 80, 160), material = Enum.Material.SmoothPlastic, collide = false, parent = space })
	local crng = Random.new(99)
	for _ = 1, 9 do
		local a = crng:NextNumber(0, math.pi * 2)
		local r = crng:NextNumber(0, 350)
		local x, z = math.cos(a) * r, math.sin(a) * r
		local y = -1500 + math.sqrt(1024 ^ 2 - x * x - z * z) + 1
		P({ name = "Crack", size = Vector3.new(crng:NextNumber(120, 380), 3, crng:NextNumber(4, 10)), cframe = CFrame.new(x, y, z) * CFrame.Angles(0, crng:NextNumber(0, math.pi), 0), color = Color3.fromRGB(255, 110, 40), material = Enum.Material.Neon, collide = false, parent = space })
	end
	for _ = 1, 14 do
		local a = crng:NextNumber(0, math.pi * 2)
		local r = crng:NextNumber(0, 700)
		local x, z = math.cos(a) * r, math.sin(a) * r
		local y = -1500 + math.sqrt(1024 ^ 2 - x * x - z * z) + 6
		P({ name = "Cloud", size = Vector3.new(crng:NextNumber(80, 220), 2, crng:NextNumber(40, 120)), cframe = CFrame.new(x, y, z) * CFrame.Angles(0, crng:NextNumber(0, math.pi), 0), color = Color3.new(1, 1, 1), material = Enum.Material.SmoothPlastic, transparency = 0.35, collide = false, parent = space })
	end
	-- The moon (Mission 1 location)
	P({ name = "Moon", shape = Enum.PartType.Ball, size = Vector3.new(420, 420, 420), position = Vector3.new(1800, 500, -2200), color = Color3.fromRGB(200, 205, 215), material = Enum.Material.Slate, collide = false, parent = space })

	-- Live story changes to the hub
	if flags.EarthSignalBeam then
		P({ name = "SignalBeam", shape = Enum.PartType.Cylinder, size = Vector3.new(900, 6, 6), cframe = CFrame.new(300, -30, 500) * CFrame.Angles(0, 0, math.rad(90)), color = Color3.fromRGB(0, 255, 200), material = Enum.Material.Neon, transparency = 0.3, collide = false, parent = space })
	end
	if flags.RegimeFlares then
		for i = 1, 6 do
			P({ name = "Flare", shape = Enum.PartType.Ball, size = Vector3.new(14, 14, 14), position = Vector3.new(-400 + i * 90, -470, -300 + i * 40), color = Color3.fromRGB(255, 40, 30), material = Enum.Material.Neon, collide = false, parent = space })
		end
	end
	if flags.HollowArmada then
		local arng = Random.new(5)
		for _ = 1, 10 do
			local pos = Vector3.new(arng:NextNumber(-800, 800), arng:NextNumber(200, 450), arng:NextNumber(-1400, -900))
			P({ name = "HollowShip", wedge = true, size = Vector3.new(30, 14, 90), cframe = CFrame.lookAt(pos, Vector3.new(0, DECK_Y, 0)), color = Color3.fromRGB(40, 10, 50), material = Enum.Material.Slate, collide = false, parent = space })
			P({ name = "HollowGlow", shape = Enum.PartType.Ball, size = Vector3.new(8, 8, 8), position = pos, color = Color3.fromRGB(255, 0, 160), material = Enum.Material.Neon, collide = false, parent = space })
		end
	end
end

function HubBuilder.ApplyLighting()
	Lighting.ClockTime = 0 -- night sky = stars
	Lighting.Brightness = 2
	Lighting.Ambient = Color3.fromRGB(95, 105, 135)
	Lighting.OutdoorAmbient = Color3.fromRGB(120, 130, 160)
	Lighting.FogEnd = 100000
	Lighting.GlobalShadows = true
	workspace.Gravity = 196.2
	if not Lighting:FindFirstChildOfClass("BloomEffect") then
		local bloom = Instance.new("BloomEffect")
		bloom.Intensity = 0.8
		bloom.Size = 30
		bloom.Threshold = 0.9
		bloom.Parent = Lighting
	end
end

function HubBuilder.Build(): Model
	local existing = workspace:FindFirstChild("Hub")
	if existing then
		existing:Destroy()
	end
	local custom = ServerStorage:FindFirstChild("Maps") and ServerStorage.Maps:FindFirstChild("Hub")
	if custom then
		local hub = custom:Clone()
		hub.Parent = workspace
		HubBuilder.ApplyLighting()
		return hub
	end

	local hub = Instance.new("Model")
	hub.Name = "Hub"
	local flags: { [string]: boolean } = {}
	for _, f in Story.currentChapter().hubFlags or {} do
		flags[f] = true
	end
	buildShip(hub)
	buildSkydeck(hub)
	buildModules(hub)
	buildTrusses(hub)
	buildClassHalls(hub)
	buildSpace(hub, flags)
	hub.Parent = workspace
	HubBuilder.ApplyLighting()
	return hub
end

HubBuilder.SpawnCFrame = CFrame.new(-80, DECK_Y + 5, 0)

return HubBuilder
