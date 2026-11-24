-- Inventory (equip / dismantle) and the order vendors in each class hall.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Loot = require(Shared.Config.Loot)
local Classes = require(Shared.Config.Classes)
local Net = require(Shared.Net)

local DataService = require(script.Parent.DataService)
local ProgressionService = require(script.Parent.ProgressionService)
local ClassService = require(script.Parent.ClassService)
local Security = require(script.Parent.Security)

local LoadoutService = {}

local function notify(player: Player, text: string, kind: string?)
	Net.event("Notify"):FireClient(player, text, kind or "info")
end

local function onInventory(player: Player, action: any, uid: any)
	if type(uid) ~= "string" then
		return
	end
	if action == "Equip" then
		if workspace:GetAttribute("Mode") ~= "Hub" then
			notify(player, "Change gear on the Meridian.", "error")
			return
		end
		ProgressionService.Equip(player, uid)
	elseif action == "Dismantle" then
		ProgressionService.Dismantle(player, uid)
	end
end

local function onVendor(player: Player, action: any)
	local profile = DataService.Get(player)
	if not profile or workspace:GetAttribute("Mode") ~= "Hub" then
		return
	end
	local classId = profile.classId
	if not classId or not Classes.Defs[classId] then
		notify(player, "Join an order first.", "error")
		return
	end
	if action == "BuyEngram" then
		if not ProgressionService.AddShards(player, -Loot.Vendor.EngramCost) then
			notify(player, ("You need %d Shards."):format(Loot.Vendor.EngramCost), "error")
			return
		end
		ProgressionService.GrantGear(player, false, 1)
	elseif action == "BuyArmorStyle" then
		if profile.cosmetics.orderArmor[classId] then
			notify(player, "You already own this order's armor.", "error")
			return
		end
		if not ProgressionService.AddShards(player, -Loot.Vendor.ArmorStyleCost) then
			notify(player, ("You need %d Shards."):format(Loot.Vendor.ArmorStyleCost), "error")
			return
		end
		profile.cosmetics.orderArmor[classId] = true
		ClassService.Refresh(player)
		notify(player, ("%s order armor unlocked!"):format(Classes.Defs[classId].name), "levelup")
	end
end

function LoadoutService.Start()
	Net.event("Inventory").OnServerEvent:Connect(Security.Guard("Inventory", 5, onInventory))
	Net.event("Vendor").OnServerEvent:Connect(Security.Guard("Vendor", 2, onVendor))
end

return LoadoutService
