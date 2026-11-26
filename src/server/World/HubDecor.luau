-- Set dressing for the Meridian: NPC crew, the Starfall monument, gardens, lamps, consoles,
-- cargo, antennas, flying traffic and a better sky. Called by HubBuilder after the structure.
-- Moving things (traffic, spinning holograms, blinking lights) are tagged and animated on the
-- client by Controllers/Ambience, so they're smooth and cost the server nothing.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")

local Build = require(script.Parent.Build)
local P = Build.part

local HubDecor = {}

local HULL = Color3.fromRGB(205, 210, 220)
local HULL_DARK = Color3.fromRGB(120, 125, 140)
local TRIM = Color3.fromRGB(60, 200, 255)
local GOLD = Color3.fromRGB(210, 170, 80)

-- R15 idle animation from Roblox's default Animate script
local IDLE_ANIMATION = "rbxassetid://507766388"

local function tag(inst: Instance, name: string, attrs: { [string]: any }?)
	for k, v in attrs or {} do
		inst:SetAttribute(k, v)
	end
	CollectionService:AddTag(inst, name)
end

-- ===== NPC crew =====

-- A real R15 avatar (default body), anchored in place, with a name tag and an idle animation.
function HubDecor.Npc(parent: Instance, name: string, title: string, cf: CFrame, color: Color3?)
	local ok, model = pcall(function()
		local desc = Instance.new("HumanoidDescription")
		local skin = Color3.fromRGB(234, 184, 146)
		desc.HeadColor = skin
		desc.LeftArmColor = skin
		desc.RightArmColor = skin
		desc.TorsoColor = color or Color3.fromRGB(60, 70, 95)
		desc.LeftLegColor = Color3.fromRGB(40, 44, 58)
		desc.RightLegColor = Color3.fromRGB(40, 44, 58)
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		return nil
	end
	local npc = model :: Model
	npc.Name = name
	local hum = npc:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	local root = npc:FindFirstChild("HumanoidRootPart") :: BasePart?
	npc:PivotTo(cf + Vector3.new(0, 3, 0))
	if root then
		root.Anchored = true
	end
	npc.Parent = parent

	local head = npc:FindFirstChild("Head") :: BasePart?
	if head then
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(180, 40)
		gui.StudsOffset = Vector3.new(0, 2.2, 0)
		gui.MaxDistance = 60
		gui.Parent = head
		for i, text in { name, title } do
			local label = Instance.new("TextLabel")
			label.Size = UDim2.new(1, 0, 0.5, 0)
			label.Position = UDim2.fromScale(0, (i - 1) * 0.5)
			label.BackgroundTransparency = 1
			label.Font = if i == 1 then Enum.Font.GothamBold else Enum.Font.Gotham
			label.TextScaled = true
			label.TextColor3 = if i == 1 then Color3.new(1, 1, 1) else (color or TRIM)
			label.TextStrokeTransparency = 0.4
			label.Text = text
			label.Parent = gui
		end
	end

	-- Idle animation (best effort, once the NPC is in the workspace)
	task.delay(2, function()
		local animator = hum and hum:FindFirstChildOfClass("Animator")
		if animator then
			pcall(function()
				local anim = Instance.new("Animation")
				anim.AnimationId = IDLE_ANIMATION
				local track = animator:LoadAnimation(anim)
				track.Looped = true
				track:Play()
			end)
		end
	end)
	return npc
end

-- ===== Props =====

local function tree(parent: Instance, pos: Vector3, scale: number)
	P({ name = "Planter", size = Vector3.new(6, 2, 6) * scale, position = pos + Vector3.new(0, 1, 0) * scale, color = HULL_DARK, material = Enum.Material.Metal, parent = parent })
	P({ name = "PlanterGlow", size = Vector3.new(6.2, 0.3, 6.2) * scale, position = pos + Vector3.new(0, 2, 0) * scale, color = Color3.fromRGB(90, 230, 130), material = Enum.Material.Neon, collide = false, parent = parent })
	P({ name = "Trunk", shape = Enum.PartType.Cylinder, size = Vector3.new(7, 1, 1) * scale, cframe = CFrame.new(pos + Vector3.new(0, 5.5, 0) * scale) * CFrame.Angles(0, 0, math.rad(90)), color = Color3.fromRGB(105, 75, 50), material = Enum.Material.Wood, parent = parent })
	for i, off in { Vector3.new(0, 9, 0), Vector3.new(1.6, 8, 1), Vector3.new(-1.5, 8.3, -0.8) } do
		P({
			name = "Leaves",
			shape = Enum.PartType.Ball,
			size = Vector3.new(5, 5, 5) * scale * (if i == 1 then 1 else 0.75),
			position = pos + off * scale,
			color = Color3.fromRGB(70, 160 + i * 15, 90),
			material = Enum.Material.Grass,
			collide = false,
			parent = parent,
		})
	end
end

local function lamp(parent: Instance, pos: Vector3)
	P({ name = "LampPost", size = Vector3.new(0.6, 9, 0.6), position = pos + Vector3.new(0, 4.5, 0), color = HULL_DARK, material = Enum.Material.Metal, parent = parent })
	P({ name = "LampHead", shape = Enum.PartType.Ball, size = Vector3.new(1.6, 1.6, 1.6), position = pos + Vector3.new(0, 9.4, 0), color = Color3.fromRGB(200, 235, 255), material = Enum.Material.Neon, collide = false, light = { color = Color3.fromRGB(180, 220, 255), range = 22, brightness = 1.6 }, parent = parent })
end

local function crate(parent: Instance, pos: Vector3, size: number, color: Color3)
	local c = P({ name = "Crate", size = Vector3.new(size, size, size), cframe = CFrame.new(pos + Vector3.new(0, size / 2, 0)) * CFrame.Angles(0, math.rad(math.random(-20, 20)), 0), color = color, material = Enum.Material.DiamondPlate, parent = parent })
	P({ name = "CrateBand", size = Vector3.new(size + 0.1, 0.3, size + 0.1), cframe = c.CFrame, color = Color3.fromRGB(255, 200, 60), material = Enum.Material.Neon, collide = false, parent = parent })
end

local function console(parent: Instance, cf: CFrame, color: Color3)
	P({ name = "ConsoleDesk", size = Vector3.new(6, 3, 2.5), cframe = cf * CFrame.new(0, 1.5, 0), color = HULL_DARK, material = Enum.Material.Metal, parent = parent })
	local screen = P({ name = "ConsoleScreen", size = Vector3.new(5, 2.6, 0.2), cframe = cf * CFrame.new(0, 4.4, 0.6) * CFrame.Angles(math.rad(-15), 0, 0), color = color, material = Enum.Material.Neon, transparency = 0.15, collide = false, parent = parent })
	tag(screen, "Blinker", { Period = 2 + math.random() * 2, MinT = 0.05, MaxT = 0.35 })
end

local function shuttle(parent: Instance, color: Color3): Model
	local m = Instance.new("Model")
	m.Name = "Traffic"
	local body = P({ name = "Body", size = Vector3.new(4, 2.5, 12), position = Vector3.zero, color = Color3.fromRGB(225, 228, 235), material = Enum.Material.Metal, collide = false, parent = m })
	P({ name = "Wing", size = Vector3.new(14, 0.5, 4), position = Vector3.new(0, -0.4, 1.5), color = HULL_DARK, material = Enum.Material.Metal, collide = false, parent = m })
	P({ name = "Engine", shape = Enum.PartType.Ball, size = Vector3.new(2.2, 2.2, 2.2), position = Vector3.new(0, 0, 6.2), color = color, material = Enum.Material.Neon, collide = false, light = { color = color, range = 18, brightness = 2 }, parent = m })
	P({ name = "Cockpit", size = Vector3.new(2.6, 1.2, 3), position = Vector3.new(0, 1.2, -3.5), color = Color3.fromRGB(90, 160, 230), material = Enum.Material.Glass, transparency = 0.3, collide = false, parent = m })
	m.PrimaryPart = body
	m.Parent = parent
	return m
end

-- ===== Areas =====

local function decorateSkydeck(hub: Model, y: number)
	local deck = Build.model("SkydeckDecor", hub)

	-- Floor pattern: darker inlaid panels so the deck isn't a white sheet
	for x = -105, 105, 30 do
		P({ name = "FloorPanel", size = Vector3.new(26, 0.08, 30), position = Vector3.new(x, y + 1.04, 18), color = Color3.fromRGB(70, 78, 98), material = Enum.Material.Metal, collide = false, parent = deck })
		P({ name = "FloorPanel", size = Vector3.new(26, 0.08, 30), position = Vector3.new(x, y + 1.04, -18), color = Color3.fromRGB(70, 78, 98), material = Enum.Material.Metal, collide = false, parent = deck })
	end

	-- The Starfall monument: a floating crystal over a ring
	local base = Vector3.new(0, y + 1, 8)
	P({ name = "MonumentBase", shape = Enum.PartType.Cylinder, size = Vector3.new(1.2, 14, 14), cframe = CFrame.new(base + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, 0, math.rad(90)), color = HULL_DARK, material = Enum.Material.Metal, parent = deck })
	local ring = P({ name = "MonumentRing", shape = Enum.PartType.Cylinder, size = Vector3.new(0.4, 15, 15), cframe = CFrame.new(base + Vector3.new(0, 1.3, 0)) * CFrame.Angles(0, 0, math.rad(90)), color = TRIM, material = Enum.Material.Neon, transparency = 0.2, collide = false, parent = deck })
	tag(ring, "Blinker", { Period = 3, MinT = 0, MaxT = 0.5 })
	local crystal = P({ name = "StarfallShard", size = Vector3.new(3, 7, 3), cframe = CFrame.new(base + Vector3.new(0, 7, 0)) * CFrame.Angles(0, 0, math.rad(12)), color = Color3.fromRGB(255, 220, 140), material = Enum.Material.Neon, collide = false, light = { color = Color3.fromRGB(255, 210, 130), range = 40, brightness = 3 }, parent = deck })
	tag(crystal, "Spinner", { Speed = 0.6, Bob = 0.8 })
	for i = 1, 4 do
		local a = i / 4 * math.pi * 2
		local shard = P({ name = "OrbitShard", size = Vector3.new(0.8, 2, 0.8), position = base + Vector3.new(math.cos(a) * 5, 6, math.sin(a) * 5), color = Color3.fromRGB(255, 200, 100), material = Enum.Material.Neon, collide = false, parent = deck })
		tag(shard, "Spinner", { Speed = 1.5, Bob = 0.5 })
	end

	-- Gardens and lamps along the railings
	for _, x in { -105, -45, 45, 105 } do
		for _, z in { -32, 32 } do
			tree(deck, Vector3.new(x, y + 1, z), 1)
		end
	end
	for _, x in { -90, -60, -20, 20, 60, 90 } do
		for _, z in { -37, 37 } do
			lamp(deck, Vector3.new(x, y + 1, z))
		end
	end

	-- Class banners hanging between the shield pylons
	local bannerColors = { Color3.fromRGB(230, 150, 60), Color3.fromRGB(150, 110, 255), Color3.fromRGB(70, 200, 255), Color3.fromRGB(90, 230, 130), Color3.fromRGB(255, 220, 70) }
	for i, color in bannerColors do
		local x = -100 + (i - 1) * 50
		P({ name = "BannerPole", size = Vector3.new(0.4, 16, 0.4), position = Vector3.new(x, y + 9, -38.5), color = HULL_DARK, material = Enum.Material.Metal, parent = deck })
		local flag = P({ name = "Banner", size = Vector3.new(6, 9, 0.2), position = Vector3.new(x + 3.2, y + 12, -38.5), color = color, material = Enum.Material.Fabric, collide = false, parent = deck })
		P({ name = "BannerTrim", size = Vector3.new(6, 0.4, 0.25), position = flag.Position - Vector3.new(0, 4.4, 0), color = GOLD, material = Enum.Material.Neon, collide = false, parent = deck })
	end

	-- Crew hanging out on the deck
	HubDecor.Npc(deck, "Ensign Mara", "Skydeck Watch", CFrame.lookAt(Vector3.new(-70, y + 1, 20), Vector3.new(-80, y + 1, 0)), TRIM)
	HubDecor.Npc(deck, "Tomas", "Off-duty pilot", CFrame.lookAt(Vector3.new(30, y + 1, -22), Vector3.new(38, y + 1, -22)), Color3.fromRGB(200, 90, 70))
	HubDecor.Npc(deck, "Iko", "Off-duty pilot", CFrame.lookAt(Vector3.new(38, y + 1, -22), Vector3.new(30, y + 1, -22)), Color3.fromRGB(90, 120, 200))
end

local function decorateCommandDeck(hub: Model, y: number)
	local cmd = Build.model("CommandDecor", hub)
	-- Rows of consoles along both walls
	for _, x in { -225, -210, -165, -150 } do
		console(cmd, CFrame.new(x, y + 0.4, -31), TRIM)
		console(cmd, CFrame.new(x, y + 0.4, 27) * CFrame.Angles(0, math.pi, 0), Color3.fromRGB(255, 190, 90))
	end
	-- Holographic Earth over the Mission Table
	local holo = P({ name = "HoloEarth", shape = Enum.PartType.Ball, size = Vector3.new(6, 6, 6), position = Vector3.new(-185, y + 9, 0), color = Color3.fromRGB(80, 170, 255), material = Enum.Material.Neon, transparency = 0.45, collide = false, parent = cmd })
	tag(holo, "Spinner", { Speed = 0.4, Bob = 0.4 })
	local orbit = P({ name = "HoloOrbit", shape = Enum.PartType.Cylinder, size = Vector3.new(0.15, 11, 11), cframe = CFrame.new(-185, y + 9, 0) * CFrame.Angles(math.rad(20), 0, math.rad(90)), color = TRIM, material = Enum.Material.Neon, transparency = 0.4, collide = false, parent = cmd })
	tag(orbit, "Spinner", { Speed = -0.8 })
	-- Crew
	HubDecor.Npc(cmd, "Commander Hale", "Fleet Command", CFrame.lookAt(Vector3.new(-176, y + 0.4, -9), Vector3.new(-185, y + 0.4, 0)), Color3.fromRGB(40, 50, 80))
	HubDecor.Npc(cmd, "Operator Venn", "SOL Liaison", CFrame.lookAt(Vector3.new(-220, y + 0.4, -6), Vector3.new(-232, y + 0.4, 0)), Color3.fromRGB(255, 200, 90))
	HubDecor.Npc(cmd, "Lt. Osei", "Comms", CFrame.lookAt(Vector3.new(-210, y + 0.4, -27), Vector3.new(-210, y + 0.4, -40)), TRIM)
end

local function decorateHangar(hub: Model, y: number)
	local hangar = Build.model("HangarDecor", hub)
	for i, pos in { Vector3.new(150, y, -28), Vector3.new(156, y, -28), Vector3.new(150, y, -22), Vector3.new(153, y + 4, -26) } do
		crate(hangar, pos, if i == 4 then 3.5 else 5, Color3.fromRGB(70, 80, 70))
	end
	for _, z in { -30, -22 } do
		P({ name = "FuelTank", shape = Enum.PartType.Cylinder, size = Vector3.new(9, 6, 6), cframe = CFrame.new(228, y + 4.5, z) * CFrame.Angles(0, 0, math.rad(90)), color = Color3.fromRGB(200, 90, 60), material = Enum.Material.Metal, parent = hangar })
	end
	P({ name = "Crane", size = Vector3.new(1, 26, 1), position = Vector3.new(210, y + 13, 20), color = Color3.fromRGB(230, 190, 50), material = Enum.Material.Metal, parent = hangar })
	P({ name = "CraneArm", size = Vector3.new(30, 1, 1), position = Vector3.new(196, y + 26, 20), color = Color3.fromRGB(230, 190, 50), material = Enum.Material.Metal, parent = hangar })
	HubDecor.Npc(hangar, "Kade", "Chief Mechanic", CFrame.lookAt(Vector3.new(165, y + 0.4, -12), Vector3.new(185, y + 0.4, 0)), Color3.fromRGB(230, 150, 60))
	HubDecor.Npc(hangar, "Pilot Reyes", "Shuttle Pilot", CFrame.lookAt(Vector3.new(200, y + 0.4, 12), Vector3.new(185, y + 0.4, 0)), Color3.fromRGB(90, 120, 200))
end

local function decorateHull(hub: Model, y: number)
	local hull = Build.model("HullDecor", hub)
	-- Comms tower over the Command Deck with a blinking beacon and a dish
	P({ name = "Mast", size = Vector3.new(1.2, 40, 1.2), position = Vector3.new(-200, y + 50, 0), color = HULL, material = Enum.Material.Metal, parent = hull })
	local beacon = P({ name = "MastBeacon", shape = Enum.PartType.Ball, size = Vector3.new(2.4, 2.4, 2.4), position = Vector3.new(-200, y + 71, 0), color = Color3.fromRGB(255, 50, 50), material = Enum.Material.Neon, collide = false, light = { color = Color3.fromRGB(255, 50, 50), range = 30, brightness = 3 }, parent = hull })
	tag(beacon, "Blinker", { Period = 1.2, MinT = 0, MaxT = 0.9 })
	local dish = P({ name = "Dish", shape = Enum.PartType.Cylinder, size = Vector3.new(1, 16, 16), cframe = CFrame.new(-165, y + 40, 0) * CFrame.Angles(0, 0, math.rad(60)), color = HULL, material = Enum.Material.Metal, parent = hull })
	tag(dish, "Spinner", { Speed = 0.15, Axis = "World" })
	-- Panel lines and running lights along the hull sides
	for x = -240, 240, 40 do
		for _, z in { -40.3, 40.3 } do
			P({ name = "PanelLine", size = Vector3.new(0.4, 36, 0.3), position = Vector3.new(x, y - 20, z), color = HULL_DARK, material = Enum.Material.Metal, collide = false, parent = hull })
			local light = P({ name = "RunningLight", shape = Enum.PartType.Ball, size = Vector3.new(1.2, 1.2, 1.2), position = Vector3.new(x + 20, y - 4, z), color = if z < 0 then Color3.fromRGB(255, 60, 60) else Color3.fromRGB(60, 255, 120), material = Enum.Material.Neon, collide = false, parent = hull })
			tag(light, "Blinker", { Period = 2, MinT = 0, MaxT = 0.8, Offset = (x + 240) / 160 })
		end
	end
end

local function traffic(hub: Model, y: number)
	local fleet = Build.model("TrafficFleet", hub)
	fleet.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	local colors = { TRIM, Color3.fromRGB(255, 150, 60), Color3.fromRGB(150, 110, 255), Color3.fromRGB(90, 230, 130) }
	for i = 1, 7 do
		local m = shuttle(fleet, colors[(i % #colors) + 1])
		local cy, r, phase = y + 30 + (i % 3) * 35, 240 + i * 45, i * 0.9
		m:PivotTo(CFrame.new(math.cos(phase) * r, cy, math.sin(phase) * r))
		tag(m, "Orbiter", {
			CenterY = cy,
			Radius = r,
			Speed = (0.05 + (i % 4) * 0.015) * (if i % 2 == 0 then 1 else -1),
			Phase = phase,
		})
	end
end

function HubDecor.ApplySky()
	local sky = Lighting:FindFirstChildOfClass("Sky") or Instance.new("Sky")
	sky.StarCount = 5000
	sky.CelestialBodiesShown = true
	sky.Parent = Lighting
	local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect") or Instance.new("ColorCorrectionEffect")
	cc.Contrast = 0.12
	cc.Saturation = 0.18
	cc.TintColor = Color3.fromRGB(235, 240, 255)
	cc.Parent = Lighting
	local rays = Lighting:FindFirstChildOfClass("SunRaysEffect") or Instance.new("SunRaysEffect")
	rays.Intensity = 0.06
	rays.Parent = Lighting
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.8
end

function HubDecor.Decorate(hub: Model, deckY: number)
	for name, fn in {
		Skydeck = decorateSkydeck,
		CommandDeck = decorateCommandDeck,
		Hangar = decorateHangar,
		Hull = decorateHull,
		Traffic = traffic,
	} do
		local ok, err = pcall(fn, hub, deckY)
		if not ok then
			warn("[HubDecor] " .. name .. " failed:", err)
		end
	end
	HubDecor.ApplySky()
end

return HubDecor
