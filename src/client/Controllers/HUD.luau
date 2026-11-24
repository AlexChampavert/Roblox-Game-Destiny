-- In-game HUD: health, ammo, abilities, super, level/XP, objective, notifications.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Classes = require(Shared:WaitForChild("Config"):WaitForChild("Classes"))

local UI = require(script.Parent.UI)
local Effects = require(script.Parent.Effects)
local Loot = require(Shared:WaitForChild("Config"):WaitForChild("Loot"))

local HUD = {}

local player = Players.LocalPlayer
local C = UI.Colors

local gui: ScreenGui
local refs: { [string]: any } = {}
local feed: Frame

local function bar(parent: Instance, name: string, position: UDim2, size: UDim2, color: Color3): (Frame, Frame)
	local back = UI.new("Frame", {
		Name = name,
		Position = position,
		Size = size,
		BackgroundColor3 = Color3.fromRGB(25, 28, 38),
		BorderSizePixel = 0,
		Parent = parent,
	}, { UI.corner(4) })
	local fill = UI.new(
		"Frame",
		{ Name = "Fill", Size = UDim2.fromScale(1, 1), BackgroundColor3 = color, BorderSizePixel = 0, Parent = back },
		{ UI.corner(4) }
	)
	return back, fill
end

local function abilityBox(parent: Instance, key: string, x: number): { [string]: any }
	local box = UI.new("Frame", {
		Name = "Ability" .. key,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, x, 1, -14),
		Size = UDim2.fromOffset(if key == "F" then 74 else 60, if key == "F" then 74 else 60),
		BackgroundColor3 = C.panel,
		Parent = parent,
	}, { UI.corner(10), UI.stroke() })
	local cover = UI.new("Frame", {
		Name = "Cooldown",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = box,
	}, { UI.corner(10) })
	local keyLabel = UI.label({
		Text = key,
		Size = UDim2.new(0, 18, 0, 18),
		Position = UDim2.fromOffset(4, 2),
		TextColor3 = C.accent,
		ZIndex = 3,
		Parent = box,
	})
	local name = UI.label({
		Text = "",
		Size = UDim2.new(1, -6, 0.42, 0),
		Position = UDim2.new(0, 3, 0.52, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
		Parent = box,
	})
	local timer = UI.label({
		Text = "",
		Size = UDim2.new(1, 0, 0.4, 0),
		Position = UDim2.fromScale(0, 0.12),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.gold,
		ZIndex = 3,
		Parent = box,
	})
	return { box = box, cover = cover, name = name, timer = timer, key = keyLabel }
end

local function build()
	gui = UI.new("ScreenGui", {
		Name = "HUD",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})

	-- Crosshair
	refs.crosshair = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(6, 6),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = gui,
	}, { UI.corner(3), UI.stroke(Color3.new(0, 0, 0), 1) })

	-- Top-left: level, XP, power, shards
	local profile = UI.new("Frame", {
		Position = UDim2.fromOffset(14, 14),
		Size = UDim2.fromOffset(250, 64),
		BackgroundColor3 = C.bg,
		BackgroundTransparency = 0.25,
		Parent = gui,
	}, { UI.corner(10), UI.padding(8) })
	refs.level = UI.label({ Text = "LV 1", Size = UDim2.new(0.35, 0, 0.45, 0), TextColor3 = C.gold, Parent = profile })
	refs.power = UI.label({
		Text = "⚡ 10",
		Size = UDim2.new(0.3, 0, 0.45, 0),
		Position = UDim2.fromScale(0.36, 0),
		TextColor3 = C.accent,
		Parent = profile,
	})
	refs.shards = UI.label({
		Text = "◆ 0",
		Size = UDim2.new(0.3, 0, 0.45, 0),
		Position = UDim2.fromScale(0.68, 0),
		TextColor3 = Color3.fromRGB(190, 150, 255),
		Parent = profile,
	})
	local _, xpFill = bar(profile, "XP", UDim2.fromScale(0, 0.62), UDim2.new(1, 0, 0.25, 0), C.gold)
	refs.xpFill = xpFill

	-- Top-right buttons
	local buttons = UI.new("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 14),
		Size = UDim2.fromOffset(520, 40),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		UI.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			Padding = UDim.new(0, 8),
		}),
	})
	refs.buttons = buttons

	-- Objective (top-center)
	local obj = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 14),
		Size = UDim2.fromOffset(420, 70),
		BackgroundColor3 = C.bg,
		BackgroundTransparency = 0.25,
		Visible = false,
		Parent = gui,
	}, { UI.corner(10), UI.padding(8) })
	refs.objective = obj
	refs.objMission = UI.label({ Text = "", Size = UDim2.new(1, 0, 0.3, 0), TextColor3 = C.accent, Parent = obj })
	refs.objText =
		UI.label({ Text = "", Size = UDim2.new(1, 0, 0.38, 0), Position = UDim2.fromScale(0, 0.32), Parent = obj })
	local objBar, objFill = bar(obj, "Progress", UDim2.fromScale(0, 0.82), UDim2.new(1, 0, 0.16, 0), C.accent)
	refs.objBar, refs.objFill = objBar, objFill

	-- Health (bottom-left)
	local hp = UI.new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 14, 1, -14),
		Size = UDim2.fromOffset(260, 44),
		BackgroundColor3 = C.bg,
		BackgroundTransparency = 0.25,
		Parent = gui,
	}, { UI.corner(10), UI.padding(8) })
	refs.className = UI.label({ Text = "", Size = UDim2.new(1, 0, 0.42, 0), TextColor3 = C.dim, Parent = hp })
	local _, hpFill = bar(hp, "Health", UDim2.fromScale(0, 0.55), UDim2.new(1, 0, 0.45, 0), C.good)
	refs.hpFill = hpFill

	-- Ammo (bottom-right)
	local ammo = UI.new("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -14, 1, -14),
		Size = UDim2.fromOffset(200, 60),
		BackgroundColor3 = C.bg,
		BackgroundTransparency = 0.25,
		Parent = gui,
	}, { UI.corner(10), UI.padding(8) })
	refs.weapon = UI.label({
		Text = "",
		Size = UDim2.new(1, 0, 0.38, 0),
		TextColor3 = C.dim,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = ammo,
	})
	refs.ammo = UI.label({
		Text = "",
		Size = UDim2.new(1, 0, 0.58, 0),
		Position = UDim2.fromScale(0, 0.42),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = ammo,
	})
	refs.ammoPanel = ammo

	-- Abilities (bottom-center)
	refs.Q = abilityBox(gui, "Q", -80)
	refs.F = abilityBox(gui, "F", 0)
	refs.E = abilityBox(gui, "E", 80)

	-- Notification feed (right side)
	feed = UI.new("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 70),
		Size = UDim2.fromOffset(360, 300),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		UI.new("UIListLayout", {
			VerticalAlignment = Enum.VerticalAlignment.Top,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	-- Hitmarker (4 ticks around the crosshair)
	local hm = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(28, 28),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	for _, rot in { 45, -45 } do
		UI.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(28, 3),
			Rotation = rot,
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			Parent = hm,
		})
	end
	refs.hitmarker = hm

	-- Downed overlay
	local downed = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.22, 0),
		Size = UDim2.fromOffset(420, 70),
		BackgroundColor3 = Color3.fromRGB(60, 0, 0),
		BackgroundTransparency = 0.2,
		Visible = false,
		Parent = gui,
	}, { UI.corner(10), UI.padding(8) })
	refs.downedText = UI.label({
		Text = "",
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Color3.fromRGB(255, 200, 200),
		Parent = downed,
	})
	refs.downed = downed

	-- Matchmaking indicator
	refs.mm = UI.label({
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 90),
		Size = UDim2.fromOffset(360, 24),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.gold,
		Visible = false,
		Parent = gui,
	})

	-- Hurt flash
	refs.hurt = UI.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(200, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 0,
		Parent = gui,
	})
end

local KIND_COLORS = {
	info = C.text,
	error = C.danger,
	levelup = C.gold,
	boss = Color3.fromRGB(255, 140, 60),
	story = Color3.fromRGB(255, 210, 120),
	super = C.accent,
	loot = Color3.fromRGB(190, 150, 255),
}

local order = 0
function HUD.Notify(text: string, kind: string?)
	order += 1
	local long = #text > 60
	local item = UI.new("Frame", {
		Size = UDim2.new(1, 0, 0, if long then 64 else 34),
		BackgroundColor3 = C.bg,
		BackgroundTransparency = 0.2,
		LayoutOrder = order,
		Parent = feed,
	}, { UI.corner(8), UI.padding(6) })
	UI.label({
		Text = text,
		Size = UDim2.fromScale(1, 1),
		TextColor3 = KIND_COLORS[kind or "info"] or C.text,
		TextWrapped = true,
		Parent = item,
	})
	local children = {}
	for _, c in feed:GetChildren() do
		if c:IsA("Frame") then
			table.insert(children, c)
		end
	end
	if #children > 5 then
		table.sort(children, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		children[1]:Destroy()
	end
	task.delay(if kind == "story" then 12 else 6, function()
		if item.Parent then
			item:Destroy()
		end
	end)
end

function HUD.Hitmarker(headshot: boolean)
	local hm = refs.hitmarker
	hm.Visible = true
	for _, line in hm:GetChildren() do
		if line:IsA("Frame") then
			line.BackgroundColor3 = if headshot then Color3.fromRGB(255, 210, 60) else Color3.new(1, 1, 1)
		end
	end
	local token = os.clock()
	refs.hitToken = token
	task.delay(0.12, function()
		if refs.hitToken == token then
			hm.Visible = false
		end
	end)
end

function HUD.AddButton(text: string, onClick: () -> ())
	UI.button(text, { Size = UDim2.fromOffset(92, 40), Parent = refs.buttons }, onClick)
end

local function update()
	local inMission = workspace:GetAttribute("Mode") == "Mission"
	refs.crosshair.Visible = inMission
	refs.ammoPanel.Visible = inMission

	-- Profile
	refs.level.Text = "LV " .. tostring(player:GetAttribute("Level") or 1)
	refs.power.Text = "⚡ " .. tostring(player:GetAttribute("Power") or 10)
	refs.shards.Text = "◆ " .. tostring(player:GetAttribute("Shards") or 0)
	local xp, xpNext = player:GetAttribute("XP") or 0, player:GetAttribute("XPNext") or 1
	refs.xpFill.Size = UDim2.fromScale(math.clamp(xp / xpNext, 0, 1), 1)

	-- Health
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		refs.hpFill.Size = UDim2.fromScale(math.clamp(hum.Health / hum.MaxHealth, 0, 1), 1)
		refs.hpFill.BackgroundColor3 = if hum.Health / hum.MaxHealth < 0.3 then C.danger else C.good
	end

	-- Weapon
	local reloading = player:GetAttribute("Reloading")
	local rarity = Loot.Rarities[player:GetAttribute("WeaponRarity") or "Common"]
	refs.weapon.TextColor3 = if rarity then rarity.color else C.dim
	refs.weapon.Text = (player:GetAttribute("WeaponName") or "")
		.. (if (player:GetAttribute("EmpoweredShots") or 0) > 0 then "  ✦ DEADEYE" else "")
	refs.ammo.Text = if reloading
		then "RELOADING"
		else ("%d / %d"):format(player:GetAttribute("Ammo") or 0, player:GetAttribute("MagSize") or 0)

	-- Downed
	local downedUntil = char and char:GetAttribute("Downed") and char:GetAttribute("DownedUntil")
	refs.downed.Visible = downedUntil ~= nil
	if downedUntil then
		refs.downedText.Text = ("DOWNED — a teammate can revive you (%ds)"):format(
			math.max(0, math.ceil(downedUntil - workspace:GetServerTimeNow()))
		)
	end

	-- Matchmaking
	local mm = player:GetAttribute("Matchmaking")
	refs.mm.Visible = mm ~= nil
	if mm then
		refs.mm.Text = "Searching for a fireteam" .. string.rep(".", math.floor(os.clock() * 2) % 4)
	end

	-- Abilities
	local classId = player:GetAttribute("ClassId")
	local class = classId and Classes.Defs[classId]
	refs.className.Text = if class then class.name .. "  ·  " .. class.role else "No class — open the Class Terminal"
	local now = workspace:GetServerTimeNow()
	for _, key in { "Q", "E" } do
		local box = refs[key]
		box.box.Visible = class ~= nil
		if class then
			local def = class.abilities[key]
			box.name.Text = def.name
			local remaining = (player:GetAttribute("Ready" .. key) or 0) - now
			if remaining > 0 then
				box.cover.Size = UDim2.fromScale(1, math.clamp(remaining / def.cooldown, 0, 1))
				box.timer.Text = tostring(math.ceil(remaining))
			else
				box.cover.Size = UDim2.fromScale(1, 0)
				box.timer.Text = ""
			end
		end
	end
	local f = refs.F
	f.box.Visible = class ~= nil
	if class then
		local charge = player:GetAttribute("SuperCharge") or 0
		f.name.Text = class.abilities.F.name
		f.cover.Size = UDim2.fromScale(1, 1 - charge / 100)
		f.timer.Text = if charge >= 100 then "READY" else tostring(math.floor(charge)) .. "%"
		f.box.UIStroke.Color = if charge >= 100 then C.gold else C.accent
	end
end

function HUD.Start()
	build()
	RunService.RenderStepped:Connect(update)

	Net.event("Notify").OnClientEvent:Connect(HUD.Notify)
	Net.event("Loot").OnClientEvent:Connect(function(item)
		local tag = if item.pinnacle then "PINNACLE " else ""
		HUD.Notify(
			("%s%s %s  ⚡%d  %s"):format(
				tag,
				item.rarity,
				item.weaponName,
				item.power,
				if item.equipped then "(equipped)" else "(in inventory)"
			),
			"loot"
		)
	end)
	Net.event("ObjectiveUpdate").OnClientEvent:Connect(function(data)
		if not data then
			refs.objective.Visible = false
			return
		end
		refs.objective.Visible = true
		refs.objMission.Text = ("%s  ·  %d/%d"):format(data.mission, data.step or 1, data.steps or 1)
		refs.objText.Text = data.text
		refs.objBar.Visible = data.progress ~= nil
		if data.progress then
			refs.objFill.Size = UDim2.fromScale(math.clamp(data.progress, 0, 1), 1)
		end
	end)
	Effects.OnHurt(function()
		refs.hurt.BackgroundTransparency = 0.75
		TweenService:Create(refs.hurt, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
	end)
end

return HUD
