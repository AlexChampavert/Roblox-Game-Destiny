-- Runs a mission: builds the map, plays the objective steps in order, handles wipes
-- (checkpoint restart), rewards, and sends everyone back to the Meridian.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Missions = require(Shared.Config.Missions)
local Progression = require(Shared.Config.Progression)
local Story = require(Shared.Config.Story)
local Net = require(Shared.Net)

local DataService = require(script.Parent.DataService)
local CombatService = require(script.Parent.CombatService)
local EnemyService = require(script.Parent.EnemyService)
local ProgressionService = require(script.Parent.ProgressionService)
local StoryService = require(script.Parent.StoryService)
local Ordnance = require(script.Parent.Ordnance)
local BountyService = require(script.Parent.BountyService)
local Security = require(script.Parent.Security)
local Telemetry = require(script.Parent.Telemetry)
local MissionBuilder = require(script.Parent.Parent.World.MissionBuilder)
local HubBuilder = require(script.Parent.Parent.World.HubBuilder)

local MissionService = {}

local STUDIO_ORIGIN = Vector3.new(0, 0, 4000) -- test missions in Studio are built away from the hub
local RETURN_DELAY = 20

local active: {
	def: any,
	layout: any,
	stepIndex: number,
	checkpoint: CFrame,
	running: boolean,
	startedAt: number,
}? =
	nil

local rng = Random.new()

local function objective(text: string, progress: number?)
	if not active then
		return
	end
	Net.event("ObjectiveUpdate"):FireAllClients({
		mission = active.def.name,
		step = active.stepIndex,
		steps = #active.def.steps,
		text = text,
		progress = progress,
	})
end

local function notifyAll(text: string, kind: string?)
	Net.event("Notify"):FireAllClients(text, kind or "info")
end

local function alivePlayers(): { Player }
	local list = {}
	for _, p in Players:GetPlayers() do
		if CombatService.GetAlive(p) then
			table.insert(list, p)
		end
	end
	return list
end

local function wiped(): boolean
	return #Players:GetPlayers() > 0 and #alivePlayers() == 0
end

local function anyPlayerWithin(pos: Vector3, radius: number): boolean
	for _, p in alivePlayers() do
		local _, _, root = CombatService.GetAlive(p)
		if root and (root.Position - pos).Magnitude <= radius then
			return true
		end
	end
	return false
end

local function scaling()
	local n = math.max(#Players:GetPlayers(), 1)
	return {
		healthMult = 1 + (n - 1) * Progression.HealthScalePerExtraPlayer,
		extra = (n - 1) * Progression.ExtraEnemiesPerExtraPlayer
			+ (if workspace:GetAttribute("Modifier") == "Frenzy" then 1 else 0),
	}
end

local function spawnWave(wave: { [string]: number }, zone)
	local s = scaling()
	local first = true
	for enemyId, count in wave do
		local total = count + (if first then s.extra else 0)
		first = false
		for _ = 1, total do
			local point = zone.spawnPoints[rng:NextInteger(1, #zone.spawnPoints)]
			local jitter = Vector3.new(rng:NextNumber(-6, 6), 0, rng:NextNumber(-6, 6))
			EnemyService.Spawn(enemyId, point + jitter, { healthMult = s.healthMult })
			task.wait(0.15)
		end
	end
end

local function setBeacon(zone, visible: boolean)
	if zone.beacon then
		zone.beacon.Transparency = if visible then 0.35 else 1
	end
end

-- ===== Step runners =====
-- Each returns true when the step is complete, false if the fireteam wiped.

local Runners = {}

function Runners.Reach(step, zone): boolean
	setBeacon(zone, true)
	objective(step.text)
	while not anyPlayerWithin(zone.center, 25) do
		if wiped() then
			return false
		end
		task.wait(0.25)
	end
	setBeacon(zone, false)
	return true
end

function Runners.Clear(step, zone): boolean
	local waves = step.waves or {}
	for i, wave in waves do
		objective(("%s (wave %d/%d)"):format(step.text, i, #waves))
		spawnWave(wave, zone)
		while EnemyService.CountAlive() > 0 do
			if wiped() then
				return false
			end
			task.wait(0.25)
		end
		task.wait(1.5)
	end
	return true
end

function Runners.Defend(step, zone): boolean
	setBeacon(zone, true)
	local duration = step.duration or 45
	local waves = step.waves or {}
	local interval = duration / math.max(#waves, 1)
	local progress = 0
	local nextWave = 1
	local nextWaveAt = 0
	while progress < duration do
		if wiped() then
			setBeacon(zone, false)
			return false
		end
		if nextWave <= #waves and progress >= nextWaveAt then
			task.spawn(spawnWave, waves[nextWave], zone)
			nextWave += 1
			nextWaveAt += interval
		end
		local holding = anyPlayerWithin(zone.center, 30)
		if holding then
			progress += 0.25
		end
		objective(if holding then step.text else step.text .. " — get back in the zone!", progress / duration)
		task.wait(0.25)
	end
	setBeacon(zone, false)
	EnemyService.ClearAll()
	return true
end

function Runners.Capture(step, zone): boolean
	local captureTime = step.captureTime or 8
	local waves = step.waves or {}
	local done = 0
	local progress: { [BasePart]: number } = {}
	for _, pad in zone.pads do
		progress[pad] = 0
	end
	if waves[1] then
		task.spawn(spawnWave, waves[1], zone)
	end
	while done < #zone.pads do
		if wiped() then
			return false
		end
		for i, pad in zone.pads do
			if progress[pad] < captureTime and anyPlayerWithin(pad.Position, 9) then
				progress[pad] += 0.25
				pad.Color = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(60, 200, 255), progress[pad] / captureTime)
				if progress[pad] >= captureTime then
					done += 1
					notifyAll(("Node %d secured"):format(i), "info")
					local wave = waves[(done % math.max(#waves, 1)) + 1]
					if wave and done < #zone.pads then
						task.spawn(spawnWave, wave, zone)
					end
				end
			end
		end
		local partial = 0
		for _, v in progress do
			partial += v / captureTime
		end
		objective(("%s (%d/%d)"):format(step.text, done, #zone.pads), partial / #zone.pads)
		task.wait(0.25)
	end
	return true
end

function Runners.Escort(step, zone): boolean
	local path = zone.dronePath
	if #path < 2 then
		return true
	end
	local drone = Instance.new("Part")
	drone.Name = "DataDrone"
	drone.Shape = Enum.PartType.Ball
	drone.Size = Vector3.new(4, 4, 4)
	drone.Material = Enum.Material.Neon
	drone.Color = Color3.fromRGB(0, 255, 200)
	drone.Anchored = true
	drone.CanCollide = false
	drone.Position = path[1]
	local light = Instance.new("PointLight")
	light.Color = drone.Color
	light.Range = 25
	light.Parent = drone
	drone.Parent = CombatService.EffectsFolder

	local waves = step.waves or {}
	local totalLength = 0
	for i = 2, #path do
		totalLength += (path[i] - path[i - 1]).Magnitude
	end
	local travelled = 0
	local segment = 2
	local nextWave = 1
	local SPEED = 6
	local ok = true
	while segment <= #path do
		if wiped() then
			ok = false
			break
		end
		local fraction = travelled / totalLength
		if nextWave <= #waves and fraction >= (nextWave - 1) / #waves then
			task.spawn(spawnWave, waves[nextWave], zone)
			nextWave += 1
		end
		local escorted = anyPlayerWithin(drone.Position, 30)
		if escorted then
			local target = path[segment]
			local offset = target - drone.Position
			local stepDist = SPEED * 0.1
			if offset.Magnitude <= stepDist then
				drone.Position = target
				segment += 1
			else
				drone.Position += offset.Unit * stepDist
			end
			travelled += stepDist
		end
		objective(
			if escorted then step.text else step.text .. " — stay close to the drone!",
			math.clamp(travelled / totalLength, 0, 1)
		)
		task.wait(0.1)
	end
	drone:Destroy()
	return ok
end

function Runners.Boss(step, zone): boolean
	setBeacon(zone, true)
	objective(step.text)
	task.wait(2)
	setBeacon(zone, false)
	local s = scaling()
	local boss = EnemyService.Spawn(step.boss, zone.center, { healthMult = s.healthMult })
	if not boss then
		return true
	end
	notifyAll(boss.Name .. " has appeared!", "boss")
	local hum = boss:FindFirstChildOfClass("Humanoid") :: Humanoid
	while hum.Health > 0 do
		if wiped() then
			return false
		end
		task.wait(0.25)
	end
	EnemyService.ClearAll()
	return true
end

-- ===== Flow =====

-- With StreamingEnabled, make sure the client has the area loaded before moving them there
local function teleportPlayer(player: Player, cf: CFrame)
	pcall(function()
		player:RequestStreamAroundAsync(cf.Position, 5)
	end)
	local char = player.Character
	if char then
		Security.AllowMovement(player, 3)
		char:PivotTo(cf)
	end
end
MissionService.TeleportPlayer = teleportPlayer

-- One SpawnLocation that follows the current checkpoint, so respawns land in the right place
local missionSpawn: SpawnLocation? = nil
local function setSpawn(cf: CFrame?)
	local hubSpawn = workspace:FindFirstChild("HubSpawn", true) :: SpawnLocation?
	if cf then
		if not missionSpawn then
			local sp = Instance.new("SpawnLocation")
			sp.Name = "MissionSpawn"
			sp.Size = Vector3.new(12, 1, 12)
			sp.Anchored = true
			sp.CanCollide = false
			sp.Transparency = 1
			sp.Neutral = true
			sp.Duration = 3 -- short spawn protection
			sp.Parent = workspace
			missionSpawn = sp
		end
		local spawn = missionSpawn :: SpawnLocation
		spawn.CFrame = cf - Vector3.new(0, 3, 0)
		if hubSpawn then
			hubSpawn.Enabled = false
		end
	else
		if missionSpawn then
			missionSpawn:Destroy()
			missionSpawn = nil
		end
		if hubSpawn then
			hubSpawn.Enabled = true
		end
	end
end

local function placeAtCheckpoint(player: Player)
	if not active then
		return
	end
	local offset = Vector3.new(rng:NextNumber(-6, 6), 0, rng:NextNumber(-6, 6))
	teleportPlayer(player, active.checkpoint + offset)
end

local function finish()
	local a = active
	if not a then
		return
	end
	local def = a.def
	local featured = workspace:GetAttribute("Featured") == true
	notifyAll(def.outro, "story")
	objective("MISSION COMPLETE — returning to the Meridian in " .. RETURN_DELAY .. "s", 1)
	for _, p in Players:GetPlayers() do
		local profile = DataService.Get(p)
		if profile then
			ProgressionService.AddXP(p, def.xpReward * (if featured then 2 else 1))
			ProgressionService.AddShards(p, def.shardReward)
			ProgressionService.GrantGear(p, true)
			profile.completed[def.id] = (profile.completed[def.id] or 0) + 1
			profile.stats.missions += 1
			StoryService.SetFlag(p, "Completed_" .. def.id)
			BountyService.Track(p, "Mission", 1)
			Telemetry.Step(p, Telemetry.Funnel.FirstClear)
			if profile.stats.missions >= 2 then
				Telemetry.Step(p, Telemetry.Funnel.SecondMission)
			end
			Telemetry.Event(p, "MissionComplete_" .. def.id, os.clock() - a.startedAt)
			task.spawn(DataService.Save, p)
		end
	end
	task.wait(RETURN_DELAY)
	MissionService.ReturnToHub()
end

function MissionService.ReturnToHub()
	local a = active
	if RunService:IsStudio() or not workspace:GetAttribute("ReservedServer") then
		-- Studio test: tear down and move everyone back to the hub
		EnemyService.ClearAll()
		Ordnance.Clear()
		if a then
			MissionBuilder.Clear(a.layout)
		end
		setSpawn(nil)
		active = nil
		MissionBuilder.RestoreTheme()
		HubBuilder.ApplyLighting()
		workspace:SetAttribute("Mode", "Hub")
		workspace:SetAttribute("MissionId", nil)
		workspace:SetAttribute("Modifier", nil)
		workspace:SetAttribute("Featured", nil)
		Net.event("ObjectiveUpdate"):FireAllClients(nil)
		for _, p in Players:GetPlayers() do
			if p.Character then
				Security.AllowMovement(p, 2)
				local hum = p.Character:FindFirstChildOfClass("Humanoid")
				if p.Character:GetAttribute("Downed") or (hum and hum.Health <= 0) then
					p:LoadCharacter()
				else
					teleportPlayer(p, HubBuilder.SpawnCFrame)
				end
			end
		end
		return
	end
	-- Live: teleport the whole fireteam to a public hub server
	local players = Players:GetPlayers()
	local ok, err = pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, players)
	end)
	if not ok then
		warn("[MissionService] return teleport failed:", err)
		for _, p in players do
			p:Kick("Mission complete! Rejoin to return to the Meridian.")
		end
	end
end

function MissionService.IsActive(): boolean
	return active ~= nil
end

function MissionService.Start(missionId: string)
	local def = Missions.Defs[missionId]
	if not def or active then
		return
	end
	local chapter = Story.currentChapter()
	workspace:SetAttribute("Mode", "Mission")
	workspace:SetAttribute("MissionId", missionId)
	workspace:SetAttribute("MissionPower", def.recommendedPower)
	workspace:SetAttribute("Featured", chapter.featuredMission == missionId)
	workspace:SetAttribute("Modifier", if chapter.featuredMission == missionId then chapter.modifier else nil)

	local origin = if workspace:GetAttribute("ReservedServer") then Vector3.zero else STUDIO_ORIGIN
	MissionBuilder.ApplyTheme(def.theme)
	local layout = MissionBuilder.Build(def, origin)
	active =
		{ def = def, layout = layout, stepIndex = 0, checkpoint = layout.start, running = true, startedAt = os.clock() }
	setSpawn(layout.start)

	for _, p in Players:GetPlayers() do
		Telemetry.Step(p, Telemetry.Funnel.FirstLaunch)
		p:SetAttribute("SuperCharge", 0)
		CombatService.RefreshLoadout(p, true) -- fresh special/heavy reserves
		placeAtCheckpoint(p)
	end
	notifyAll(def.intro, "story")
	if workspace:GetAttribute("Featured") then
		notifyAll(
			"Featured mission this week: double XP!"
				.. (
					if workspace:GetAttribute("Modifier")
						then " Modifier: " .. workspace:GetAttribute("Modifier")
						else ""
				),
			"info"
		)
	end

	task.spawn(function()
		task.wait(6) -- let the rest of the fireteam load in
		local a = active
		while a and a.stepIndex < #def.steps do
			a.stepIndex += 1
			local step = def.steps[a.stepIndex]
			local zone = layout.zones[a.stepIndex]
			local runner = Runners[step.type]
			local success = false
			while not success do
				local ok, result = pcall(runner, step, zone)
				if not ok then
					warn("[MissionService] step error:", result)
					result = true -- don't soft-lock the fireteam on a bug
				end
				success = result
				if not success then
					notifyAll("Fireteam wiped. Restarting from checkpoint...", "error")
					for _, p in Players:GetPlayers() do
						Telemetry.Event(p, "Wipe_" .. def.id .. "_" .. step.type)
					end
					EnemyService.ClearAll()
					task.wait(Players.RespawnTime + 1)
					for _, p in Players:GetPlayers() do
						if not CombatService.GetAlive(p) then
							p:LoadCharacter()
						end
						placeAtCheckpoint(p)
					end
					task.wait(2)
				end
			end
			-- Next checkpoint = entrance of the next zone
			local nextZone = layout.zones[a.stepIndex + 1]
			if nextZone then
				a.checkpoint = nextZone.checkpoint
				setSpawn(nextZone.checkpoint)
				notifyAll("Checkpoint reached", "info")
			end
		end
		finish()
	end)
end

function MissionService.Init()
	Players.RespawnTime = 6
	-- Respawn players at the current checkpoint during a mission
	local function hook(player: Player)
		player.CharacterAdded:Connect(function()
			if active then
				task.wait()
				placeAtCheckpoint(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, p in Players:GetPlayers() do
		hook(p)
	end
end

return MissionService
