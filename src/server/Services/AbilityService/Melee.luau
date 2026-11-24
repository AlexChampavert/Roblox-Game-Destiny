-- Melee (V) per class, plus finishers: V on a weakened (<= 15% health) non-boss enemy
-- right in front of you finishes it, and drops power orbs (super charge) for the fireteam.

local Players = game:GetService("Players")

local CombatService = require(script.Parent.Parent.CombatService)
local Kit = require(script.Parent.Kit)

type Ctx = Kit.Ctx

local Melee = {}

local FINISHER_RANGE = 8
local FINISHER_HEALTH = 0.15

-- Enemies in a cone in front of the player, nearest first
local function inFront(ctx: Ctx, range: number, minDot: number): { Model }
	local list = {}
	for _, enemy in Kit.enemiesInRadius(ctx.root.Position, range) do
		local to = (enemy.PrimaryPart :: BasePart).Position - ctx.root.Position
		local flat = Vector3.new(to.X, 0, to.Z)
		if flat.Magnitude < 2 or flat.Unit:Dot(ctx.look) >= minDot then
			table.insert(list, enemy)
		end
	end
	table.sort(list, function(a, b)
		return ((a.PrimaryPart :: BasePart).Position - ctx.root.Position).Magnitude
			< ((b.PrimaryPart :: BasePart).Position - ctx.root.Position).Magnitude
	end)
	return list
end

-- Returns the enemy a finisher would hit, if any (also used to show the prompt on the client)
function Melee.FinisherTarget(ctx: Ctx): Model?
	for _, enemy in inFront(ctx, FINISHER_RANGE, 0.5) do
		local hum = enemy:FindFirstChildOfClass("Humanoid")
		if hum and not enemy:GetAttribute("IsBoss") and hum.Health / hum.MaxHealth <= FINISHER_HEALTH then
			return enemy
		end
	end
	return nil
end

function Melee.Finisher(ctx: Ctx, enemy: Model, color: Color3)
	local hum = enemy:FindFirstChildOfClass("Humanoid") :: Humanoid
	local pos = (enemy.PrimaryPart :: BasePart).Position
	CombatService.ApplyDamageReduction(ctx.char, 1, 1.2) -- untouchable during the finisher
	CombatService.DamageEnemy(enemy, hum.Health + 1, ctx.player, nil, ctx.element)
	Kit.effect("Explosion", { position = pos, radius = 9, color = color })
	Kit.effect("Beam", { from = pos + Vector3.new(0, 30, 0), to = pos, color = color, width = 2, duration = 0.4 })
	-- Power orbs: super energy for everyone nearby
	for _, p in Players:GetPlayers() do
		local _, _, root = CombatService.GetAlive(p)
		if root and (root.Position - pos).Magnitude <= 30 then
			CombatService.AddSuper(p, if p == ctx.player then 15 else 10)
		end
	end
end

local function strike(ctx: Ctx, range: number, damage: number, color: Color3): Model?
	local target = inFront(ctx, range, 0.4)[1]
	if target then
		CombatService.DamageEnemy(target, damage, ctx.player, nil, ctx.element)
		Kit.effect("Explosion", { position = (target.PrimaryPart :: BasePart).Position, radius = 3, color = color })
	end
	return target
end

Melee.ShoulderCharge = function(ctx)
	Kit.impulse(ctx.player, ctx.look * 70, 0.25)
	task.delay(0.15, function()
		local target = strike(ctx, 9, 130, Color3.fromRGB(255, 140, 40))
		if target and target.PrimaryPart then
			target.PrimaryPart.AssemblyLinearVelocity = ctx.look * 70 + Vector3.new(0, 30, 0)
		end
	end)
	return true
end

Melee.KnifeThrow = function(ctx)
	local head = ctx.char:FindFirstChild("Head") :: BasePart?
	local origin = if head then head.Position else ctx.root.Position
	local dir = (ctx.aim - origin)
	if dir.Magnitude < 0.1 then
		return false
	end
	local result = workspace:Raycast(origin, dir.Unit * 45, CombatService.BuildRayParams())
	local hitPos = if result then result.Position else origin + dir.Unit * 45
	Kit.effect("Tracer", { from = origin, to = hitPos, color = Color3.fromRGB(90, 200, 255) })
	local enemy = result and CombatService.FindEnemyModel(result.Instance)
	if enemy and result then
		local headshot = result.Instance.Name == "Head"
		CombatService.DamageEnemy(enemy, if headshot then 220 else 110, ctx.player, nil, ctx.element)
	end
	return true
end

Melee.VoidPalm = function(ctx)
	local color = Color3.fromRGB(170, 90, 255)
	Kit.effect("Explosion", { position = ctx.root.Position + ctx.look * 5, radius = 7, color = color })
	for _, enemy in inFront(ctx, 9, 0.3) do
		CombatService.DamageEnemy(enemy, 95, ctx.player, nil, ctx.element)
		local part = enemy.PrimaryPart :: BasePart
		part.AssemblyLinearVelocity = ctx.look * 90 + Vector3.new(0, 25, 0)
	end
	return true
end

Melee.SiphonStrike = function(ctx)
	local target = strike(ctx, 8, 85, Color3.fromRGB(255, 190, 90))
	if target then
		CombatService.Heal(ctx.player, 25)
		Kit.effect("Heal", { position = ctx.root.Position, radius = 4 })
	end
	return true
end

Melee.ShockWrench = function(ctx)
	local target = strike(ctx, 8, 90, Color3.fromRGB(90, 200, 255))
	if target then
		local hum = target:FindFirstChildOfClass("Humanoid")
		if hum and not target:GetAttribute("IsBoss") then
			target:SetAttribute("StunnedUntil", Kit.now() + 1.5)
		end
	end
	return true
end

return Melee
