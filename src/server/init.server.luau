-- STARFALL server bootstrap.
-- One place, two modes:
--   HUB     : public servers. Builds the Meridian, handles classes/fireteams/launching.
--   MISSION : reserved servers created by a fireteam launch. Reads the missionId from
--             the teleport data and runs that mission.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Missions = require(Shared.Config.Missions)
require(Shared.Net) -- creates the remotes

local Services = script:WaitForChild("Services")
local World = script:WaitForChild("World")

local isReserved = game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
workspace:SetAttribute("ReservedServer", isReserved)
workspace:SetAttribute("Mode", if isReserved then "Mission" else "Hub")

if isReserved then
	-- Don't spawn anyone until the mission map exists
	Players.CharacterAutoLoads = false
else
	require(World.HubBuilder).Build()
end

local Security = require(Services.Security)
local MovementService = require(Services.MovementService)
local Telemetry = require(Services.Telemetry)
local DataService = require(Services.DataService)
local ProgressionService = require(Services.ProgressionService)
local CombatService = require(Services.CombatService)
local ClassService = require(Services.ClassService)
local AbilityService = require(Services.AbilityService)
local EnemyService = require(Services.EnemyService)
local StoryService = require(Services.StoryService)
local MissionService = require(Services.MissionService)
local BountyService = require(Services.BountyService)
local LoadoutService = require(Services.LoadoutService)
local MatchmakingService = require(Services.MatchmakingService)
local LobbyService = require(Services.LobbyService)

Security.Start()
MovementService.Start()
DataService.Start()
CombatService.Start()
ClassService.Start()
AbilityService.Start()
EnemyService.Start()
StoryService.Start()
MissionService.Init()
BountyService.Start()
LoadoutService.Start()
MatchmakingService.Start()
LobbyService.Start()

-- Analytics hooks
Players.PlayerAdded:Connect(function(player)
	Telemetry.Step(player, Telemetry.Funnel.Joined)
end)
Players.PlayerRemoving:Connect(Telemetry.Forget)
ProgressionService.LeveledUp:Connect(function(player, level)
	if level >= 5 then
		Telemetry.Step(player, Telemetry.Funnel.Level5)
	end
	Telemetry.Event(player, "LevelUp", level)
end)
Security.OnFlag(function(player, reason)
	Telemetry.Event(player, "SecurityFlag_" .. (reason:match("^[%a:]+") or "other"))
end)

if isReserved then
	local missionId: string? = nil
	local function readJoinData(player: Player)
		local data = player:GetJoinData().TeleportData
		if type(data) == "table" and type(data.missionId) == "string" and Missions.Defs[data.missionId] then
			missionId = missionId or data.missionId
		end
	end
	Players.PlayerAdded:Connect(readJoinData)
	for _, p in Players:GetPlayers() do
		readJoinData(p)
	end

	local waited = 0
	while not missionId and waited < 20 do
		task.wait(0.25)
		waited += 0.25
	end
	if not missionId then
		warn("[Bootstrap] No mission in teleport data, defaulting to WakeProtocol")
	end

	MissionService.Start(missionId or "WakeProtocol")
	Players.CharacterAutoLoads = true
	for _, p in Players:GetPlayers() do
		DataService.WaitFor(p)
		if not p.Character then
			task.spawn(p.LoadCharacter, p)
		end
	end
	-- Late joiners (rest of the fireteam) spawn normally and get placed at the checkpoint
end

print(("[Starfall] Server ready in %s mode"):format(workspace:GetAttribute("Mode")))
