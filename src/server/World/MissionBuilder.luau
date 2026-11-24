-- Builds a playable blockout map for a mission: a start pad, then one arena "zone" per
-- objective step, joined by bridges. Themed by the mission's `theme` config.
--
-- Hand-built maps: put a Model named <missionId> in ServerStorage.Maps containing
--   Start      (BasePart)            where the fireteam spawns
--   Zone1..N   (BasePart)            center of each zone, with optional children:
--       Spawn* (BaseParts)          enemy spawn points
--       Pad*   (BaseParts)          capture pads
--       Path*  (BaseParts, ordered) escort drone path
-- The builder reads those instead of generating geometry.

local Lighting = game:GetService("Lighting")
local ServerStorage = game:GetService("ServerStorage")

local Build = require(script.Parent.Build)
local P = Build.part

local MissionBuilder = {}

export type Zone = {
	center: Vector3,
	size: number,
	checkpoint: CFrame,
	spawnPoints: { Vector3 },
	pads: { BasePart },
	dronePath: { Vector3 },
	beacon: BasePart?,
}

export type Layout = {
	model: Model,
	start: CFrame,
	zones: { Zone },
}

local ZONE = 140
local BOSS_ZONE = 190
local BRIDGE = 50
local WALL_H = 7
local DOOR = 26

local function spawnRing(center: Vector3, radius: number, count: number): { Vector3 }
	local list = {}
	for i = 1, count do
		local a = (i / count) * math.pi * 2
		table.insert(list, center + Vector3.new(math.cos(a) * radius, 1, math.sin(a) * radius))
	end
	return list
end

local function buildZone(model: Model, def, index: number, step, startX: number, origin: Vector3): Zone
	local theme = def.theme
	local isBoss = step.type == "Boss"
	local size = if isBoss then BOSS_ZONE else ZONE
	local center = Vector3.new(startX + size / 2, origin.Y, origin.Z)
	local zoneModel = Build.model("Zone" .. index, model)
	local rng = Random.new(def.order * 1000 + index)

	-- Floor
	P({
		name = "Floor",
		size = Vector3.new(size, 4, size),
		position = center - Vector3.new(0, 2, 0),
		color = theme.floorColor,
		material = theme.floorMaterial,
		parent = zoneModel,
	})

	-- Walls (with doorways on the -X / +X sides)
	local half = size / 2
	local wallY = center.Y + WALL_H / 2
	for _, zSide in { -1, 1 } do
		P({
			name = "Wall",
			size = Vector3.new(size, WALL_H, 3),
			position = Vector3.new(center.X, wallY, center.Z + zSide * half),
			color = theme.coverColor,
			material = theme.coverMaterial,
			parent = zoneModel,
		})
	end
	local seg = (size - DOOR) / 2
	for _, xSide in { -1, 1 } do
		for _, zSide in { -1, 1 } do
			P({
				name = "Wall",
				size = Vector3.new(3, WALL_H, seg),
				position = Vector3.new(center.X + xSide * half, wallY, center.Z + zSide * (DOOR / 2 + seg / 2)),
				color = theme.coverColor,
				material = theme.coverMaterial,
				parent = zoneModel,
			})
		end
	end
	-- Accent strip on top of the walls
	for _, zSide in { -1, 1 } do
		P({
			name = "Accent",
			size = Vector3.new(size, 0.5, 3.2),
			position = Vector3.new(center.X, center.Y + WALL_H + 0.25, center.Z + zSide * half),
			color = theme.accentColor,
			material = Enum.Material.Neon,
			collide = false,
			parent = zoneModel,
		})
	end

	-- Cover (keeps a clear lane through the middle)
	local coverCount = if isBoss then 10 else 16
	for _ = 1, coverCount do
		local sx, sy, sz = rng:NextNumber(4, 14), rng:NextNumber(4, 10), rng:NextNumber(4, 14)
		local lx, lz = rng:NextNumber(-half + 12, half - 12), rng:NextNumber(-half + 12, half - 12)
		if math.abs(lz) > 10 and Vector2.new(lx, lz).Magnitude > 20 then
			local block = P({
				name = "Cover",
				size = Vector3.new(sx, sy, sz),
				cframe = CFrame.new(center + Vector3.new(lx, sy / 2, lz))
					* CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
				color = theme.coverColor,
				material = theme.coverMaterial,
				parent = zoneModel,
			})
			if rng:NextNumber() < 0.3 then
				P({
					name = "CoverGlow",
					size = Vector3.new(sx + 0.2, 0.4, sz + 0.2),
					cframe = block.CFrame * CFrame.new(0, sy / 2 - 0.5, 0),
					color = theme.accentColor,
					material = Enum.Material.Neon,
					collide = false,
					parent = zoneModel,
				})
			end
		end
	end

	-- Skyline / scenery outside the walls
	for _ = 1, 8 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(half + 30, half + 120)
		local h = rng:NextNumber(30, 120)
		P({
			name = "Scenery",
			size = Vector3.new(rng:NextNumber(15, 40), h, rng:NextNumber(15, 40)),
			position = center + Vector3.new(math.cos(a) * r, h / 2 - 20, math.sin(a) * r),
			color = theme.coverColor:Lerp(Color3.new(0, 0, 0), 0.3),
			material = theme.coverMaterial,
			collide = false,
			parent = zoneModel,
		})
	end

	-- Objective beacon (tall light column, shown by MissionService when this zone is active)
	local beacon = P({
		name = "Beacon",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(120, 3, 3),
		cframe = CFrame.new(center + Vector3.new(0, 60, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		color = theme.accentColor,
		material = Enum.Material.Neon,
		transparency = 1,
		collide = false,
		parent = zoneModel,
	})

	-- Capture pads
	local pads = {}
	local padCount = step.points or 0
	for i = 1, padCount do
		local a = (i / padCount) * math.pi * 2 + math.pi / 4
		local pos = center + Vector3.new(math.cos(a) * 38, 0.2, math.sin(a) * 38)
		local pad = P({
			name = "Pad" .. i,
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(0.4, 14, 14),
			cframe = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)),
			color = Color3.new(1, 1, 1),
			material = Enum.Material.Neon,
			transparency = 0.4,
			collide = false,
			parent = zoneModel,
		})
		table.insert(pads, pad)
	end

	-- Escort path: straight through the middle lane
	local dronePath = {}
	if step.type == "Escort" then
		for i = 0, 4 do
			table.insert(dronePath, center + Vector3.new(-half + 10 + i * (size - 20) / 4, 6, 0))
		end
	end

	-- Mission-specific set pieces
	if def.id == "WakeProtocol" and index == 1 then
		local wreck = Build.model("CrashedShuttle", zoneModel)
		P({
			size = Vector3.new(36, 9, 15),
			cframe = CFrame.new(center + Vector3.new(20, 3, 24))
				* CFrame.Angles(math.rad(12), math.rad(25), math.rad(-8)),
			color = Color3.fromRGB(230, 230, 235),
			material = Enum.Material.Metal,
			parent = wreck,
		})
		P({
			size = Vector3.new(3, 3, 3),
			position = center + Vector3.new(30, 9, 26),
			color = Color3.fromRGB(255, 120, 40),
			material = Enum.Material.Neon,
			collide = false,
			light = { color = Color3.fromRGB(255, 120, 40), range = 30, brightness = 3 },
			parent = wreck,
		})
	end

	return {
		center = center,
		size = size,
		checkpoint = CFrame.new(
			Vector3.new(startX + 8, origin.Y + 4, origin.Z),
			Vector3.new(startX + 100, origin.Y + 4, origin.Z)
		),
		spawnPoints = spawnRing(center, size * 0.38, 10),
		pads = pads,
		dronePath = dronePath,
		beacon = beacon,
	}
end

local function readCustomMap(def, custom: Model): Layout
	local model = custom:Clone()
	model.Parent = workspace
	local start = model:FindFirstChild("Start") :: BasePart
	local zones = {}
	for i = 1, #def.steps do
		local zonePart = model:FindFirstChild("Zone" .. i) :: BasePart
		assert(zonePart, ("Map %s is missing Zone%d"):format(def.id, i))
		local spawns, pads, path = {}, {}, {}
		local pathParts = {}
		for _, child in zonePart:GetChildren() do
			if child:IsA("BasePart") then
				if child.Name:sub(1, 5) == "Spawn" then
					table.insert(spawns, child.Position)
				elseif child.Name:sub(1, 3) == "Pad" then
					table.insert(pads, child)
				elseif child.Name:sub(1, 4) == "Path" then
					table.insert(pathParts, child)
				end
			end
		end
		table.sort(pathParts, function(a, b)
			return (tonumber(a.Name:sub(5)) or 0) < (tonumber(b.Name:sub(5)) or 0)
		end)
		for _, part in pathParts do
			table.insert(path, part.Position)
		end
		if #spawns == 0 then
			spawns = spawnRing(zonePart.Position, 50, 10)
		end
		table.insert(zones, {
			center = zonePart.Position,
			size = math.max(zonePart.Size.X, zonePart.Size.Z),
			checkpoint = zonePart.CFrame + Vector3.new(0, 5, 0),
			spawnPoints = spawns,
			pads = pads,
			dronePath = path,
			beacon = nil,
		})
	end
	return { model = model, start = start.CFrame + Vector3.new(0, 4, 0), zones = zones }
end

-- origin: where the map starts (mission servers use 0,0,0; Studio test missions use an offset)
function MissionBuilder.Build(def, origin: Vector3): Layout
	local custom = ServerStorage:FindFirstChild("Maps") and ServerStorage.Maps:FindFirstChild(def.id)
	if custom then
		return readCustomMap(def, custom)
	end

	local model = Instance.new("Model")
	model.Name = "Mission_" .. def.id
	local theme = def.theme

	-- Start pad (landing zone)
	local startCenter = origin + Vector3.new(-30, 0, 0)
	P({
		name = "StartPad",
		size = Vector3.new(60, 4, 60),
		position = startCenter - Vector3.new(0, 2, 0),
		color = theme.floorColor,
		material = theme.floorMaterial,
		parent = model,
	})
	P({
		name = "StartRing",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.3, 24, 24),
		cframe = CFrame.new(startCenter + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		color = theme.accentColor,
		material = Enum.Material.Neon,
		transparency = 0.5,
		collide = false,
		parent = model,
	})

	local zones = {}
	local x = origin.X + BRIDGE
	-- bridge from start pad to zone 1
	P({
		name = "Bridge",
		size = Vector3.new(BRIDGE + 4, 3, DOOR - 2),
		position = Vector3.new(origin.X + BRIDGE / 2, origin.Y - 1.5, origin.Z),
		color = theme.floorColor:Lerp(Color3.new(0, 0, 0), 0.2),
		material = theme.floorMaterial,
		parent = model,
	})
	for i, step in def.steps do
		local zone = buildZone(model, def, i, step, x, origin)
		table.insert(zones, zone)
		x += zone.size
		if i < #def.steps then
			P({
				name = "Bridge",
				size = Vector3.new(BRIDGE + 4, 3, DOOR - 2),
				position = Vector3.new(x + BRIDGE / 2, origin.Y - 1.5, origin.Z),
				color = theme.floorColor:Lerp(Color3.new(0, 0, 0), 0.2),
				material = theme.floorMaterial,
				parent = model,
			})
			x += BRIDGE
		end
	end

	model.Parent = workspace

	if theme.hasWater then
		local min = Vector3.new(origin.X - 200, origin.Y - 40, origin.Z - 300)
		local max = Vector3.new(x + 200, origin.Y - 6, origin.Z + 300)
		workspace.Terrain:FillBlock(CFrame.new((min + max) / 2), max - min, Enum.Material.Water)
	end

	return {
		model = model,
		start = CFrame.new(startCenter + Vector3.new(0, 4, 0), startCenter + Vector3.new(100, 4, 0)),
		zones = zones,
	}
end

local savedLighting: { [string]: any }? = nil

function MissionBuilder.ApplyTheme(theme)
	savedLighting = {
		ClockTime = Lighting.ClockTime,
		Ambient = Lighting.Ambient,
		OutdoorAmbient = Lighting.OutdoorAmbient,
		FogColor = Lighting.FogColor,
		FogEnd = Lighting.FogEnd,
		Gravity = workspace.Gravity,
	}
	Lighting.ClockTime = theme.clockTime
	Lighting.Ambient = theme.ambient
	Lighting.OutdoorAmbient = theme.ambient
	Lighting.FogColor = theme.fogColor
	Lighting.FogEnd = theme.fogEnd
	workspace.Gravity = theme.gravity
	if workspace:GetAttribute("Modifier") == "LowGravity" then
		workspace.Gravity *= 0.5
	end
end

function MissionBuilder.RestoreTheme()
	if not savedLighting then
		return
	end
	local s = savedLighting :: { [string]: any }
	Lighting.ClockTime = s.ClockTime
	Lighting.Ambient = s.Ambient
	Lighting.OutdoorAmbient = s.OutdoorAmbient
	Lighting.FogColor = s.FogColor
	Lighting.FogEnd = s.FogEnd
	workspace.Gravity = s.Gravity
	savedLighting = nil
end

function MissionBuilder.Clear(layout: Layout)
	layout.model:Destroy()
	workspace.Terrain:Clear()
end

return MissionBuilder
