-- Player rockets (straight projectiles that explode on impact) and ammo bricks
-- (pickups dropped by enemies). No gameplay rules here: callers pass what happens.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Ordnance = {}

local folder = Instance.new("Folder")
folder.Name = "Pickups"
folder.Parent = workspace

type Rocket = {
	part: BasePart,
	velocity: Vector3,
	params: RaycastParams,
	expires: number,
	onImpact: (Vector3) -> (),
}
local rockets: { Rocket } = {}

type Brick = { part: BasePart, ammoType: string, expires: number, onPickup: (Player) -> boolean }
local bricks: { Brick } = {}

local AMMO_COLORS = {
	special = Color3.fromRGB(90, 255, 120),
	heavy = Color3.fromRGB(190, 90, 255),
}

function Ordnance.FireRocket(
	origin: Vector3,
	direction: Vector3,
	speed: number,
	params: RaycastParams,
	onImpact: (Vector3) -> ()
)
	local part = Instance.new("Part")
	part.Name = "Rocket"
	part.Size = Vector3.new(0.6, 0.6, 2.2)
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(255, 160, 60)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CFrame = CFrame.lookAt(origin, origin + direction)
	local light = Instance.new("PointLight")
	light.Color = part.Color
	light.Range = 14
	light.Parent = part
	part.Parent = folder
	table.insert(rockets, {
		part = part,
		velocity = direction.Unit * speed,
		params = params,
		expires = os.clock() + 5,
		onImpact = onImpact,
	})
end

function Ordnance.SpawnAmmoBrick(position: Vector3, ammoType: string, onPickup: (Player) -> boolean)
	local part = Instance.new("Part")
	part.Name = "AmmoBrick_" .. ammoType
	part.Size = Vector3.new(1.4, 1.4, 1.4)
	part.Material = Enum.Material.Neon
	part.Color = AMMO_COLORS[ammoType] or Color3.new(1, 1, 1)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CastShadow = false
	part.CFrame = CFrame.new(position + Vector3.new(0, 1.5, 0)) * CFrame.Angles(math.rad(45), math.rad(45), 0)
	local light = Instance.new("PointLight")
	light.Color = part.Color
	light.Range = 10
	light.Parent = part
	part.Parent = folder
	table.insert(bricks, { part = part, ammoType = ammoType, expires = os.clock() + 30, onPickup = onPickup })
end

function Ordnance.Clear()
	for _, r in rockets do
		r.part:Destroy()
	end
	table.clear(rockets)
	for _, b in bricks do
		b.part:Destroy()
	end
	table.clear(bricks)
end

local function step(dt: number)
	for i = #rockets, 1, -1 do
		local r = rockets[i]
		local from = r.part.Position
		local move = r.velocity * dt
		local hit = workspace:Raycast(from, move, r.params)
		if hit or os.clock() > r.expires then
			local at = if hit then hit.Position else from
			r.part:Destroy()
			table.remove(rockets, i)
			task.spawn(r.onImpact, at)
		else
			r.part.CFrame = CFrame.lookAt(from + move, from + move * 2)
		end
	end

	local t = os.clock()
	for i = #bricks, 1, -1 do
		local b = bricks[i]
		if t > b.expires or not b.part.Parent then
			b.part:Destroy()
			table.remove(bricks, i)
			continue
		end
		b.part.CFrame *= CFrame.Angles(0, dt * 2, 0) -- spin
		for _, p in Players:GetPlayers() do
			local char = p.Character
			local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and (root.Position - b.part.Position).Magnitude < 5 and b.onPickup(p) then
				b.part:Destroy()
				table.remove(bricks, i)
				break
			end
		end
	end
end

RunService.Heartbeat:Connect(function(dt)
	local ok, err = pcall(step, dt)
	if not ok then
		warn("[Ordnance]", err)
	end
end)

return Ordnance
