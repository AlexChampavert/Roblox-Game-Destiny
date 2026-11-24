-- Server-authoritative shooting, damage, healing, buffs, regen, weapon perks,
-- gun models, and the downed/revive system.
-- Clients only send "I fired at this point"; the server checks fire rate, ammo and line of sight.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Weapons = require(Shared.Config.Weapons)
local Elements = require(Shared.Config.Elements)
local Classes = require(Shared.Config.Classes)
local Progression = require(Shared.Config.Progression)
local Net = require(Shared.Net)

local DataService = require(script.Parent.DataService)
local ProgressionService = require(script.Parent.ProgressionService)
local Security = require(script.Parent.Security)
local MovementService = require(script.Parent.MovementService)
local Ordnance = require(script.Parent.Ordnance)

local CombatService = {}

local REGEN_DELAY = 4 -- seconds without damage before regen starts
local REGEN_PER_SECOND = 0.15 -- fraction of max health

type WeaponState = {
	slot: string,
	ammo: { [string]: number }, -- rounds in the magazine, per slot
	reserve: { [string]: number }, -- reserve rounds per ammo type ("special", "heavy"); primary is infinite
	lastFire: number,
	reloadingUntil: number,
	reloadToken: number,
	-- perk state
	rampageStacks: number,
	rampageUntil: number,
	killClipPending: number, -- time of last kill (reload within 5s triggers Kill Clip)
	killClipUntil: number,
	starfallHits: number,
}

local states: { [Player]: WeaponState } = {}
local lastDamaged: { [Player]: number } = {}
local rng = Random.new()

local effectsFolder = Instance.new("Folder")
effectsFolder.Name = "Effects"
effectsFolder.Parent = workspace
CombatService.EffectsFolder = effectsFolder

local downedEvent = Instance.new("BindableEvent")
CombatService.Downed = downedEvent.Event -- (player)
local revivedEvent = Instance.new("BindableEvent")
CombatService.Revived = revivedEvent.Event -- (player, reviver?)

local function now(): number
	return workspace:GetServerTimeNow()
end

function CombatService.IsCombatEnabled(): boolean
	return workspace:GetAttribute("Mode") == "Mission"
end

-- Character, humanoid, root of a player who can act (alive and NOT downed)
function CombatService.GetAlive(player: Player): (Model?, Humanoid?, BasePart?)
	local char = player.Character
	if not char or char:GetAttribute("Downed") then
		return nil, nil, nil
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hum or not root or hum.Health <= 0 then
		return nil, nil, nil
	end
	return char, hum, root
end

function CombatService.IsDowned(player: Player): boolean
	local char = player.Character
	return char ~= nil and char:GetAttribute("Downed") == true
end

-- ===== Weapons / loadout =====

function CombatService.GetWeaponItem(player: Player, slot: string)
	local profile = DataService.Get(player)
	return profile and profile.gear[slot]
end

function CombatService.GetWeaponId(player: Player, slot: string): string
	local profile = DataService.Get(player)
	if profile then
		local gear = profile.gear[slot]
		if gear and gear.weaponId and Weapons[gear.weaponId] then
			return gear.weaponId
		end
		local class = profile.classId and Classes.Defs[profile.classId]
		if class then
			return class.startingWeapons[slot]
		end
	end
	return if slot == "primary" then "AutoRifle" elseif slot == "heavy" then "RocketLauncher" else "HandCannon"
end

local function hasPerk(player: Player, slot: string, perk: string): boolean
	local item = CombatService.GetWeaponItem(player, slot)
	return item ~= nil and item.perks ~= nil and table.find(item.perks, perk) ~= nil
end
CombatService.HasPerk = hasPerk

local function magSize(player: Player, slot: string): number
	local base = Weapons[CombatService.GetWeaponId(player, slot)].magSize
	return if hasPerk(player, slot, "DeepMag") then math.floor(base * 1.3) else base
end

local function reloadTime(player: Player, slot: string): number
	local base = Weapons[CombatService.GetWeaponId(player, slot)].reloadTime
	return if hasPerk(player, slot, "Outlaw") then base * 0.75 else base
end

-- Simple gun model built from parts, welded to the right hand (replace with real meshes later:
-- put a Model in ServerStorage.WeaponModels.<weaponId> with a "Handle" part).
local function attachGun(player: Player)
	local st = states[player]
	local char = player.Character
	local hand = char and (char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")) :: BasePart?
	if not st or not char or not hand then
		return
	end
	local old = char:FindFirstChild("Gun")
	if old then
		old:Destroy()
	end
	local weaponId = CombatService.GetWeaponId(player, st.slot)
	local w = Weapons[weaponId]
	local item = CombatService.GetWeaponItem(player, st.slot)
	local rarityColor = if item and item.rarity == "Exotic"
		then Color3.fromRGB(255, 205, 60)
		elseif item and item.rarity == "Legendary" then Color3.fromRGB(190, 90, 255)
		elseif item and item.rarity == "Rare" then Color3.fromRGB(80, 140, 255)
		else Color3.fromRGB(200, 200, 200)

	local gun = Instance.new("Model")
	gun.Name = "Gun"
	local function piece(name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = color
		p.Material = material
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		-- gun-local -Z (barrel) = out of the fingers (hand -Y): lowered at rest, forward when aiming
		p.CFrame = hand.CFrame * CFrame.new(0, -hand.Size.Y / 2, 0) * CFrame.Angles(math.rad(-90), 0, 0) * offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = hand
		weld.Part1 = p
		weld.Parent = p
		p.Parent = gun
		return p
	end
	-- Barrel along gun-local -Z
	local len = w.length
	local body = piece(
		"Handle",
		Vector3.new(0.35, 0.55, len),
		CFrame.new(0, 0, -len / 2 + 0.4),
		Color3.fromRGB(45, 48, 58),
		Enum.Material.Metal
	)
	piece(
		"Grip",
		Vector3.new(0.3, 0.7, 0.35),
		CFrame.new(0, -0.3, 0.1),
		Color3.fromRGB(30, 30, 35),
		Enum.Material.Metal
	)
	piece(
		"Stripe",
		Vector3.new(0.37, 0.12, len * 0.6),
		CFrame.new(0, 0.2, -len / 2 + 0.4),
		rarityColor,
		Enum.Material.Neon
	)
	local muzzle = Instance.new("Attachment")
	muzzle.Name = "Muzzle"
	muzzle.Position = Vector3.new(0, 0.1, -len / 2)
	muzzle.Parent = body
	gun.PrimaryPart = body
	gun.Parent = char
end

local function syncWeapon(player: Player)
	local st = states[player]
	if not st then
		return
	end
	local weaponId = CombatService.GetWeaponId(player, st.slot)
	local item = CombatService.GetWeaponItem(player, st.slot)
	player:SetAttribute("WeaponSlot", st.slot)
	player:SetAttribute("WeaponId", weaponId)
	player:SetAttribute("WeaponName", Weapons[weaponId].name)
	player:SetAttribute("WeaponRarity", if item then item.rarity else "Common")
	player:SetAttribute("WeaponElement", if item then item.element else nil)
	player:SetAttribute("Ammo", st.ammo[st.slot])
	local ammoType = Weapons[weaponId].ammoType
	player:SetAttribute("AmmoType", ammoType)
	player:SetAttribute("Reserve", if ammoType == "primary" then -1 else (st.reserve[ammoType] or 0))
	player:SetAttribute("MagSize", magSize(player, st.slot))
	player:SetAttribute("Reloading", now() < st.reloadingUntil)
end

-- refillReserves: true at mission start (special/heavy reserves back to their starting amount)
function CombatService.RefreshLoadout(player: Player, refillReserves: boolean?)
	local st = states[player]
	if not st then
		st = {
			slot = "primary",
			ammo = {},
			reserve = {},
			lastFire = 0,
			reloadingUntil = 0,
			reloadToken = 0,
			rampageStacks = 0,
			rampageUntil = 0,
			killClipPending = 0,
			killClipUntil = 0,
			starfallHits = 0,
		}
		states[player] = st
	end
	for _, slot in Progression.WeaponSlots do
		st.ammo[slot] = magSize(player, slot)
		local ammoType = Weapons[CombatService.GetWeaponId(player, slot)].ammoType
		if ammoType ~= "primary" and (refillReserves or st.reserve[ammoType] == nil) then
			st.reserve[ammoType] = magSize(player, slot) * (Progression.StartReserveMags[ammoType] or 1)
		end
	end
	st.reloadingUntil = 0
	syncWeapon(player)
	attachGun(player)
end

function CombatService.RefundAmmo(player: Player, fraction: number)
	local st = states[player]
	if not st then
		return
	end
	local size = magSize(player, st.slot)
	st.ammo[st.slot] = math.min(size, st.ammo[st.slot] + math.ceil(size * fraction))
	syncWeapon(player)
end

local function startReload(player: Player)
	local st = states[player]
	if not st or now() < st.reloadingUntil then
		return
	end
	local size = magSize(player, st.slot)
	if st.ammo[st.slot] >= size then
		return
	end
	local ammoType = Weapons[CombatService.GetWeaponId(player, st.slot)].ammoType
	if ammoType ~= "primary" and (st.reserve[ammoType] or 0) <= 0 then
		Net.event("Notify"):FireClient(player, ("No %s ammo: find ammo bricks!"):format(ammoType), "error")
		return
	end
	st.reloadToken += 1
	local token = st.reloadToken
	local slot = st.slot
	local duration = reloadTime(player, slot)
	st.reloadingUntil = now() + duration
	syncWeapon(player)
	task.delay(duration, function()
		if states[player] == st and st.reloadToken == token then
			local needed = size - st.ammo[slot]
			if ammoType == "primary" then
				st.ammo[slot] = size
			else
				local take = math.min(needed, st.reserve[ammoType] or 0)
				st.ammo[slot] += take
				st.reserve[ammoType] = (st.reserve[ammoType] or 0) - take
			end
			st.reloadingUntil = 0
			-- Kill Clip: reloading soon after a kill
			if hasPerk(player, slot, "KillClip") and now() - st.killClipPending < 5 then
				st.killClipUntil = now() + 5
				Net.event("Notify"):FireClient(player, "Kill Clip!", "super")
			end
			syncWeapon(player)
		end
	end)
end

-- Ammo bricks: +1 magazine of that ammo type (up to the max). Returns false if already full.
function CombatService.AddReserve(player: Player, ammoType: string): boolean
	local st = states[player]
	if not st then
		return false
	end
	local mag = 1
	for _, slot in Progression.WeaponSlots do
		if Weapons[CombatService.GetWeaponId(player, slot)].ammoType == ammoType then
			mag = magSize(player, slot)
		end
	end
	local max = mag * (Progression.MaxReserveMags[ammoType] or 4)
	local current = st.reserve[ammoType] or 0
	if current >= max then
		return false
	end
	st.reserve[ammoType] = math.min(max, current + mag)
	syncWeapon(player)
	Net.event("Notify")
		:FireClient(player, ("+%s ammo"):format(if ammoType == "heavy" then "Heavy" else "Special"), "loot")
	return true
end

-- Called by EnemyService when an enemy dies
function CombatService.DropAmmo(position: Vector3, def)
	local drops = Progression.AmmoDrops
	local function brick(ammoType: string)
		local offset = Vector3.new(rng:NextNumber(-2, 2), 0, rng:NextNumber(-2, 2))
		Ordnance.SpawnAmmoBrick(position + offset, ammoType, function(p)
			return CombatService.AddReserve(p, ammoType)
		end)
	end
	if def.isBoss then
		for _ = 1, drops.bossHeavy do
			brick("heavy")
		end
		brick("special")
		return
	end
	local elite = def.xp >= 30
	if rng:NextNumber() < (if elite then drops.eliteSpecial else drops.special) then
		brick("special")
	end
	if rng:NextNumber() < (if elite then drops.eliteHeavy else drops.heavy) then
		brick("heavy")
	end
end

-- Called by EnemyService when this player lands a killing blow
function CombatService.OnKill(player: Player)
	local st = states[player]
	if not st then
		return
	end
	if hasPerk(player, st.slot, "Rampage") then
		st.rampageStacks = if now() < st.rampageUntil then math.min(3, st.rampageStacks + 1) else 1
		st.rampageUntil = now() + 5
	end
	st.killClipPending = now()
end

-- ===== Damage helpers =====

function CombatService.AddSuper(player: Player, amount: number)
	if amount > 0 and (tonumber(player:GetAttribute("OrderRank")) or 0) >= 20 then
		amount *= 1.25 -- Order upgrade: SuperGain
	end
	local charge = (tonumber(player:GetAttribute("SuperCharge")) or 0) + amount
	player:SetAttribute("SuperCharge", math.clamp(charge, 0, 100))
end

-- Damage reduction buff on a character (Bastion, Sanctuary, Lifeline...)
function CombatService.ApplyDamageReduction(char: Model, amount: number, duration: number)
	local t = now()
	local drUntil = tonumber(char:GetAttribute("DRUntil")) or 0
	local current = if drUntil > t then (tonumber(char:GetAttribute("DR")) or 0) else 0
	char:SetAttribute("DR", math.max(current, amount))
	char:SetAttribute("DRUntil", math.max(drUntil, t + duration))
end

function CombatService.FindEnemyModel(inst: Instance?): Model?
	local current = inst
	while current and current ~= workspace do
		if current:IsA("Model") and CollectionService:HasTag(current, "Enemy") then
			return current
		end
		current = current.Parent
	end
	return nil
end

-- headshot ~= nil means the damage came from a weapon; nil = ability/turret
-- element: "Ember" | "Volt" | "Null" | nil (kinetic)
function CombatService.DamageEnemy(
	model: Model,
	amount: number,
	attacker: Player?,
	headshot: boolean?,
	element: string?
)
	local hum = model:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return
	end
	local fromWeapon = headshot ~= nil
	if attacker then
		local power = attacker:GetAttribute("Power") or Progression.StartPower
		local missionPower = workspace:GetAttribute("MissionPower") or power
		amount *= Progression.powerMultiplier(power, missionPower)
		if not fromWeapon and (attacker:GetAttribute("OrderRank") or 0) >= 15 then
			amount *= 1.2 -- Order upgrade: AbilityDamage
		end
		model:SetAttribute("LastHitBy", attacker.UserId)
		model:SetAttribute("LastHitHeadshot", headshot == true)
		model:SetAttribute("LastHitSource", if fromWeapon then "Weapon" else "Ability")
		model:SetAttribute("LastHitElement", element)
		if model:GetAttribute("IsBoss") then
			CombatService.AddSuper(attacker, amount / hum.MaxHealth * Progression.SuperChargePerBossDamagePct)
		end
	end

	-- Elemental shield absorbs damage first: matching element x3, anything else x0.5
	local shield = tonumber(model:GetAttribute("Shield")) or 0
	local onShield = false
	if shield > 0 then
		onShield = true
		local shieldElement = model:GetAttribute("ShieldElement")
		local factor = if element ~= nil and element == shieldElement then 3 else 0.5
		local shieldDamage = amount * factor
		if shieldDamage < shield then
			model:SetAttribute("Shield", shield - shieldDamage)
			amount = 0
		else
			model:SetAttribute("Shield", 0)
			amount = (shieldDamage - shield) / factor -- leftover goes through to health
			CombatService.BreakShield(model, shieldElement, attacker)
		end
		amount = math.max(amount, 0)
		shield = shieldDamage -- for the damage number below
	end

	if attacker then
		local head = model:FindFirstChild("Head") :: BasePart?
		Net.event("Effect"):FireClient(attacker, "Damage", {
			position = if head then head.Position else model:GetPivot().Position,
			amount = math.floor((if onShield then shield else amount) + 0.5),
			headshot = headshot == true,
			shield = onShield,
		})
	end
	if amount > 0 then
		hum:TakeDamage(amount)
	end
end

-- Shield break: elemental burst that damages enemies around it
function CombatService.BreakShield(model: Model, element: string?, attacker: Player?)
	local pos = model:GetPivot().Position
	local def = element and Elements[element]
	Net.event("Effect"):FireAllClients("Explosion", { position = pos, radius = 10, color = if def then def.color else Color3.new(1, 1, 1) })
	if attacker then
		Net.event("Notify"):FireClient(attacker, "Shield broken!", "super")
	end
	for _, other in CollectionService:GetTagged("Enemy") do
		local part = other.PrimaryPart
		if other ~= model and part and (part.Position - pos).Magnitude <= 10 then
			task.defer(CombatService.DamageEnemy, other, 40, attacker, nil, element)
		end
	end
end

-- ===== Downed / revive =====

local function down(player: Player, char: Model, hum: Humanoid)
	char:SetAttribute("Downed", true)
	char:SetAttribute("DownedUntil", now() + Progression.DownedTime)
	hum.Health = 1
	hum.WalkSpeed = 3
	hum.JumpHeight = 0
	hum.JumpPower = 0
	local root = char:FindFirstChild("HumanoidRootPart")
	if root then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "RevivePrompt"
		prompt.ActionText = "Revive"
		prompt.ObjectText = player.DisplayName
		prompt.HoldDuration = Progression.ReviveHold
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = root
		prompt.Triggered:Connect(function(reviver)
			if reviver ~= player and CombatService.GetAlive(reviver) then
				CombatService.Revive(player, reviver)
			end
		end)
	end
	Net.event("Notify"):FireAllClients(player.DisplayName .. " is down! Hold to revive.", "error")
	downedEvent:Fire(player)
end

function CombatService.Revive(player: Player, reviver: Player?)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not char or not hum or not char:GetAttribute("Downed") then
		return
	end
	char:SetAttribute("Downed", nil)
	char:SetAttribute("DownedUntil", nil)
	local prompt = char:FindFirstChild("RevivePrompt", true)
	if prompt then
		prompt:Destroy()
	end
	hum.JumpHeight = 7.2
	hum.JumpPower = 50
	hum.Health = hum.MaxHealth * Progression.ReviveHealth
	MovementService.ApplySpeed(player)
	lastDamaged[player] = now()
	Security.AllowMovement(player, 1)
	if reviver then
		local profile = DataService.Get(reviver)
		if profile then
			profile.stats.revives += 1
		end
		Net.event("Notify"):FireAllClients(("%s revived %s"):format(reviver.DisplayName, player.DisplayName), "info")
	end
	revivedEvent:Fire(player, reviver)
end

function CombatService.DamagePlayer(player: Player, amount: number)
	local char, hum = CombatService.GetAlive(player)
	if not char or not hum then
		return -- dead or already downed
	end
	if player:GetAttribute("ClassId") == "Bulwark" then
		amount *= 0.85 -- Iron Skin
	end
	if (char:GetAttribute("DRUntil") or 0) > now() then
		amount *= 1 - (char:GetAttribute("DR") or 0)
	end
	lastDamaged[player] = now()
	Net.event("Effect"):FireClient(player, "Hurt", { amount = amount })
	if CombatService.IsCombatEnabled() and hum.Health - amount <= 0 then
		down(player, char, hum)
		return
	end
	hum:TakeDamage(amount)
end

function CombatService.Heal(player: Player, amount: number)
	local _, hum = CombatService.GetAlive(player)
	if hum then
		hum.Health = math.min(hum.MaxHealth, hum.Health + amount)
	end
end

-- ===== Shooting =====

local function spreadDirection(dir: Vector3, degrees: number): Vector3
	if degrees <= 0 then
		return dir
	end
	local cf = CFrame.lookAt(Vector3.zero, dir)
	local roll = rng:NextNumber(0, math.pi * 2)
	local pitch = math.rad(rng:NextNumber(0, degrees))
	return (cf * CFrame.Angles(0, 0, roll) * CFrame.Angles(pitch, 0, 0)).LookVector
end

local function buildRayParams(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { effectsFolder }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	return params
end
CombatService.BuildRayParams = buildRayParams

-- Send a tracer to everyone except the shooter (who already drew it locally)
local function tracerToOthers(shooter: Player, data)
	for _, p in Players:GetPlayers() do
		if p ~= shooter then
			Net.event("Effect"):FireClient(p, "Tracer", data)
		end
	end
end

local function onFire(player: Player, aimPoint: any)
	if typeof(aimPoint) ~= "Vector3" or not CombatService.IsCombatEnabled() then
		return
	end
	if aimPoint.X ~= aimPoint.X then -- NaN check
		return
	end
	local st = states[player]
	local char, _, root = CombatService.GetAlive(player)
	if not st or not char or not root then
		return
	end
	local head = char:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	local t = now()
	if t < st.reloadingUntil then
		return
	end
	local slot = st.slot
	local w = Weapons[CombatService.GetWeaponId(player, slot)]
	if t - st.lastFire < (60 / w.rpm) * 0.8 then -- 20% tolerance for latency
		return
	end
	if st.ammo[slot] <= 0 then
		startReload(player)
		return
	end

	local origin = head.Position
	local toAim = aimPoint - origin
	if toAim.Magnitude < 0.5 or toAim.Magnitude > 5000 then
		return
	end
	local baseDir = toAim.Unit
	-- Anti-exploit: you can't shoot behind yourself (the client faces the camera direction)
	local flatLook = root.CFrame.LookVector
	if baseDir:Dot(flatLook) < -0.35 then
		Security.Flag(player, "shot behind", 0.5)
		return
	end

	-- Shooting cancels sprint; aiming down sights tightens spread
	local stance = player:GetAttribute("Stance")
	if stance == "sprint" then
		MovementService.SetStance(player, "none")
	end
	local spreadMult = if stance == "ads" then 0.3 else 1

	st.lastFire = t
	st.ammo[slot] -= 1
	player:SetAttribute("Ammo", st.ammo[slot])

	local empoweredShots = player:GetAttribute("EmpoweredShots") or 0
	local empowered = empoweredShots > 0
	if empowered then
		player:SetAttribute("EmpoweredShots", empoweredShots - 1)
	end

	-- Perk multipliers
	local mult = 1
	if t < st.rampageUntil then
		mult *= 1 + 0.1 * st.rampageStacks
	end
	if t < st.killClipUntil then
		mult *= 1.25
	end
	local headseeker = hasPerk(player, slot, "Headseeker")
	local explosive = hasPerk(player, slot, "ExplosivePayload")
	local starfall = hasPerk(player, slot, "StarfallRound")

	local classId = player:GetAttribute("ClassId")
	local params = buildRayParams()
	local gun = char:FindFirstChild("Gun") :: Model?
	local muzzleAtt = gun and gun.PrimaryPart and gun.PrimaryPart:FindFirstChild("Muzzle") :: Attachment?
	local muzzle = if muzzleAtt then muzzleAtt.WorldPosition else origin + baseDir * 2
	local tracerColor = if empowered then Color3.fromRGB(200, 120, 255) else Color3.fromRGB(255, 230, 150)

	local item = CombatService.GetWeaponItem(player, slot)
	local element = item and item.element

	if w.projectile then
		-- Rocket: a real projectile that explodes on impact
		local radius = w.projectile.radius
		Ordnance.FireRocket(muzzle, baseDir, w.projectile.speed, params, function(at)
			Net.event("Effect")
				:FireAllClients("Explosion", { position = at, radius = radius, color = Color3.fromRGB(255, 160, 60) })
			for _, enemy in CollectionService:GetTagged("Enemy") do
				local part = enemy.PrimaryPart
				if part and (part.Position - at).Magnitude <= radius then
					CombatService.DamageEnemy(enemy, w.damage * mult, player, false, element)
				end
			end
		end)
		if st.ammo[slot] <= 0 then
			startReload(player)
		end
		return
	end

	for _ = 1, w.pellets do
		local dir = spreadDirection(baseDir, w.spread * spreadMult)
		local result = workspace:Raycast(origin, dir * w.range, params)
		local hitPos = if result then result.Position else origin + dir * w.range
		if result then
			local model = CombatService.FindEnemyModel(result.Instance)
			if model then
				local critMult = tonumber(result.Instance:GetAttribute("CritMult")) -- boss weak point
				local headshot = result.Instance.Name == "Head" or critMult ~= nil
				local damage = w.damage * mult * (critMult or 1)
				if headshot then
					damage *= w.headshotMult + (if headseeker then 0.3 else 0)
					if classId == "Phantom" then
						damage *= 1.25 -- Predator
					end
				end
				if empowered then
					damage *= 5
				end
				CombatService.DamageEnemy(model, damage, player, headshot, element)

				if explosive then
					for _, other in CollectionService:GetTagged("Enemy") do
						if
							other ~= model
							and other.PrimaryPart
							and (other.PrimaryPart.Position - hitPos).Magnitude < 6
						then
							CombatService.DamageEnemy(other, damage * 0.25, player, false, element)
						end
					end
				end
				if starfall then
					st.starfallHits += 1
					if st.starfallHits >= 6 then
						st.starfallHits = 0
						Net.event("Effect"):FireAllClients("Beam", {
							from = hitPos + Vector3.new(0, 120, 0),
							to = hitPos,
							color = Color3.fromRGB(255, 220, 120),
							width = 3,
							duration = 0.5,
						})
						Net.event("Effect"):FireAllClients(
							"Explosion",
							{ position = hitPos, radius = 8, color = Color3.fromRGB(255, 220, 120) }
						)
						for _, other in CollectionService:GetTagged("Enemy") do
							if other.PrimaryPart and (other.PrimaryPart.Position - hitPos).Magnitude < 8 then
								CombatService.DamageEnemy(other, 80, player, false)
							end
						end
					end
				end
			end
		end
		tracerToOthers(player, { from = muzzle, to = hitPos, color = tracerColor })
	end

	if st.ammo[slot] <= 0 then
		startReload(player)
	end
end

-- ===== Lifecycle =====

local function onCharacter(player: Player, char: Model)
	lastDamaged[player] = 0
	char:WaitForChild("RightHand", 10)
	CombatService.RefreshLoadout(player)
	local hum = char:WaitForChild("Humanoid", 10) :: Humanoid?
	if hum then
		hum.Died:Connect(function()
			local profile = DataService.Get(player)
			if profile and CombatService.IsCombatEnabled() then
				profile.stats.deaths += 1
			end
		end)
	end
end

function CombatService.Start()
	Net.event("Fire").OnServerEvent:Connect(Security.Guard("Fire", 20, onFire))
	Net.event("Reload").OnServerEvent:Connect(Security.Guard("Reload", 4, function(player)
		startReload(player)
	end))
	Net.event("SwitchWeapon").OnServerEvent:Connect(Security.Guard("SwitchWeapon", 4, function(player, slot)
		local st = states[player]
		if not st or not table.find(Progression.WeaponSlots, slot) or st.slot == slot then
			return
		end
		st.slot = slot
		st.reloadToken += 1
		st.reloadingUntil = 0
		syncWeapon(player)
		attachGun(player)
	end))
	-- Aim pitch for the arm/gun pose that other players see
	Net.unreliable("AimPitch").OnServerEvent:Connect(function(player, pitch)
		if type(pitch) ~= "number" or pitch ~= pitch or not Security.Allow(player, "AimPitch", 20) then
			return
		end
		local char = player.Character
		if char then
			char:SetAttribute("AimPitch", math.clamp(pitch, -1.4, 1.4))
		end
	end)

	local function onPlayer(player: Player)
		player:SetAttribute("SuperCharge", 0)
		player.CharacterAdded:Connect(function(char)
			DataService.WaitFor(player)
			onCharacter(player, char)
		end)
		DataService.WaitFor(player)
		CombatService.RefreshLoadout(player)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do
		task.spawn(onPlayer, p)
	end
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
		lastDamaged[player] = nil
	end)

	ProgressionService.GearChanged:Connect(function(player)
		CombatService.RefreshLoadout(player)
	end)

	-- Regen, Lifebinder aura, passive super charge, bleed-out
	task.spawn(function()
		local TICK = 0.25
		while true do
			task.wait(TICK)
			if CombatService.IsCombatEnabled() then
				local t = now()
				local healers: { Vector3 } = {}
				for _, p in Players:GetPlayers() do
					local _, _, root = CombatService.GetAlive(p)
					if root and p:GetAttribute("ClassId") == "Lifebinder" then
						table.insert(healers, root.Position)
					end
				end
				for _, p in Players:GetPlayers() do
					local char = p.Character
					if char and char:GetAttribute("Downed") and t > (char:GetAttribute("DownedUntil") or 0) then
						-- Bled out
						char:SetAttribute("Downed", nil)
						local hum = char:FindFirstChildOfClass("Humanoid")
						if hum then
							hum.Health = 0
						end
					end
					local _, hum, root = CombatService.GetAlive(p)
					if hum and root then
						if t - (lastDamaged[p] or 0) > REGEN_DELAY then
							hum.Health = math.min(hum.MaxHealth, hum.Health + hum.MaxHealth * REGEN_PER_SECOND * TICK)
						end
						for _, pos in healers do
							if (pos - root.Position).Magnitude <= 25 then
								hum.Health = math.min(hum.MaxHealth, hum.Health + 2 * TICK) -- Mending Aura
								break
							end
						end
						CombatService.AddSuper(p, Progression.SuperChargePerSecond * TICK)
					end
				end
			end
		end
	end)
end

return CombatService
