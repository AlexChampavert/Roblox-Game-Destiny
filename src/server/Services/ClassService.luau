-- Class selection and applying class stats to the character.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Classes = require(Shared.Config.Classes)
local Net = require(Shared.Net)

local DataService = require(script.Parent.DataService)
local CombatService = require(script.Parent.CombatService)
local Security = require(script.Parent.Security)
local Telemetry = require(script.Parent.Telemetry)

local ClassService = {}

local function applyToCharacter(player: Player, char: Model)
	local profile = DataService.Get(player)
	local class = profile and profile.classId and Classes.Defs[profile.classId]
	local hum = char:WaitForChild("Humanoid", 10) :: Humanoid?
	if not hum then
		return
	end
	if not class then
		hum.MaxHealth = 100
		hum.Health = 100
		hum.WalkSpeed = 16
		return
	end
	hum.MaxHealth = class.maxHealth
	hum.Health = class.maxHealth
	hum.WalkSpeed = class.walkSpeed
	char:SetAttribute("ClassId", class.id)

	-- Class color stripe so teammates can tell classes apart (replace with armor sets later)
	local highlight = char:FindFirstChild("ClassHighlight") :: Highlight?
	if not highlight then
		local newHighlight = Instance.new("Highlight")
		newHighlight.Name = "ClassHighlight"
		newHighlight.FillTransparency = 1
		newHighlight.OutlineTransparency = 0.3
		newHighlight.DepthMode = Enum.HighlightDepthMode.Occluded
		newHighlight.Parent = char
		highlight = newHighlight
	end
	local outline = highlight :: Highlight
	outline.OutlineColor = class.color

	-- Order armor (bought from the order vendor): tint the body in the class colors
	if profile.cosmetics.orderArmor[class.id] then
		local dark = class.color:Lerp(Color3.new(0, 0, 0), 0.55)
		for _, name in { "UpperTorso", "LowerTorso", "LeftUpperArm", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg" } do
			local part = char:FindFirstChild(name) :: BasePart?
			if part then
				part.Color = if name:find("Torso") then dark else class.color
				part.Material = Enum.Material.Metal
			end
		end
	end
end

function ClassService.Refresh(player: Player)
	if player.Character then
		applyToCharacter(player, player.Character)
	end
end

function ClassService.SetClass(player: Player, classId: string): boolean
	local profile = DataService.Get(player)
	if not profile or not Classes.Defs[classId] then
		return false
	end
	if workspace:GetAttribute("Mode") ~= "Hub" and profile.classId ~= nil then
		Net.event("Notify"):FireClient(player, "You can only change class on the Meridian.", "error")
		return false
	end
	if not profile.classId then
		Telemetry.Step(player, Telemetry.Funnel.ClassPicked)
	end
	profile.classId = classId
	DataService.Sync(player)
	player:SetAttribute("SuperCharge", 0)
	player:SetAttribute("ReadyQ", 0)
	player:SetAttribute("ReadyE", 0)
	CombatService.RefreshLoadout(player)
	if player.Character then
		applyToCharacter(player, player.Character)
	end
	Net.event("Notify"):FireClient(player, ("You joined the %s order."):format(Classes.Defs[classId].name), "info")
	return true
end

function ClassService.Start()
	Net.event("SelectClass").OnServerEvent:Connect(Security.Guard("SelectClass", 2, function(player, classId)
		if type(classId) == "string" then
			ClassService.SetClass(player, classId)
		end
	end))

	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(char)
			DataService.WaitFor(player)
			applyToCharacter(player, char)
		end)
		local profile = DataService.WaitFor(player)
		if player.Character then
			applyToCharacter(player, player.Character)
		end
		-- New players pick a class first
		if profile and not profile.classId then
			Net.event("OpenMenu"):FireClient(player, "Classes")
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do
		task.spawn(onPlayer, p)
	end
end

return ClassService
