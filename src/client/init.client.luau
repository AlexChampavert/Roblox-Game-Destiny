-- STARFALL client bootstrap.

local Controllers = script:WaitForChild("Controllers")

local Effects = require(Controllers:WaitForChild("Effects"))
local Menus = require(Controllers:WaitForChild("Menus"))
local HUD = require(Controllers:WaitForChild("HUD"))
local Combat = require(Controllers:WaitForChild("Combat"))

Effects.Start()
Menus.Start()
HUD.Start()
Combat.Start(Menus)
Combat.OnHitmarker(HUD.Hitmarker)

-- Quick-access buttons (top right)
HUD.AddButton("Bounties", function()
	Menus.Open("Bounties")
end)
HUD.AddButton("Gear", function()
	Menus.Open("Inventory")
end)
HUD.AddButton("Fireteam", function()
	Menus.Open("Fireteam")
end)
HUD.AddButton("Missions", function()
	if workspace:GetAttribute("Mode") == "Hub" then
		Menus.Open("Missions")
	end
end)
HUD.AddButton("Class", function()
	if workspace:GetAttribute("Mode") == "Hub" then
		Menus.Open("Classes")
	end
end)
