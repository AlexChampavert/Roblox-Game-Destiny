-- Client-side ambient animation for the hub (smooth and free for the server):
--   Orbiter : models flying in circles around the ship (attrs CenterY, Radius, Speed, Phase)
--   Spinner : parts that rotate (Speed rad/s) and optionally bob up and down (Bob studs)
--   Blinker : neon parts that pulse (Period s, MinT/MaxT transparency, Offset s)

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Ambience = {}

type Spin = { part: BasePart, base: CFrame, speed: number, bob: number, world: boolean }
local spinners: { [BasePart]: Spin } = {}

local function trackSpinner(inst: Instance)
	if inst:IsA("BasePart") then
		spinners[inst] = {
			part = inst,
			base = inst.CFrame,
			speed = tonumber(inst:GetAttribute("Speed")) or 1,
			bob = tonumber(inst:GetAttribute("Bob")) or 0,
			world = inst:GetAttribute("Axis") == "World",
		}
	end
end

local function untrack(inst: Instance)
	if inst:IsA("BasePart") then
		spinners[inst] = nil
	end
end

local function step()
	local t = os.clock()

	for _, model in CollectionService:GetTagged("Orbiter") do
		if model:IsA("Model") and model.PrimaryPart then
			local r = tonumber(model:GetAttribute("Radius")) or 300
			local speed = tonumber(model:GetAttribute("Speed")) or 0.05
			local a = (tonumber(model:GetAttribute("Phase")) or 0) + t * speed
			local y = (tonumber(model:GetAttribute("CenterY")) or 150) + math.sin(a * 3) * 6
			local pos = Vector3.new(math.cos(a) * r, y, math.sin(a) * r)
			-- face along the direction of travel
			local tangent = Vector3.new(-math.sin(a), 0, math.cos(a)) * math.sign(speed)
			model:PivotTo(CFrame.lookAt(pos, pos + tangent))
		end
	end

	for part, s in spinners do
		if not part.Parent then
			spinners[part] = nil
			continue
		end
		local angle = t * s.speed
		local bob = if s.bob > 0 then Vector3.new(0, math.sin(t * 1.5) * s.bob, 0) else Vector3.zero
		if s.world then
			part.CFrame = CFrame.new(s.base.Position + bob) * CFrame.Angles(0, angle, 0) * s.base.Rotation
		else
			part.CFrame = (s.base + bob) * CFrame.Angles(0, angle, 0)
		end
	end

	for _, part in CollectionService:GetTagged("Blinker") do
		if part:IsA("BasePart") then
			local period = tonumber(part:GetAttribute("Period")) or 2
			local minT = tonumber(part:GetAttribute("MinT")) or 0
			local maxT = tonumber(part:GetAttribute("MaxT")) or 0.8
			local phase = ((t + (tonumber(part:GetAttribute("Offset")) or 0)) % period) / period
			local wave = (math.sin(phase * math.pi * 2) + 1) / 2
			part.Transparency = minT + (maxT - minT) * wave
		end
	end
end

function Ambience.Start()
	for _, inst in CollectionService:GetTagged("Spinner") do
		trackSpinner(inst)
	end
	CollectionService:GetInstanceAddedSignal("Spinner"):Connect(trackSpinner)
	CollectionService:GetInstanceRemovedSignal("Spinner"):Connect(untrack)
	RunService.RenderStepped:Connect(function()
		local ok, err = pcall(step)
		if not ok then
			warn("[Ambience]", err)
		end
	end)
end

return Ambience
