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
local AimPose = require(script.Parent.AimPose)

local Combat = {}

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local firing = false
local fireQueued = false
local lastReloadRequest = 0
local Menus: any = nil

local SHOULDER_OFFSET = Vector3.new(2, 0.6, 0)
local SLIDE_OFFSET = Vector3.new(2, -1.4, 0)
local HIP_FOV = 70
local SPRINT_FOV = 76
local AIM_ASSIST_DEGREES = 3.5 -- gamepad/touch only: bullet magnetism cone

-- Movement / aim state
local aiming = false
local sprinting = false
local stanceSent = "none"
local nextShotTime = 0
local usingMouse = not UserInputService.TouchEnabled
local autoFire = UserInputService.TouchEnabled -- mobile default ON (toggle with the AUTO button)
local touchFireHeld = false
local baseSensitivity: number? = nil

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

local function enemyOf(inst: Instance?): Model?
	local current = inst
	while current and current ~= workspace do
		if current:IsA("Model") and CollectionService:HasTag(current, "Enemy") then
			return current
		end
		current = current.Parent
	end
	return nil
end

-- Aim assist (gamepad/touch only): if an enemy is within a small cone of the crosshair and
-- visible, aim at it. Mouse players never get assist.
local function assistTarget(origin: Vector3, dir: Vector3, params: RaycastParams): Vector3?
	if usingMouse then
		return nil
	end
	local best, bestAngle = nil, math.rad(AIM_ASSIST_DEGREES)
	for _, model in CollectionService:GetTagged("Enemy") do
		local hum = model:FindFirstChildOfClass("Humanoid")
		local head = model:FindFirstChild("Head") :: BasePart?
		local body = model.PrimaryPart
		if hum and hum.Health > 0 and body then
			for _, part in { head, body } do
				if part then
					local to = part.Position - origin
					local angle = math.acos(math.clamp(dir:Dot(to.Unit), -1, 1))
					if angle < bestAngle and to.Magnitude < 300 then
						local hit = workspace:Raycast(origin, to, params)
						if hit and enemyOf(hit.Instance) == model then
							best, bestAngle = part.Position, angle
						end
					end
				end
			end
		end
	end
	return best
end

-- World point under the crosshair (screen center), with aim assist on gamepad/touch
function Combat.AimPoint(): Vector3
	local vp = camera.ViewportSize
	local ray = camera:ViewportPointToRay(vp.X / 2, vp.Y / 2)
	local params = getRayParams()
	local assisted = assistTarget(ray.Origin, ray.Direction, params)
	if assisted then
		return assisted
	end
	local result = workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
	return if result then result.Position else ray.Origin + ray.Direction * 1000
end

-- Is the crosshair (or assist cone) on an enemy right now? Used by mobile auto-fire.
local function crosshairOnEnemy(): boolean
	local vp = camera.ViewportSize
	local ray = camera:ViewportPointToRay(vp.X / 2, vp.Y / 2)
	local params = getRayParams()
	if assistTarget(ray.Origin, ray.Direction, params) then
		return true
	end
	local result = workspace:Raycast(ray.Origin, ray.Direction * 300, params)
	return result ~= nil and enemyOf(result.Instance) ~= nil
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
	[Enum.KeyCode.Q] = function()
		useAbility("Q")
	end,
	[Enum.KeyCode.E] = function()
		useAbility("E")
	end,
	[Enum.KeyCode.F] = function()
		useAbility("F")
	end,
	[Enum.KeyCode.R] = reload,
	[Enum.KeyCode.One] = function()
		swapWeapon("primary")
	end,
	[Enum.KeyCode.Two] = function()
		swapWeapon("secondary")
	end,
	[Enum.KeyCode.Tab] = function()
		if Menus then
			if Menus.IsOpen() then
				Menus.Close()
			else
				Menus.Open("Fireteam")
			end
		end
	end,
	-- Gamepad
	[Enum.KeyCode.ButtonL1] = function()
		useAbility("Q")
	end,
	[Enum.KeyCode.ButtonR1] = function()
		useAbility("E")
	end,
	[Enum.KeyCode.ButtonB] = function()
		useAbility("F")
	end,
	[Enum.KeyCode.ButtonX] = reload,
	[Enum.KeyCode.ButtonY] = function()
		swapWeapon(nil)
	end,
}

local function tryMantle()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	local state = hum:GetState()
	if state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping then
		Net.event("Mantle"):FireServer()
	end
end

local function trySlide()
	if sprinting then
		Net.event("Slide"):FireServer()
	end
end

local function onInputBegan(input: InputObject, processed: boolean)
	if processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2 then
		firing = true
		fireQueued = true
		sprinting = false
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton2 or input.KeyCode == Enum.KeyCode.ButtonL2 then
		aiming = true
		sprinting = false
		return
	end
	if input.KeyCode == Enum.KeyCode.LeftShift then
		sprinting = true
		aiming = false
		return
	end
	if input.KeyCode == Enum.KeyCode.ButtonL3 then
		sprinting = not sprinting
		return
	end
	if
		input.KeyCode == Enum.KeyCode.C
		or input.KeyCode == Enum.KeyCode.LeftControl
		or input.KeyCode == Enum.KeyCode.ButtonR3
	then
		trySlide()
		return
	end
	if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
		tryMantle() -- jumping is still handled by Roblox; this only adds the ledge climb
	end
	local action = KEY_ACTIONS[input.KeyCode]
	if action then
		action()
	end
end

local function onInputEnded(input: InputObject)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2 then
		firing = false
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 or input.KeyCode == Enum.KeyCode.ButtonL2 then
		aiming = false
	elseif input.KeyCode == Enum.KeyCode.LeftShift then
		sprinting = false
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
		touchFireHeld = true
		firing = true
		fireQueued = true
	end, function()
		touchFireHeld = false
		firing = false
	end)
	bind("TouchAim", "AIM", UDim2.new(1, -90, 1, -130), function()
		aiming = not aiming
		sprinting = false
	end)
	bind("TouchSprint", "RUN", UDim2.new(0, 20, 1, -260), function()
		sprinting = not sprinting
		aiming = false
	end)
	bind("TouchSlide", "SLIDE", UDim2.new(0, 90, 1, -260), trySlide)
	bind("TouchAuto", "AUTO", UDim2.new(1, -90, 1, -320), function()
		autoFire = not autoFire
		ContextActionService:SetTitle("TouchAuto", if autoFire then "AUTO" else "auto off")
	end)
	bind("TouchQ", "Q", UDim2.new(1, -230, 1, -130), function()
		useAbility("Q")
	end)
	bind("TouchE", "E", UDim2.new(1, -230, 1, -200), function()
		useAbility("E")
	end)
	bind("TouchF", "SUPER", UDim2.new(1, -170, 1, -260), function()
		useAbility("F")
	end)
	bind("TouchReload", "R", UDim2.new(1, -90, 1, -250), reload)
	bind("TouchSwap", "SWAP", UDim2.new(1, -300, 1, -160), function()
		swapWeapon(nil)
	end)
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

	-- Field of view: zoom when aiming, widen a little when sprinting (frame-rate independent smoothing)
	local w = Weapons[player:GetAttribute("WeaponId") or ""]
	local targetFov = if combat
			and aiming
			and w
		then w.adsFov
		elseif sprinting and hum.MoveDirection.Magnitude > 0 then SPRINT_FOV
		else HIP_FOV
	camera.FieldOfView += (targetFov - camera.FieldOfView) * (1 - math.exp(-14 * dt))
	-- Keep the crosshair speed on screen the same when zoomed: scale mouse sensitivity by tan(fov/2)
	pcall(function()
		if baseSensitivity == nil then
			baseSensitivity = UserInputService.MouseDeltaSensitivity
		end
		local ratio = math.tan(math.rad(camera.FieldOfView) / 2) / math.tan(math.rad(HIP_FOV) / 2)
		UserInputService.MouseDeltaSensitivity = (baseSensitivity :: number) * math.min(1, ratio)
	end)

	if combat then
		local sliding = (tonumber(char:GetAttribute("SlidingUntil")) or 0) > workspace:GetServerTimeNow()
		hum.CameraOffset = if sliding then SLIDE_OFFSET else SHOULDER_OFFSET
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

local function updateStance()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local moving = hum ~= nil and hum.MoveDirection.Magnitude > 0.1
	local desired = "none"
	if aiming and inMission() then
		desired = "ads"
	elseif sprinting and moving and not firing then
		desired = "sprint"
	end
	if not moving and not UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and usingMouse then
		sprinting = false
	end
	if desired ~= stanceSent then
		stanceSent = desired
		Net.event("SetStance"):FireServer(desired)
	end
end

local function updateShooting()
	updateStance()
	if not inMission() or (Menus and Menus.IsOpen()) then
		fireQueued = false
		return
	end
	-- Mobile auto-fire: shoot while the crosshair (or assist cone) is on an enemy
	if autoFire and not usingMouse and not touchFireHeld then
		firing = crosshairOnEnemy()
		if firing then
			fireQueued = true
		end
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
	-- Fire on a scheduled clock (not "last shot = now"), so fire rate doesn't drop at low FPS
	local now = os.clock()
	local interval = 60 / w.rpm
	if nextShotTime < now - interval then
		nextShotTime = now -- idle gap: don't bank shots
	end
	if nextShotTime <= now then
		nextShotTime += interval
		fireQueued = false
		sprinting = false
		local aim = Combat.AimPoint()
		Net.event("Fire"):FireServer(aim)
		Combat.PredictShot(w, aim)
	end
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
			dir = (cf * CFrame.Angles(0, 0, math.random() * math.pi * 2) * CFrame.Angles(
				math.rad(math.random() * w.spread),
				0,
				0
			)).LookVector
		end
		local result = workspace:Raycast(head.Position, dir * w.range, params)
		local hitPos = if result then result.Position else head.Position + dir * w.range
		if result and enemyOf(result.Instance) then
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

function Combat.Start(menus)
	Menus = menus
	UserInputService.LastInputTypeChanged:Connect(function(inputType)
		usingMouse = inputType == Enum.UserInputType.Keyboard
			or inputType == Enum.UserInputType.MouseButton1
			or inputType == Enum.UserInputType.MouseButton2
			or inputType == Enum.UserInputType.MouseMovement
			or inputType == Enum.UserInputType.MouseWheel
	end)
	UserInputService.InputBegan:Connect(onInputBegan)
	UserInputService.InputEnded:Connect(onInputEnded)
	bindTouchButtons()
	RunService:BindToRenderStep("StarfallCamera", Enum.RenderPriority.Camera.Value + 1, updateCamera)
	RunService.Heartbeat:Connect(updateShooting)
	RunService.Stepped:Connect(function()
		AimPose.Update(inMission())
	end)

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
