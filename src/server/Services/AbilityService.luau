-- Class abilities (Q, E) and supers (F). Server validates cooldowns/charge and applies effects.
-- Movement (dashes, thrusters) is applied on the owning client via an "Impulse" effect
-- because the client owns its character's physics; the server still decides if it happens.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Classes = require(Shared.Config.Classes)
local Net = require(Shared.Net)

local CombatService = require(script.Parent.CombatService)
local Security = require(script.Parent.Security)

local AbilityService = {}

type Ctx = {
	player: Player,
	char: Model,
	hum: Humanoid,
	root: BasePart,
	aim: Vector3, -- world point the player is aiming at
	look: Vector3, -- flat look direction
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
AbilityService.EnemiesInRadius = enemiesInRadius

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

local Abilities: { [string]: (Ctx) -> boolean } = {}

-- BULWARK
Abilities.ShieldBash = function(ctx)
	local origin = ctx.root.Position
	for _, enemy in enemiesInRadius(origin + ctx.look * 6, 10) do
		CombatService.DamageEnemy(enemy, 70, ctx.player)
		local eroot = enemy.PrimaryPart :: BasePart
		eroot.AssemblyLinearVelocity = ctx.look * 80 + Vector3.new(0, 35, 0)
	end
	effect("Explosion", { position = origin + ctx.look * 6, radius = 10, color = Color3.fromRGB(230, 150, 60) })
	return true
end

Abilities.Charge = function(ctx)
	impulse(ctx.player, ctx.look * 90, 0.3)
	-- Damage along the path while charging
	task.spawn(function()
		local hit: { [Model]: boolean } = {}
		for _ = 1, 6 do
			task.wait(0.05)
			for _, enemy in enemiesInRadius(ctx.root.Position, 7) do
				if not hit[enemy] then
					hit[enemy] = true
					CombatService.DamageEnemy(enemy, 55, ctx.player)
					local eroot = enemy.PrimaryPart :: BasePart
					eroot.AssemblyLinearVelocity = ctx.look * 60 + Vector3.new(0, 25, 0)
				end
			end
		end
	end)
	return true
end

Abilities.Bastion = function(ctx)
	local center = ctx.root.Position
	local dome =
		zonePart("Bastion", center, Vector3.new(30, 30, 30), Color3.fromRGB(255, 180, 80), Enum.PartType.Ball, 0.2)
	Debris:AddItem(dome, 10)
	task.spawn(function()
		local endTime = os.clock() + 10
		while os.clock() < endTime and dome.Parent do
			for _, p in alliesInRadius(center, 15) do
				CombatService.ApplyDamageReduction(p.Character :: Model, 0.6, 0.6)
			end
			task.wait(0.5)
		end
	end)
	return true
end

-- PHANTOM
Abilities.SmokeVeil = function(ctx)
	local char = ctx.char
	char:SetAttribute("CloakedUntil", now() + 4)
	local saved: { [BasePart]: number } = {}
	for _, d in char:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
			saved[d] = d.Transparency
			d.Transparency = math.max(d.Transparency, 0.85)
		end
	end
	effect("Explosion", { position = ctx.root.Position, radius = 8, color = Color3.fromRGB(60, 50, 90) })
	task.delay(4, function()
		for part, t in saved do
			if part.Parent then
				part.Transparency = t
			end
		end
	end)
	return true
end

Abilities.ShadowDash = function(ctx)
	impulse(ctx.player, ctx.look * 120, 0.22)
	return true
end

Abilities.Deadeye = function(ctx)
	ctx.player:SetAttribute("EmpoweredShots", 3)
	effect("Explosion", { position = ctx.root.Position, radius = 6, color = Color3.fromRGB(180, 120, 255) })
	return true
end

-- ARCANIST
Abilities.GravityWell = function(ctx)
	local center = clampAim(ctx, 90) + Vector3.new(0, 3, 0)
	local well =
		zonePart("GravityWell", center, Vector3.new(8, 8, 8), Color3.fromRGB(70, 200, 255), Enum.PartType.Ball, 0)
	well.Material = Enum.Material.Neon
	Debris:AddItem(well, 3.2)
	task.spawn(function()
		for _ = 1, 15 do
			for _, enemy in enemiesInRadius(center, 20) do
				local eroot = enemy.PrimaryPart :: BasePart
				local pull = center - eroot.Position
				if pull.Magnitude > 2 then
					eroot.AssemblyLinearVelocity = pull.Unit * 30
				end
				CombatService.DamageEnemy(enemy, 7, ctx.player)
			end
			task.wait(0.2)
		end
		effect("Explosion", { position = center, radius = 14, color = Color3.fromRGB(70, 200, 255) })
		for _, enemy in enemiesInRadius(center, 14) do
			CombatService.DamageEnemy(enemy, 60, ctx.player)
		end
	end)
	return true
end

Abilities.Blink = function(ctx)
	local origin = ctx.root.Position
	local params = CombatService.BuildRayParams()
	local result = workspace:Raycast(origin, ctx.look * 35, params)
	local distance = if result then math.max(result.Distance - 3, 0) else 35
	if distance < 4 then
		return false
	end
	effect("Explosion", { position = origin, radius = 5, color = Color3.fromRGB(70, 200, 255) })
	local target = origin + ctx.look * distance
	Security.AllowMovement(ctx.player, 1.5)
	ctx.char:PivotTo(CFrame.lookAt(target, target + ctx.look))
	effect("Explosion", { position = target, radius = 5, color = Color3.fromRGB(70, 200, 255) })
	return true
end

Abilities.NovaStorm = function(ctx)
	ctx.char:SetAttribute("DR", 0.8)
	ctx.char:SetAttribute("DRUntil", now() + 1.5)
	impulse(ctx.player, Vector3.new(0, 45, 0), 0.4)
	effect("Explosion", { position = ctx.root.Position, radius = 8, color = Color3.fromRGB(150, 230, 255) })
	task.delay(1.2, function()
		local _, _, root = CombatService.GetAlive(ctx.player)
		local center = if root then root.Position else ctx.root.Position
		effect("Explosion", { position = center, radius = 34, color = Color3.fromRGB(70, 200, 255) })
		for _, enemy in enemiesInRadius(center, 34) do
			CombatService.DamageEnemy(enemy, 420, ctx.player)
		end
	end)
	return true
end

-- LIFEBINDER
Abilities.HealingPulse = function(ctx)
	for _, p in alliesInRadius(ctx.root.Position, 25) do
		local _, hum = CombatService.GetAlive(p)
		if hum then
			CombatService.Heal(p, hum.MaxHealth * 0.4)
		end
	end
	effect("Heal", { position = ctx.root.Position, radius = 25 })
	return true
end

Abilities.Lifeline = function(ctx)
	local best: Player? = nil
	local bestDist = 70
	for _, p in Players:GetPlayers() do
		if p ~= ctx.player then
			local _, _, root = CombatService.GetAlive(p)
			if root then
				local d = (root.Position - ctx.root.Position).Magnitude
				if d < bestDist then
					best, bestDist = p, d
				end
			end
		end
	end
	if not best then
		Net.event("Notify"):FireClient(ctx.player, "No ally in range for Lifeline.", "error")
		return false
	end
	local _, _, allyRoot = CombatService.GetAlive(best)
	local dir = ((allyRoot :: BasePart).Position - ctx.root.Position)
	impulse(ctx.player, dir.Unit * math.min(140, dir.Magnitude / 0.3), 0.3)
	CombatService.ApplyDamageReduction(ctx.char, 0.5, 4)
	CombatService.ApplyDamageReduction(best.Character :: Model, 0.5, 4)
	effect("Heal", { position = (allyRoot :: BasePart).Position, radius = 6 })
	return true
end

Abilities.Sanctuary = function(ctx)
	local center = ctx.root.Position
	local zone = zonePart(
		"Sanctuary",
		center - Vector3.new(0, 2.5, 0),
		Vector3.new(1, 40, 40),
		Color3.fromRGB(90, 230, 130),
		Enum.PartType.Cylinder,
		0.3
	)
	zone.CFrame = CFrame.new(center - Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
	Debris:AddItem(zone, 8)
	effect("Heal", { position = center, radius = 20 })
	task.spawn(function()
		for _ = 1, 16 do
			for _, p in alliesInRadius(center, 20) do
				CombatService.Heal(p, 10)
				CombatService.ApplyDamageReduction(p.Character :: Model, 0.4, 0.6)
			end
			-- Sanctuary instantly revives downed allies inside it
			for _, p in Players:GetPlayers() do
				local c = p.Character
				local r = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
				if r and CombatService.IsDowned(p) and (r.Position - center).Magnitude <= 20 then
					CombatService.Revive(p, ctx.player)
				end
			end
			task.wait(0.5)
		end
	end)
	return true
end

-- ENGINEER
Abilities.SentryTurret = function(ctx)
	local pos = ctx.root.Position + ctx.look * 4
	local params = CombatService.BuildRayParams()
	local ground = workspace:Raycast(pos + Vector3.new(0, 5, 0), Vector3.new(0, -20, 0), params)
	if ground then
		pos = ground.Position + Vector3.new(0, 1.5, 0)
	end
	local turret = Instance.new("Model")
	turret.Name = "SentryTurret"
	local base = zonePart("Base", pos, Vector3.new(3, 3, 3), Color3.fromRGB(70, 70, 80), Enum.PartType.Block, 0)
	base.Material = Enum.Material.Metal
	base.Parent = turret
	local head = zonePart(
		"Head",
		pos + Vector3.new(0, 2.2, 0),
		Vector3.new(1.6, 1.6, 1.6),
		Color3.fromRGB(255, 220, 70),
		Enum.PartType.Ball,
		0
	)
	head.Material = Enum.Material.Neon
	head.Parent = turret
	turret.Parent = CombatService.EffectsFolder
	Debris:AddItem(turret, 20) -- 15s + Scavenger bonus

	task.spawn(function()
		local rayParams = CombatService.BuildRayParams()
		while turret.Parent do
			local target: Model? = nil
			local best = 90
			for _, enemy in enemiesInRadius(head.Position, 90) do
				local d = ((enemy.PrimaryPart :: BasePart).Position - head.Position).Magnitude
				if d < best then
					local los = workspace:Raycast(
						head.Position,
						(enemy.PrimaryPart :: BasePart).Position - head.Position,
						rayParams
					)
					if not los or CombatService.FindEnemyModel(los.Instance) == enemy then
						target, best = enemy, d
					end
				end
			end
			if target then
				local tpos = (target.PrimaryPart :: BasePart).Position
				CombatService.DamageEnemy(target, 8, ctx.player)
				effect("Tracer", { from = head.Position, to = tpos, color = Color3.fromRGB(255, 220, 70) })
			end
			task.wait(0.25)
		end
	end)
	return true
end

Abilities.Thrusters = function(ctx)
	impulse(ctx.player, ctx.look * 45 + Vector3.new(0, 75, 0), 0.35)
	effect(
		"Explosion",
		{ position = ctx.root.Position - Vector3.new(0, 2, 0), radius = 4, color = Color3.fromRGB(255, 150, 50) }
	)
	return true
end

Abilities.OrbitalStrike = function(ctx)
	local target = clampAim(ctx, 250)
	local warning = zonePart(
		"StrikeWarning",
		target,
		Vector3.new(1, 36, 36),
		Color3.fromRGB(255, 60, 40),
		Enum.PartType.Cylinder,
		0.4
	)
	warning.CFrame = CFrame.new(target) * CFrame.Angles(0, 0, math.rad(90))
	Debris:AddItem(warning, 1.6)
	task.delay(1.5, function()
		effect(
			"Beam",
			{
				from = target + Vector3.new(0, 400, 0),
				to = target,
				color = Color3.fromRGB(255, 240, 200),
				width = 14,
				duration = 1.2,
			}
		)
		effect("Explosion", { position = target, radius = 22, color = Color3.fromRGB(255, 200, 120) })
		for _, enemy in enemiesInRadius(target, 22) do
			CombatService.DamageEnemy(enemy, 650, ctx.player)
		end
	end)
	return true
end

-- ===== Dispatch =====

local MOVEMENT_ABILITIES = { Charge = true, ShadowDash = true, Blink = true, Lifeline = false, Thrusters = true }

local function onUseAbility(player: Player, slot: any, aim: any)
	if (slot ~= "Q" and slot ~= "E" and slot ~= "F") or typeof(aim) ~= "Vector3" then
		return
	end
	local classId = player:GetAttribute("ClassId")
	local class = classId and Classes.Defs[classId]
	local char, hum, root = CombatService.GetAlive(player)
	if not class or not char or not hum or not root then
		return
	end
	local def = class.abilities[slot]
	local inMission = CombatService.IsCombatEnabled()
	-- In the hub only movement abilities work (fun on the Skydeck jumping puzzle)
	if not inMission and not MOVEMENT_ABILITIES[def.id] then
		return
	end

	local t = now()
	if slot == "F" then
		if (player:GetAttribute("SuperCharge") or 0) < 100 then
			return
		end
	elseif t < (player:GetAttribute("Ready" .. slot) or 0) then
		return
	end

	local flat = Vector3.new(aim.X - root.Position.X, 0, aim.Z - root.Position.Z)
	local look = if flat.Magnitude > 0.1 then flat.Unit else root.CFrame.LookVector
	local fn = Abilities[def.id]
	if not fn then
		warn("[AbilityService] missing ability", def.id)
		return
	end
	Security.AllowMovement(player, 2) -- dashes / boosts move faster than walking
	local ok, used = pcall(fn, { player = player, char = char, hum = hum, root = root, aim = aim, look = look })
	if not ok then
		warn("[AbilityService]", def.id, "error:", used)
		return
	end
	if not used then
		return
	end

	if slot == "F" then
		player:SetAttribute("SuperCharge", 0)
		Net.event("Notify"):FireClient(player, def.name .. "!", "super")
	else
		local cooldown = def.cooldown
		if class.passive.id == "Overflow" then
			cooldown *= 0.85
		end
		-- Order Rank upgrades
		local rank = player:GetAttribute("OrderRank") or 0
		if (slot == "Q" and rank >= 5) or (slot == "E" and rank >= 10) then
			cooldown *= 0.85
		end
		if workspace:GetAttribute("Modifier") == "Overcharged" then
			cooldown *= 0.5
		end
		player:SetAttribute("Ready" .. slot, t + cooldown)
	end
end

function AbilityService.Start()
	Net.event("UseAbility").OnServerEvent:Connect(Security.Guard("UseAbility", 6, onUseAbility))
end

return AbilityService
