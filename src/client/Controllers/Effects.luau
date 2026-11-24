-- Client-side visual effects driven by the server's "Effect" remote.
-- Also applies movement impulses (dashes / thrusters) to the local character.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

local Effects = {}

local player = Players.LocalPlayer
local folder = Instance.new("Folder")
folder.Name = "ClientEffects"
folder.Parent = workspace
Effects.Folder = folder

local hurtCallback: ((number) -> ())? = nil
function Effects.OnHurt(cb: (number) -> ())
	hurtCallback = cb
end

local function basicPart(): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	return p
end

-- Tracer pool: reuse parts instead of creating/destroying hundreds per second
local pool: { Part } = {}
local POOL_MAX = 80

local function getPooled(): Part
	local p = table.remove(pool)
	if p then
		p.Transparency = 0
		return p
	end
	local np = basicPart()
	np.Parent = folder
	return np
end

local function release(p: Part)
	if #pool < POOL_MAX then
		p.Transparency = 1
		p.CFrame = CFrame.new(0, -10000, 0)
		table.insert(pool, p)
	else
		p:Destroy()
	end
end

local function tracer(data)
	local from: Vector3, to: Vector3 = data.from, data.to
	local length = (to - from).Magnitude
	if length < 0.1 then
		return
	end
	local p = getPooled()
	local thick = if data.enemy then 0.35 else 0.15
	p.Shape = Enum.PartType.Block
	p.Size = Vector3.new(thick, thick, length)
	p.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -length / 2)
	p.Color = data.color or Color3.new(1, 1, 0.7)
	local tween = TweenService:Create(p, TweenInfo.new(0.12), { Transparency = 1 })
	tween:Play()
	task.delay(0.13, release, p)
end
Effects.Tracer = tracer

function Effects.MuzzleFlash(position: Vector3, color: Color3?)
	local p = getPooled()
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(0.9, 0.9, 0.9)
	p.CFrame = CFrame.new(position)
	p.Color = color or Color3.fromRGB(255, 220, 140)
	task.delay(0.05, release, p)
end

local function explosion(data)
	local p = basicPart()
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(1, 1, 1)
	p.Position = data.position
	p.Color = data.color or Color3.new(1, 0.6, 0.2)
	p.Transparency = 0.2
	p.Parent = folder
	local d = (data.radius or 5) * 2
	TweenService:Create(
		p,
		TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(d, d, d), Transparency = 1 }
	):Play()
	Debris:AddItem(p, 0.4)
end

local function beam(data)
	local from: Vector3, to: Vector3 = data.from, data.to
	local length = (to - from).Magnitude
	local p = basicPart()
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(length, data.width or 6, data.width or 6)
	p.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -length / 2) * CFrame.Angles(0, math.rad(90), 0)
	p.Color = data.color or Color3.new(1, 1, 1)
	p.Parent = folder
	TweenService
		:Create(p, TweenInfo.new(data.duration or 1), { Transparency = 1, Size = Vector3.new(length, 0.5, 0.5) })
		:Play()
	Debris:AddItem(p, (data.duration or 1) + 0.1)
end

local function heal(data)
	local p = basicPart()
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(0.3, 2, 2)
	p.CFrame = CFrame.new(data.position - Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
	p.Color = Color3.fromRGB(90, 255, 140)
	p.Transparency = 0.2
	p.Parent = folder
	local d = (data.radius or 10) * 2
	TweenService:Create(
		p,
		TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(0.3, d, d), Transparency = 1 }
	):Play()
	Debris:AddItem(p, 0.7)
end

local function damageNumber(data)
	local anchor = basicPart()
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.1, 0.1, 0.1)
	anchor.Position = data.position + Vector3.new(math.random(-10, 10) / 10, 1, math.random(-10, 10) / 10)
	anchor.Parent = folder
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(80, 30)
	gui.AlwaysOnTop = true
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = tostring(data.amount)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = if data.shield then Color3.fromRGB(120, 200, 255)
		elseif data.headshot then Color3.fromRGB(255, 220, 60)
		else Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Parent = gui
	TweenService:Create(anchor, TweenInfo.new(0.6), { Position = anchor.Position + Vector3.new(0, 3, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(0.6), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(anchor, 0.65)
end

local function impulse(data)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local att = Instance.new("Attachment")
	att.Parent = root
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = att
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.VectorVelocity = data.velocity
	lv.MaxForce = math.huge
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.Parent = root
	Debris:AddItem(lv, data.duration or 0.25)
	Debris:AddItem(att, data.duration or 0.25)
end

local handlers = {
	Tracer = tracer,
	Explosion = explosion,
	Beam = beam,
	Heal = heal,
	Damage = damageNumber,
	Impulse = impulse,
	Hurt = function(data)
		if hurtCallback then
			hurtCallback(data.amount)
		end
	end,
}

function Effects.Start()
	Net.event("Effect").OnClientEvent:Connect(function(kind, data)
		local handler = handlers[kind]
		if handler then
			handler(data)
		end
	end)
end

return Effects
