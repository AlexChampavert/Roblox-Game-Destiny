-- Over-the-shoulder camera, shooting, abilities, and input (keyboard/mouse, gamepad, touch).
-- PC: LMB fire · R reload · 1/2 weapons · Q/E abilities · F super · Tab fireteam
-- Gamepad: RT fire · X reload · Y swap · LB/RB abilities · B super
-- Mobile: on-screen buttons

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Weapons = require(Shared:WaitForChild("Config"):WaitForChild("Weapons"))

local Effects = require(script.Parent.Effects)

local Combat = {}

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local firing = false
local fireQueued = false
local lastShot = 0
local lastReloadRequest = 0
local Menus: any = nil

local SHOULDER_OFFSET = Vector3.new(2, 0.6, 0)

local recoilKick = 0 -- degrees, decays every frame
local hitmarkerCallback: ((boolean) -> ())? = nil
function Combat.OnHitmarker(cb: (boolean) -> ())
	hitmarkerCallback = cb
end

local function inMission(): boolean
	return workspace:GetAttribute("Mode") == "Mission"
end

local function getRayParams(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { Effects.Folder }
	if player.Character then
		table.insert(ignore, player.Character)
	end
	local serverEffects = workspace:FindFirstChild("Effects")
	if serverEffects then
		table.insert(ignore, serverEffects)
	end
	params.FilterDescendantsInstances = ignore
	return params
end

-- World point under the crosshair (screen center)
function Combat.AimPoint(): Vector3
	local vp = camera.ViewportSize
	local ray = camera:ViewportPointToRay(vp.X / 2, vp.Y / 2)
	local result = workspace:Raycast(ray.Origin, ray.Direction * 1000, getRayParams())
	return if result then result.Position else ray.Origin + ray.Direction * 1000
end

-- E is also the interact key for ProximityPrompts: don't fire an ability while one is shown
local promptsShown = 0
game:GetService("ProximityPromptService").PromptShown:Connect(function(prompt)
	promptsShown += 1
	prompt.PromptHidden:Once(function()
		promptsShown = math.max(0, promptsShown - 1)
	end)
end)

local function useAbility(slot: string)
	if Menus and Menus.IsOpen() then
		return
	end
	if slot == "E" and promptsShown > 0 then
		return
	end
	Net.event("UseAbility"):FireServer(slot, Combat.AimPoint())
end

local function reload()
	if os.clock() - lastReloadRequest > 0.5 then
		lastReloadRequest = os.clock()
		Net.event("Reload"):FireServer()
	end
end

local function swapWeapon(slot: string?)
	local current = player:GetAttribute("WeaponSlot") or "primary"
	local target = slot or (if current == "primary" then "secondary" else "primary")
	Net.event("SwitchWeapon"):FireServer(target)
end

-- ===== Input =====

local KEY_ACTIONS: { [Enum.KeyCode]: () -> () } = {
	[Enum.KeyCode.Q] = function() useAbility("Q") end,
	[Enum.KeyCode.E] = function() useAbility("E") end,
	[Enum.KeyCode.F] = function() useAbility("F") end,
	[Enum.KeyCode.R] = reload,
	[Enum.KeyCode.One] = function() swapWeapon("primary") end,
	[Enum.KeyCode.Two] = function() swapWeapon("secondary") end,
	[Enum.KeyCode.Tab] = function()
		if Menus then
			if Menus.IsOpen() then Menus.Close() else Menus.Open("Fireteam") end
		end
	end,
	-- Gamepad
	[Enum.KeyCode.ButtonL1] = function() useAbility("Q") end,
	[Enum.KeyCode.ButtonR1] = function() useAbility("E") end,
	[Enum.KeyCode.ButtonB] = function() useAbility("F") end,
	[Enum.KeyCode.ButtonX] = reload,
	[Enum.KeyCode.ButtonY] = function() swapWeapon(nil) end,
}

local function onInputBegan(input: InputObject, processed: boolean)
	if processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2 then
		firing = true
		fireQueued = true
		return
	end
	local action = KEY_ACTIONS[input.KeyCode]
	if action then
		action()
	end
end

local function onInputEnded(input: InputObject)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2 then
		firing = false
	end
end

local function bindTouchButtons()
	if not UserInputService.TouchEnabled then
		return
	end
	local function bind(name: string, title: string, pos: UDim2, began: () -> (), ended: (() -> ())?)
		ContextActionService:BindAction(name, function(_, state)
			if state == Enum.UserInputState.Begin then
				began()
			elseif state == Enum.UserInputState.End and ended then
				ended()
			end
			return Enum.ContextActionResult.Sink
		end, true)
		ContextActionService:SetTitle(name, title)
		ContextActionService:SetPosition(name, pos)
	end
	bind("TouchFire", "FIRE", UDim2.new(1, -150, 1, -190), function()
		firing = true
		fireQueued = true
	end, function()
		firing = false
	end)
	bind("TouchQ", "Q", UDim2.new(1, -230, 1, -130), function() useAbility("Q") end)
	bind("TouchE", "E", UDim2.new(1, -230, 1, -200), function() useAbility("E") end)
	bind("TouchF", "SUPER", UDim2.new(1, -170, 1, -260), function() useAbility("F") end)
	bind("TouchReload", "R", UDim2.new(1, -90, 1, -250), reload)
	bind("TouchSwap", "SWAP", UDim2.new(1, -300, 1, -160), function() swapWeapon(nil) end)
end

-- ===== Per frame =====

local function updateCamera(dt: number)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hum or not root then
		return
	end
	local combat = inMission() and hum.Health > 0 and not (Menus and Menus.IsOpen())
	if combat then
		hum.CameraOffset = SHOULDER_OFFSET
		hum.AutoRotate = false
		if not UserInputService.TouchEnabled then
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
			UserInputService.MouseIconEnabled = false
		end
		-- Face where the camera looks
		local look = camera.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude > 0.01 then
			root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
		end
		player.CameraMaxZoomDistance = 14
		player.CameraMinZoomDistance = 6
		-- Visual recoil kick (the camera module recomputes the base CFrame each frame)
		if recoilKick > 0.01 then
			camera.CFrame *= CFrame.Angles(math.rad(recoilKick), 0, 0)
			recoilKick *= math.max(0, 1 - dt * 14)
		end
	else
		hum.CameraOffset = Vector3.zero
		hum.AutoRotate = true
		if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
		UserInputService.MouseIconEnabled = true
		player.CameraMaxZoomDistance = 40
		player.CameraMinZoomDistance = 0.5
	end
end

local function updateShooting()
	if not inMission() or (Menus and Menus.IsOpen()) then
		fireQueued = false
		return
	end
	local w = Weapons[player:GetAttribute("WeaponId") or ""]
	if not w then
		return
	end
	local wantShot = (w.automatic and firing) or fireQueued
	if not wantShot then
		return
	end
	if player:GetAttribute("Reloading") then
		return
	end
	if (player:GetAttribute("Ammo") or 0) <= 0 then
		reload()
		fireQueued = false
		return
	end
	local now = os.clock()
	if now - lastShot >= 60 / w.rpm then
		lastShot = now
		fireQueued = false
		local aim = Combat.AimPoint()
		Net.event("Fire"):FireServer(aim)
		Combat.PredictShot(w, aim)
	end
end

local function findEnemy(inst: Instance?): Model?
	local current = inst
	while current and current ~= workspace do
		if current:IsA("Model") and CollectionService:HasTag(current, "Enemy") then
			return current
		end
		current = current.Parent
	end
	return nil
end

-- Client-side prediction: draw the shot instantly; the server stays authoritative
-- (damage numbers come back from the server).
function Combat.PredictShot(w, aim: Vector3)
	local char = player.Character
	local head = char and char:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	local gun = char:FindFirstChild("Gun") :: Model?
	local muzzleAtt = gun and gun.PrimaryPart and gun.PrimaryPart:FindFirstChild("Muzzle") :: Attachment?
	local muzzle = if muzzleAtt then muzzleAtt.WorldPosition else head.Position
	local params = getRayParams()
	local baseDir = (aim - head.Position).Unit
	local anyHit, anyHead = false, false
	for _ = 1, w.pellets do
		local dir = baseDir
		if w.pellets > 1 or w.spread > 1 then
			local cf = CFrame.lookAt(Vector3.zero, baseDir)
			dir = (cf * CFrame.Angles(0, 0, math.random() * math.pi * 2) * CFrame.Angles(math.rad(math.random() * w.spread), 0, 0)).LookVector
		end
		local result = workspace:Raycast(head.Position, dir * w.range, params)
		local hitPos = if result then result.Position else head.Position + dir * w.range
		if result and findEnemy(result.Instance) then
			anyHit = true
			anyHead = anyHead or result.Instance.Name == "Head"
		end
		Effects.Tracer({ from = muzzle, to = hitPos, color = Color3.fromRGB(255, 230, 150) })
	end
	Effects.MuzzleFlash(muzzle)
	recoilKick = math.min(recoilKick + w.recoil, 12)
	if anyHit and hitmarkerCallback then
		hitmarkerCallback(anyHead)
	end
	if w.fireSound then
		local sound = Instance.new("Sound")
		sound.SoundId = w.fireSound
		sound.Volume = 0.6
		sound.Parent = head
		sound:Play()
		game:GetService("Debris"):AddItem(sound, 2)
	end
end

-- ===== Aim pose: arms follow the camera pitch (yours locally, others via AimPitch) =====

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
		if right and originalC0[right] then right.C0 = originalC0[right] end
		if left and originalC0[left] then left.C0 = originalC0[left] end
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

local function updatePoses()
	local mission = inMission()
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
			poseCharacter(char, if aiming then (char:GetAttribute("AimPitch") or 0) else nil, other:GetAttribute("Reloading") == true)
		end
	end
end

function Combat.Start(menus)
	Menus = menus
	UserInputService.InputBegan:Connect(onInputBegan)
	UserInputService.InputEnded:Connect(onInputEnded)
	bindTouchButtons()
	RunService:BindToRenderStep("StarfallCamera", Enum.RenderPriority.Camera.Value + 1, updateCamera)
	RunService.Heartbeat:Connect(updateShooting)
	RunService.Stepped:Connect(updatePoses)

	-- You can't revive yourself: hide the revive prompt on your own character
	local function hideOwnPrompt(char: Model)
		char.DescendantAdded:Connect(function(d)
			if d:IsA("ProximityPrompt") and d.Name == "RevivePrompt" then
				d.Enabled = false
			end
		end)
	end
	player.CharacterAdded:Connect(hideOwnPrompt)
	if player.Character then
		hideOwnPrompt(player.Character)
	end
end

return Combat
