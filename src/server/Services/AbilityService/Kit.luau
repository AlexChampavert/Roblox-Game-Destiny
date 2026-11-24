-- Shared helpers for ability implementations (init, Grenades, Melee).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)

local CombatService = require(script.Parent.Parent.CombatService)

local Kit = {}

export type Ctx = {
	player: Player,
	char: Model,
	hum: Humanoid,
	root: BasePart,
	aim: Vector3, -- world point the player is aiming at
	look: Vector3, -- flat look direction
	element: string?, -- the class element
}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function effect(kind: string, data: any)
	Net.event("Effect"):FireAllClients(kind, data)
end

local function impulse(player: Player, velocity: Vector3, duration: number)
	Net.event("Effect"):FireClient(player, "Impulse", { velocity = velocity, duration = duration })
end

local function enemiesInRadius(pos: Vector3, radius: number): { Model }
	local list = {}
	for _, model in CollectionService:GetTagged("Enemy") do
		local hum = model:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 and model.PrimaryPart then
			if (model.PrimaryPart.Position - pos).Magnitude <= radius then
				table.insert(list, model)
			end
		end
	end
	return list
end

local function alliesInRadius(pos: Vector3, radius: number): { Player }
	local list = {}
	for _, p in Players:GetPlayers() do
		local _, _, root = CombatService.GetAlive(p)
		if root and (root.Position - pos).Magnitude <= radius then
			table.insert(list, p)
		end
	end
	return list
end

local function zonePart(
	name: string,
	pos: Vector3,
	size: Vector3,
	color: Color3,
	shape: Enum.PartType,
	transparency: number
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Size = size
	p.Position = pos
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = Enum.Material.ForceField
	p.Color = color
	p.Transparency = transparency
	p.CastShadow = false
	p.Parent = CombatService.EffectsFolder
	return p
end

local function clampAim(ctx: Ctx, maxDistance: number): Vector3
	local offset = ctx.aim - ctx.root.Position
	if offset.Magnitude > maxDistance then
		return ctx.root.Position + offset.Unit * maxDistance
	end
	return ctx.aim
end

-- ===== Ability implementations =====
-- Return false to cancel (cooldown is not consumed).

Kit.now = now
Kit.effect = effect
Kit.impulse = impulse
Kit.enemiesInRadius = enemiesInRadius
Kit.alliesInRadius = alliesInRadius
Kit.zonePart = zonePart
Kit.clampAim = clampAim

-- Lob a grenade along an arc (server-simulated). Detonates on impact, near an enemy, or after `fuse` s.
function Kit.throwGrenade(ctx: Ctx, color: Color3, onDetonate: (position: Vector3) -> (), fuse: number?)
	local head = ctx.char:FindFirstChild("Head") :: BasePart?
	local origin = (if head then head.Position else ctx.root.Position) + ctx.look * 2
	local toAim = ctx.aim - origin
	local dir = if toAim.Magnitude > 0.1 then toAim.Unit else ctx.look
	local velocity = dir * 85 + Vector3.new(0, 18, 0)
	local gravity = Vector3.new(0, -workspace.Gravity * 0.45, 0)

	local ball = zonePart("Grenade", origin, Vector3.new(1.2, 1.2, 1.2), color, Enum.PartType.Ball, 0)
	ball.Material = Enum.Material.Neon
	local params = CombatService.BuildRayParams()

	task.spawn(function()
		local pos = origin
		local elapsed = 0
		local limit = fuse or 2.5
		local STEP = 1 / 30
		while elapsed < limit do
			local dt = task.wait(STEP)
			elapsed += dt
			velocity += gravity * dt
			local stepVec = velocity * dt
			local hit = workspace:Raycast(pos, stepVec, params)
			if hit then
				pos = hit.Position + hit.Normal * 0.5
				break
			end
			pos += stepVec
			ball.Position = pos
			if #enemiesInRadius(pos, 3) > 0 then
				break
			end
		end
		ball:Destroy()
		onDetonate(pos)
	end)
end

return Kit
