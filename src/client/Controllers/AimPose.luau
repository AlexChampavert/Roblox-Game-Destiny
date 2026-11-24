-- Aim pose: arms (and the gun welded to the right hand) follow the camera pitch.
-- Your own pitch comes from the camera; other players' from their AimPitch attribute,
-- which the server sets from the AimPitch UnreliableRemoteEvent.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

local AimPose = {}

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local originalC0: { [Motor6D]: CFrame } = {}
local lastPitchSent, lastPitchTime = 0, 0

local function poseCharacter(char: Model, pitch: number?, reloading: boolean)
	local upperR = char:FindFirstChild("RightUpperArm")
	local upperL = char:FindFirstChild("LeftUpperArm")
	local right = upperR and upperR:FindFirstChild("RightShoulder") :: Motor6D?
	local left = upperL and upperL:FindFirstChild("LeftShoulder") :: Motor6D?
	for _, motor in { right, left } do
		if motor and not originalC0[motor] then
			originalC0[motor] = motor.C0
			motor.Destroying:Once(function()
				originalC0[motor] = nil
			end)
		end
	end
	if pitch == nil then
		if right and originalC0[right] then
			right.C0 = originalC0[right]
		end
		if left and originalC0[left] then
			left.C0 = originalC0[left]
		end
		return
	end
	local p = if reloading then -0.6 else pitch
	if right then
		right.C0 = originalC0[right] * CFrame.Angles(math.pi / 2 + p, 0, 0)
	end
	if left then
		left.C0 = originalC0[left] * CFrame.Angles(0, -0.7, 0) * CFrame.Angles(math.pi / 2 + p, 0, 0)
	end
end

function AimPose.Update(mission: boolean)
	-- Local player
	local myChar = player.Character
	if myChar then
		local aiming = mission and myChar:FindFirstChild("Gun") ~= nil and not myChar:GetAttribute("Downed")
		local pitch = math.asin(math.clamp(camera.CFrame.LookVector.Y, -1, 1))
		poseCharacter(myChar, if aiming then pitch else nil, player:GetAttribute("Reloading") == true)
		local t = os.clock()
		if aiming and t - lastPitchTime > 0.1 and math.abs(pitch - lastPitchSent) > 0.02 then
			lastPitchTime, lastPitchSent = t, pitch
			Net.unreliable("AimPitch"):FireServer(pitch)
		end
	end
	-- Everyone else
	for _, other in Players:GetPlayers() do
		local char = other.Character
		if other ~= player and char then
			local aiming = mission and char:FindFirstChild("Gun") ~= nil and not char:GetAttribute("Downed")
			poseCharacter(
				char,
				if aiming then (char:GetAttribute("AimPitch") or 0) else nil,
				other:GetAttribute("Reloading") == true
			)
		end
	end
end

return AimPose
