--!strict
-- Creates (server) or finds (client) every RemoteEvent / RemoteFunction by name.
-- Usage: local Net = require(Shared.Net); Net.event("Fire"):FireServer(...)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = {
	-- client -> server
	"SelectClass", -- (classId)
	"Fire", -- (aimPoint: Vector3)
	"Reload", -- ()
	"SwitchWeapon", -- (slot: "primary" | "secondary")
	"UseAbility", -- (slot: "Q" | "E" | "F", aimPoint: Vector3)
	"FireteamAction", -- (action: string, arg: any)
	"LaunchMission", -- (missionId)
	"Matchmaking", -- ("Join", missionId) | ("Cancel")
	"Inventory", -- ("Equip" | "Dismantle", itemUid)
	"Vendor", -- ("BuyEngram" | "BuyArmorStyle")
	"SetStance", -- ("none" | "sprint" | "ads")
	"Slide", -- ()
	"Mantle", -- ()
	-- server -> client
	"Notify", -- (text, kind)
	"ObjectiveUpdate", -- ({ mission, text, progress })
	"FireteamUpdate", -- (state table)
	"Effect", -- (kind, data)
	"OpenMenu", -- (menuName, arg?)
	"Loot", -- (item table)
}

-- High-frequency, loss-tolerant (UnreliableRemoteEvent)
local UNRELIABLE = {
	"AimPitch", -- client -> server: (pitch radians), ~10/s
}

local FUNCTIONS = {
	"GetState", -- () -> state table for menus
}

local Net = {}

local folder: Folder
if RunService:IsServer() then
	folder = Instance.new("Folder")
	folder.Name = "Remotes"
	for _, name in EVENTS do
		local e = Instance.new("RemoteEvent")
		e.Name = name
		e.Parent = folder
	end
	for _, name in UNRELIABLE do
		local u = Instance.new("UnreliableRemoteEvent")
		u.Name = name
		u.Parent = folder
	end
	for _, name in FUNCTIONS do
		local f = Instance.new("RemoteFunction")
		f.Name = name
		f.Parent = folder
	end
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

function Net.event(name: string): RemoteEvent
	return folder:WaitForChild(name) :: RemoteEvent
end

function Net.unreliable(name: string): UnreliableRemoteEvent
	return folder:WaitForChild(name) :: UnreliableRemoteEvent
end

function Net.func(name: string): RemoteFunction
	return folder:WaitForChild(name) :: RemoteFunction
end

return Net
