-- Enemy spawning, simple AI, boss phases and kill rewards.
-- Uses ServerStorage.EnemyModels.<id> if present (must contain Humanoid, HumanoidRootPart, Head);
-- otherwise builds a blocky placeholder so everything works before art exists.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enemies = require(Shared.Config.Enemies)
local Progression = require(Shared.Config.Progression)
local Net = require(Shared.Net)

local DataService = require(script.Parent.DataService)
local CombatService = require(script.Parent.CombatService)
local ProgressionService = require(script.Parent.ProgressionService)

local EnemyService = {}

local died = Instance.new("BindableEvent")
EnemyService.Died = died.Event -- (model, def)

local enemyFolder = Instance.new("Folder")
enemyFolder.Name = "Enemies"
enemyFolder.Parent = workspace

type Brain = {
	model: Model,
	def: any,
	hum: Humanoid,
	root: BasePart,
	head: BasePart,
	damageMult: number,
	speedMult: number,
	lastAttack: number,
	lastPos: Vector3,
	stuckTime: number,
	nextPhase: number,
	lastSpecial: number,
	path: { Vector3 }?,
	pathIndex: number,
	nextPathAt: number,
	computing: boolean?,
}

local brains: { [Model]: Brain } = {}
local rng = Random.new()

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = a
end

local function buildPlaceholder(def): Model
	local s = def.size
	local model = Instance.new("Model")

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1) * s
	root.Transparency = 1
	root.CanCollide = true
	root.Parent = model

	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Size = Vector3.new(2.2, 2.4, 1.2) * s
	torso.Color = def.color
	torso.Material = Enum.Material.SmoothPlastic
	torso.CanCollide = false
	torso.Massless = true
	torso.CFrame = root.CFrame
	torso.Parent = model
	weld(root, torso)

	local legs = Instance.new("Part")
	legs.Name = "Legs"
	legs.Size = Vector3.new(1.8, 2, 1) * s
	legs.Color = def.color:Lerp(Color3.new(0, 0, 0), 0.4)
	legs.CanCollide = false
	legs.Massless = true
	legs.CFrame = root.CFrame * CFrame.new(0, -2.2 * s, 0)
	legs.Parent = model
	weld(root, legs)

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1.3, 1.3, 1.3) * s
	head.Color = def.color:Lerp(Color3.new(1, 1, 1), 0.15)
	head.CanCollide = false
	head.Massless = true
	head.CFrame = root.CFrame * CFrame.new(0, 1.9 * s, 0)
	head.Parent = model
	weld(root, head)

	local eye = Instance.new("Part")
	eye.Name = "Eye"
	eye.Size = Vector3.new(0.9, 0.3, 0.1) * s
	eye.Material = Enum.Material.Neon
	eye.Color = if def.faction == "Hollow" then Color3.fromRGB(255, 60, 200) else Color3.fromRGB(255, 50, 30)
	eye.CanCollide = false
	eye.Massless = true
	eye.CFrame = head.CFrame * CFrame.new(0, 0.1 * s, -0.66 * s)
	eye.Parent = model
	weld(head, eye)

	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R15
	hum.HipHeight = 2.2 * s -- root bottom (-1s) to legs bottom (-3.2s)
	hum.Parent = model

	model.PrimaryPart = root
	return model
end

local function addHealthBar(def, head: BasePart, hum: Humanoid)
	local gui = Instance.new("BillboardGui")
	gui.Name = "HealthBar"
	gui.Size = if def.isBoss then UDim2.fromOffset(260, 34) else UDim2.fromOffset(90, 18)
	gui.StudsOffsetWorldSpace = Vector3.new(0, head.Size.Y + 1, 0)
	gui.AlwaysOnTop = def.isBoss == true
	gui.MaxDistance = if def.isBoss then 400 else 120
	gui.Parent = head

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0.5, 0)
	label.BackgroundTransparency = 1
	label.Text = def.name
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = if def.isBoss then Color3.fromRGB(255, 210, 90) else Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.Parent = gui

	local back = Instance.new("Frame")
	back.Position = UDim2.new(0, 0, 0.6, 0)
	back.Size = UDim2.new(1, 0, 0.3, 0)
	back.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	back.BorderSizePixel = 0
	back.Parent = gui

	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(1, 0, 1, 0)
	fill.BackgroundColor3 = if def.isBoss then Color3.fromRGB(255, 170, 40) else Color3.fromRGB(230, 60, 60)
	fill.BorderSizePixel = 0
	fill.Parent = back

	hum.HealthChanged:Connect(function(h)
		fill.Size = UDim2.new(math.clamp(h / hum.MaxHealth, 0, 1), 0, 1, 0)
	end)
end

function EnemyService.Spawn(
	enemyId: string,
	position: Vector3,
	opts: { healthMult: number?, damageMult: number?, speedMult: number? }?
): Model?
	local def = Enemies[enemyId]
	if not def then
		warn("[EnemyService] unknown enemy", enemyId)
		return nil
	end
	local options = opts or {}
	local template = ServerStorage:FindFirstChild("EnemyModels") and ServerStorage.EnemyModels:FindFirstChild(enemyId)
	local model: Model = if template then template:Clone() else buildPlaceholder(def)
	model.Name = def.name

	local hum = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	local head = model:FindFirstChild("Head") :: BasePart
	local speedMult = options.speedMult or 1
	if workspace:GetAttribute("Modifier") == "Frenzy" then
		speedMult *= 1.25
	end

	hum.MaxHealth = def.health * (options.healthMult or 1)
	hum.Health = hum.MaxHealth
	hum.WalkSpeed = def.speed * speedMult
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.BreakJointsOnDeath = false

	model:SetAttribute("EnemyId", enemyId)
	model:SetAttribute("IsBoss", def.isBoss == true)
	CollectionService:AddTag(model, "Enemy")
	model:PivotTo(CFrame.new(position + Vector3.new(0, 3 * def.size + 2, 0)))
	model.Parent = enemyFolder
	root:SetNetworkOwner(nil) -- server simulates enemies
	addHealthBar(def, head, hum)

	brains[model] = {
		model = model,
		def = def,
		hum = hum,
		root = root,
		head = head,
		damageMult = options.damageMult or 1,
		speedMult = speedMult,
		lastAttack = 0,
		lastPos = root.Position,
		stuckTime = 0,
		lastSpecial = os.clock(),
		path = nil,
		pathIndex = 1,
		nextPathAt = 0,
		nextPhase = 1,
	}

	hum.Died:Connect(function()
		EnemyService._onDied(model)
	end)
	return model
end

function EnemyService.CountAlive(): number
	local n = 0
	for _, brain in brains do
		if brain.hum.Health > 0 then
			n += 1
		end
	end
	return n
end

function EnemyService.ClearAll()
	for model in brains do
		model:Destroy()
	end
	table.clear(brains)
	enemyFolder:ClearAllChildren()
	EnemyService.ClearProjectiles()
end

function EnemyService._onDied(model: Model)
	local brain = brains[model]
	if not brain then
		return
	end
	brains[model] = nil
	CollectionService:RemoveTag(model, "Enemy")
	local def = brain.def

	-- Co-op rewards: every player gets XP, the killer gets super charge + kill stat
	local killerId = model:GetAttribute("LastHitBy")
	local featured = workspace:GetAttribute("Featured") == true
	for _, p in Players:GetPlayers() do
		ProgressionService.AddXP(p, def.xp * (if featured then 2 else 1))
		if p.UserId == killerId then
			CombatService.AddSuper(p, Progression.SuperChargePerKill * (if def.isBoss then 0 else 1))
			CombatService.OnKill(p)
			local profile = DataService.Get(p)
			if profile then
				profile.stats.kills += 1
			end
			if p:GetAttribute("ClassId") == "Engineer" then
				CombatService.RefundAmmo(p, 0.1) -- Scavenger
			end
			if not def.isBoss and rng:NextNumber() < Progression.DropChancePerKill then
				ProgressionService.GrantGear(p, false)
			end
		end
	end

	died:Fire(model, def)

	-- Fade out
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.Material = Enum.Material.Neon
		end
	end
	task.delay(1.5, function()
		model:Destroy()
	end)
end

-- ===== AI =====

local function nearestTarget(pos: Vector3, range: number): (Player?, BasePart?)
	local best, bestRoot, bestDist = nil, nil, range
	local t = workspace:GetServerTimeNow()
	for _, p in Players:GetPlayers() do
		local char, _, root = CombatService.GetAlive(p)
		if char and root and (char:GetAttribute("CloakedUntil") or 0) < t then
			local d = (root.Position - pos).Magnitude
			if d < bestDist then
				best, bestRoot, bestDist = p, root, d
			end
		end
	end
	return best, bestRoot
end

local function checkPhases(brain: Brain)
	local phases = brain.def.phases
	if not phases then
		return
	end
	local phase = phases[brain.nextPhase]
	if not phase then
		return
	end
	if brain.hum.Health / brain.hum.MaxHealth > phase.atHealthPct then
		return
	end
	brain.nextPhase += 1
	if phase.message then
		Net.event("Notify"):FireAllClients(phase.message, "boss")
	end
	if phase.speedMult then
		brain.speedMult *= phase.speedMult
		brain.hum.WalkSpeed = brain.def.speed * brain.speedMult
	end
	if phase.damageMult then
		brain.damageMult *= phase.damageMult
	end
	if phase.spawnAdds then
		local playerCount = math.max(#Players:GetPlayers(), 1)
		for enemyId, count in phase.spawnAdds do
			for _ = 1, count + (playerCount - 1) do
				local angle = rng:NextNumber(0, math.pi * 2)
				local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * rng:NextNumber(18, 35)
				EnemyService.Spawn(enemyId, brain.root.Position + offset, {
					healthMult = 1 + (playerCount - 1) * Progression.HealthScalePerExtraPlayer,
				})
			end
		end
	end
end

-- ===== Projectiles (dodgeable) =====

type Projectile = { part: BasePart, velocity: Vector3, damage: number, radius: number, expires: number }
local projectiles: { Projectile } = {}

local function fireProjectile(brain: Brain, targetRoot: BasePart, damage: number)
	local spec = brain.def.projectile
	local origin = brain.head.Position
	-- Lead the target a little so standing still is a bad idea, strafing is a good one
	local travel = (targetRoot.Position - origin).Magnitude / spec.speed
	local aim = targetRoot.Position + targetRoot.AssemblyLinearVelocity * travel * 0.5
	local part = Instance.new("Part")
	part.Name = "Projectile"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(spec.size, spec.size, spec.size)
	part.Material = Enum.Material.Neon
	part.Color = brain.def.color
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Position = origin
	local light = Instance.new("PointLight")
	light.Color = brain.def.color
	light.Range = 10
	light.Parent = part
	part.Parent = CombatService.EffectsFolder
	table.insert(projectiles, {
		part = part,
		velocity = (aim - origin).Unit * spec.speed,
		damage = damage,
		radius = spec.size / 2 + 1.5,
		expires = os.clock() + 6,
	})
end

local function stepProjectiles(dt: number)
	if #projectiles == 0 then
		return
	end
	local params = CombatService.BuildRayParams()
	local excluded = params.FilterDescendantsInstances
	table.insert(excluded, enemyFolder)
	params.FilterDescendantsInstances = excluded
	for i = #projectiles, 1, -1 do
		local proj = projectiles[i]
		local from = proj.part.Position
		local step = proj.velocity * dt
		local done = os.clock() > proj.expires
		-- Hit a player?
		if not done then
			for _, p in Players:GetPlayers() do
				local _, _, root = CombatService.GetAlive(p)
				if root then
					-- closest point on the segment to the player
					local t = math.clamp((root.Position - from):Dot(step) / math.max(step:Dot(step), 1e-6), 0, 1)
					if ((from + step * t) - root.Position).Magnitude <= proj.radius then
						CombatService.DamagePlayer(p, proj.damage)
						done = true
						break
					end
				end
			end
		end
		-- Hit a wall?
		if not done and workspace:Raycast(from, step, params) then
			done = true
		end
		if done then
			Net.event("Effect"):FireAllClients(
				"Explosion",
				{ position = proj.part.Position, radius = proj.radius, color = proj.part.Color }
			)
			proj.part:Destroy()
			table.remove(projectiles, i)
		else
			proj.part.Position = from + step
		end
	end
end

-- ===== Telegraphed special attack (bosses) =====

local function special(brain: Brain, targetRoot: BasePart)
	local spec = brain.def.special
	local center = targetRoot.Position - Vector3.new(0, 2.8, 0)
	local warning = Instance.new("Part")
	warning.Name = "Telegraph"
	warning.Shape = Enum.PartType.Cylinder
	warning.Size = Vector3.new(0.3, spec.radius * 2, spec.radius * 2)
	warning.CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90))
	warning.Material = Enum.Material.Neon
	warning.Color = Color3.fromRGB(255, 40, 40)
	warning.Transparency = 0.55
	warning.Anchored = true
	warning.CanCollide = false
	warning.CanQuery = false
	warning.Parent = CombatService.EffectsFolder
	task.delay(spec.windup, function()
		warning:Destroy()
		if brain.hum.Health <= 0 then
			return
		end
		Net.event("Effect")
			:FireAllClients("Explosion", { position = center, radius = spec.radius, color = brain.def.color })
		for _, p in Players:GetPlayers() do
			local _, _, root = CombatService.GetAlive(p)
			if root and (root.Position - center).Magnitude <= spec.radius then
				CombatService.DamagePlayer(p, spec.damage * brain.damageMult)
			end
		end
	end)
end

local function attack(brain: Brain, target: Player, targetRoot: BasePart)
	local def = brain.def
	local damage = def.damage * brain.damageMult
	if def.attackType == "Melee" then
		CombatService.DamagePlayer(target, damage)
		Net.event("Effect")
			:FireAllClients("Explosion", { position = targetRoot.Position, radius = 3 * def.size, color = def.color })
		return
	end
	if def.projectile then
		fireProjectile(brain, targetRoot, damage)
		return
	end
	-- Hitscan (soldiers): blocked by cover
	local params = CombatService.BuildRayParams()
	local excluded = params.FilterDescendantsInstances
	table.insert(excluded, enemyFolder)
	params.FilterDescendantsInstances = excluded
	local origin = brain.head.Position
	local result = workspace:Raycast(origin, targetRoot.Position - origin, params)
	if result then
		Net.event("Effect")
			:FireAllClients("Tracer", { from = origin, to = result.Position, color = def.color, enemy = true })
		return
	end
	CombatService.DamagePlayer(target, damage)
	Net.event("Effect")
		:FireAllClients("Tracer", { from = origin, to = targetRoot.Position, color = def.color, enemy = true })
end

-- ===== Movement (direct when visible, pathfinding when blocked) =====

local function hasLineOfSight(from: Vector3, to: Vector3): boolean
	local params = CombatService.BuildRayParams()
	local excluded = params.FilterDescendantsInstances
	table.insert(excluded, enemyFolder)
	params.FilterDescendantsInstances = excluded
	return workspace:Raycast(from, to - from, params) == nil
end

local function moveTowards(brain: Brain, goal: Vector3)
	local pos = brain.root.Position
	if hasLineOfSight(pos, goal) then
		brain.path = nil
		brain.hum:MoveTo(goal)
		return
	end
	local t = os.clock()
	if (not brain.path or t >= brain.nextPathAt) and not brain.computing then
		brain.nextPathAt = t + 1.2 -- recompute at most ~1x per second per enemy
		brain.computing = true
		task.spawn(function() -- ComputeAsync yields: never block the AI loop
			local path = PathfindingService:CreatePath({
				AgentRadius = 2 * brain.def.size,
				AgentHeight = 5 * brain.def.size,
				AgentCanJump = true,
			})
			local ok = pcall(function()
				path:ComputeAsync(pos, goal)
			end)
			if ok and path.Status == Enum.PathStatus.Success then
				local points = {}
				for _, wp in path:GetWaypoints() do
					table.insert(points, wp.Position)
				end
				brain.path = points
				brain.pathIndex = math.min(2, #points)
			else
				brain.path = nil
			end
			brain.computing = false
		end)
	end
	local points = brain.path
	if points and points[brain.pathIndex] then
		local wp = points[brain.pathIndex]
		if (Vector3.new(wp.X, pos.Y, wp.Z) - pos).Magnitude < 4 then
			brain.pathIndex += 1
			wp = points[brain.pathIndex] or goal
		end
		brain.hum:MoveTo(wp)
	else
		brain.hum:MoveTo(goal)
	end
end

local function think(brain: Brain, dt: number)
	if brain.hum.Health <= 0 then
		return
	end
	if brain.def.isBoss then
		checkPhases(brain)
	end
	local pos = brain.root.Position
	if (tonumber(brain.model:GetAttribute("StunnedUntil")) or 0) > workspace:GetServerTimeNow() then
		brain.hum:MoveTo(pos) -- stunned: no movement, no attacks
		return
	end
	local target, targetRoot = nearestTarget(pos, brain.def.aggroRange)
	if not target or not targetRoot then
		brain.hum:MoveTo(pos)
		return
	end

	local dist = (targetRoot.Position - pos).Magnitude
	local reach = brain.def.attackRange + brain.def.size * 2
	local t = os.clock()
	local visible = brain.def.attackType == "Melee" or hasLineOfSight(brain.head.Position, targetRoot.Position)

	if brain.def.attackType == "Ranged" and dist <= reach * 0.8 and visible then
		-- In range with a clear shot: hold and strafe
		local side = brain.root.CFrame.RightVector * (if rng:NextNumber() < 0.5 then -6 else 6)
		brain.hum:MoveTo(pos + side)
	else
		moveTowards(brain, targetRoot.Position)
	end

	if dist <= reach and visible and t - brain.lastAttack >= brain.def.attackCooldown then
		brain.lastAttack = t
		attack(brain, target, targetRoot)
	end

	local spec = brain.def.special
	if spec and t - brain.lastSpecial >= spec.every and dist <= brain.def.aggroRange then
		brain.lastSpecial = t
		special(brain, targetRoot)
	end

	-- Unstick: jump if not moving while chasing
	if (pos - brain.lastPos).Magnitude < 0.5 and dist > reach then
		brain.stuckTime += dt
		if brain.stuckTime > 1.5 then
			brain.hum.Jump = true
			brain.stuckTime = 0
			brain.path = nil
		end
	else
		brain.stuckTime = 0
	end
	brain.lastPos = pos
end

function EnemyService.Start()
	RunService.Heartbeat:Connect(function(dt)
		local ok, err = pcall(stepProjectiles, dt)
		if not ok then
			warn("[EnemyService] projectile error:", err)
		end
	end)

	-- AI budget: think for at most MAX_PER_TICK enemies per tick, round-robin,
	-- so 40+ enemies don't spike the server.
	task.spawn(function()
		local TICK = 0.1
		local MAX_PER_TICK = 12
		local queue: { Brain } = {}
		while true do
			task.wait(TICK)
			if #queue == 0 then
				for _, brain in brains do
					table.insert(queue, brain)
				end
			end
			for _ = 1, math.min(MAX_PER_TICK, #queue) do
				local brain = table.remove(queue) :: Brain
				if brains[brain.model] then
					local ok, err = pcall(think, brain, 0.2)
					if not ok then
						warn("[EnemyService] AI error:", err)
					end
				end
			end
		end
	end)
end

function EnemyService.ClearProjectiles()
	for _, proj in projectiles do
		proj.part:Destroy()
	end
	table.clear(projectiles)
end

return EnemyService
