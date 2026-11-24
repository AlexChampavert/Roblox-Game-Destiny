-- Grenades (G). Each returns true if used. Thrown along an arc by Kit.throwGrenade.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")

local CombatService = require(script.Parent.Parent.CombatService)
local Kit = require(script.Parent.Kit)

type Ctx = Kit.Ctx

local Grenades: { [string]: (Ctx) -> boolean } = {}

local function blast(ctx: Ctx, pos: Vector3, radius: number, damage: number, color: Color3)
	Kit.effect("Explosion", { position = pos, radius = radius, color = color })
	for _, enemy in Kit.enemiesInRadius(pos, radius) do
		CombatService.DamageEnemy(enemy, damage, ctx.player, nil, ctx.element)
	end
end

Grenades.FragGrenade = function(ctx)
	Kit.throwGrenade(ctx, Color3.fromRGB(255, 140, 40), function(pos)
		blast(ctx, pos, 14, 95, Color3.fromRGB(255, 140, 40))
	end)
	return true
end

Grenades.ArcboltGrenade = function(ctx)
	local color = Color3.fromRGB(90, 200, 255)
	Kit.throwGrenade(ctx, color, function(pos)
		blast(ctx, pos, 6, 40, color)
		-- Chain lightning to up to 4 more enemies, each jump from the last one hit
		local from = pos
		local hit: { [Model]: boolean } = {}
		for _ = 1, 4 do
			local best, bestDist = nil, 22
			for _, enemy in Kit.enemiesInRadius(from, 22) do
				local d = ((enemy.PrimaryPart :: BasePart).Position - from).Magnitude
				if not hit[enemy] and d < bestDist then
					best, bestDist = enemy, d
				end
			end
			if not best then
				break
			end
			hit[best] = true
			local to = (best.PrimaryPart :: BasePart).Position
			Kit.effect("Beam", { from = from, to = to, color = color, width = 0.6, duration = 0.25 })
			CombatService.DamageEnemy(best, 60, ctx.player, nil, ctx.element)
			from = to
		end
	end)
	return true
end

Grenades.VortexGrenade = function(ctx)
	local color = Color3.fromRGB(170, 90, 255)
	Kit.throwGrenade(ctx, color, function(pos)
		local vortex = Kit.zonePart("Vortex", pos, Vector3.new(18, 18, 18), color, Enum.PartType.Ball, 0.3)
		Debris:AddItem(vortex, 4)
		task.spawn(function()
			for _ = 1, 16 do
				for _, enemy in Kit.enemiesInRadius(pos, 9) do
					CombatService.DamageEnemy(enemy, 9, ctx.player, nil, ctx.element)
				end
				task.wait(0.25)
			end
		end)
	end)
	return true
end

Grenades.HealingGrenade = function(ctx)
	local color = Color3.fromRGB(255, 190, 90)
	Kit.throwGrenade(ctx, color, function(pos)
		blast(ctx, pos, 12, 45, color)
		Kit.effect("Heal", { position = pos, radius = 14 })
		for _, p in Players:GetPlayers() do
			local _, _, root = CombatService.GetAlive(p)
			if root and (root.Position - pos).Magnitude <= 14 then
				CombatService.Heal(p, 50)
			end
		end
	end)
	return true
end

Grenades.ClusterGrenade = function(ctx)
	local color = Color3.fromRGB(255, 220, 70)
	Kit.throwGrenade(ctx, color, function(pos)
		blast(ctx, pos, 10, 60, color)
		for i = 1, 4 do
			local a = i / 4 * math.pi * 2
			local sub = pos + Vector3.new(math.cos(a) * 7, 0, math.sin(a) * 7)
			task.delay(0.15 * i, function()
				blast(ctx, sub, 6, 30, color)
			end)
		end
	end)
	return true
end

return Grenades
