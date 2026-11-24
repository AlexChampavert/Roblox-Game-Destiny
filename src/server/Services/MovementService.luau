-- Stances (sprint / aim down sights), slide and mantle. Server-authoritative:
-- the client asks, the server checks state and geometry, then applies speed or moves the player.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Classes = require(Shared.Config.Classes)
local Net = require(Shared.Net)

local Security = require(script.Parent.Security)

local MovementService = {}

local SPRINT_MULT = 1.45
local ADS_MULT = 0.6
local SLIDE_SPEED = 48
local SLIDE_TIME = 0.45
local SLIDE_COOLDOWN = 1.2
local MANTLE_COOLDOWN = 0.6
local MANTLE_MIN, MANTLE_MAX = 1.5, 7.5 -- ledge height above the feet (studs)

local lastSlide: { [Player]: number } = {}
local lastMantle: { [Player]: number } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function getChar(player: Player): (Model?, Humanoid?, BasePart?)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not char or not hum or not root or hum.Health <= 0 or char:GetAttribute("Downed") then
		return nil, nil, nil
	end
	return char, hum, root
end

function MovementService.BaseSpeed(player: Player): number
	local classId = player:GetAttribute("ClassId")
	local class = classId and Classes.Defs[classId]
	return if class then class.walkSpeed else 16
end

-- Single place that decides WalkSpeed (class base x stance). Downed players are left alone.
function MovementService.ApplySpeed(player: Player)
	local _, hum = getChar(player)
	if not hum then
		return
	end
	local stance = player:GetAttribute("Stance")
	local mult = if stance == "sprint" then SPRINT_MULT elseif stance == "ads" then ADS_MULT else 1
	hum.WalkSpeed = MovementService.BaseSpeed(player) * mult
end

function MovementService.SetStance(player: Player, stance: string)
	if stance ~= "none" and stance ~= "sprint" and stance ~= "ads" then
		return
	end
	if player:GetAttribute("Stance") == stance then
		return
	end
	player:SetAttribute("Stance", stance)
	MovementService.ApplySpeed(player)
end

local function rayParams(char: Model): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { char }
	for _, name in { "Effects", "ClientEffects", "Enemies" } do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(ignore, f)
		end
	end
	params.FilterDescendantsInstances = ignore
	return params
end

local function onSlide(player: Player)
	local char, hum, root = getChar(player)
	if not char or not hum or not root then
		return
	end
	local t = now()
	if player:GetAttribute("Stance") ~= "sprint" or hum.FloorMaterial == Enum.Material.Air then
		return
	end
	if t - (lastSlide[player] or 0) < SLIDE_COOLDOWN then
		return
	end
	lastSlide[player] = t
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.1 then
		return
	end
	Security.AllowMovement(player, SLIDE_TIME + 1)
	char:SetAttribute("SlidingUntil", t + SLIDE_TIME + 0.2)
	Net.event("Effect"):FireClient(player, "Impulse", { velocity = flat.Unit * SLIDE_SPEED, duration = SLIDE_TIME })
end

local function onMantle(player: Player)
	local char, hum, root = getChar(player)
	if not char or not hum or not root then
		return
	end
	local t = now()
	if t - (lastMantle[player] or 0) < MANTLE_COOLDOWN then
		return
	end
	local look = root.CFrame.LookVector
	local forward = Vector3.new(look.X, 0, look.Z)
	if forward.Magnitude < 0.1 then
		return
	end
	forward = forward.Unit
	local params = rayParams(char)
	local feetY = root.Position.Y - (root.Size.Y / 2 + hum.HipHeight)

	-- 1) A wall right in front of the chest
	local wall = workspace:Raycast(root.Position, forward * 3.5, params)
	if not wall then
		return
	end
	-- 2) A ledge top just past the wall, within reach
	local probe = wall.Position + forward * 1.5 + Vector3.new(0, MANTLE_MAX + 2, 0)
	local top = workspace:Raycast(probe, Vector3.new(0, -(MANTLE_MAX + 4), 0), params)
	if not top or top.Normal.Y < 0.7 then
		return
	end
	local height = top.Position.Y - feetY
	if height < MANTLE_MIN or height > MANTLE_MAX then
		return
	end
	-- 3) Room to stand on the ledge
	if workspace:Raycast(top.Position + Vector3.new(0, 0.2, 0), Vector3.new(0, 5, 0), params) then
		return
	end
	lastMantle[player] = t
	Security.AllowMovement(player, 1.5)
	local standY = top.Position.Y + hum.HipHeight + root.Size.Y / 2 + 0.1
	local target = Vector3.new(top.Position.X, standY, top.Position.Z)
	char:PivotTo(CFrame.lookAt(target, target + forward))
	Net.event("Effect"):FireAllClients("Explosion", { position = top.Position, radius = 2, color = Color3.fromRGB(200, 200, 210) })
end

function MovementService.Start()
	Net.event("SetStance").OnServerEvent:Connect(Security.Guard("SetStance", 10, function(player, stance)
		if type(stance) == "string" then
			MovementService.SetStance(player, stance)
		end
	end))
	Net.event("Slide").OnServerEvent:Connect(Security.Guard("Slide", 3, onSlide))
	Net.event("Mantle").OnServerEvent:Connect(Security.Guard("Mantle", 4, onMantle))

	Players.PlayerAdded:Connect(function(player)
		player:SetAttribute("Stance", "none")
		player.CharacterAdded:Connect(function()
			player:SetAttribute("Stance", "none")
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastSlide[player] = nil
		lastMantle[player] = nil
	end)
end

return MovementService
