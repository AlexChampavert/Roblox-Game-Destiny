-- Menus: class picker, mission table, fireteam, SOL story panel, lore.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Config = Shared:WaitForChild("Config")
local Classes = require(Config:WaitForChild("Classes"))
local Missions = require(Config:WaitForChild("Missions"))
local Weapons = require(Config:WaitForChild("Weapons"))
local Loot = require(Config:WaitForChild("Loot"))
local Progression = require(Config:WaitForChild("Progression"))

local UI = require(script.Parent.UI)

local Menus = {}

local player = Players.LocalPlayer
local C = UI.Colors

local gui: ScreenGui
local window: Frame
local title: TextLabel
local content: ScrollingFrame
local openName: string? = nil
local inviteFrame: Frame

function Menus.IsOpen(): boolean
	return openName ~= nil
end

function Menus.Close()
	openName = nil
	window.Visible = false
end

local function clear()
	for _, c in content:GetChildren() do
		if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then
			c:Destroy()
		end
	end
end

local function card(height: number): Frame
	return UI.new("Frame", { Size = UDim2.new(1, -8, 0, height), BackgroundColor3 = C.panel, Parent = content }, { UI.corner(10), UI.padding(10), UI.stroke(C.accent, 1) })
end

-- ===== Pages =====

local Pages = {}

function Pages.Classes(state)
	title.Text = "CHOOSE YOUR CLASS"
	for _, id in Classes.Order do
		local class = Classes.Defs[id]
		local selected = state and state.classId == id
		local c = card(150)
		c.UIStroke.Color = class.color
		c.UIStroke.Transparency = if selected then 0 else 0.5
		UI.label({ Text = class.name:upper() .. (if selected then "  ✓" else ""), Size = UDim2.new(0.6, 0, 0, 26), TextColor3 = class.color, Parent = c })
		UI.label({ Text = ("%s  ·  HP %d  ·  Speed %d"):format(class.role, class.maxHealth, class.walkSpeed), Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 28), TextColor3 = C.dim, Parent = c })
		local lines = {
			("Passive — %s: %s"):format(class.passive.name, class.passive.description),
			("Q — %s: %s"):format(class.abilities.Q.name, class.abilities.Q.description),
			("E — %s: %s"):format(class.abilities.E.name, class.abilities.E.description),
			("F (Super) — %s: %s"):format(class.abilities.F.name, class.abilities.F.description),
			("Weapons — %s + %s"):format(Weapons[class.startingWeapons.primary].name, Weapons[class.startingWeapons.secondary].name),
		}
		for i, line in lines do
			UI.label({ Text = line, Size = UDim2.new(0.75, 0, 0, 15), Position = UDim2.fromOffset(0, 32 + i * 18), Font = Enum.Font.Gotham, TextColor3 = C.text, Parent = c })
		end
		if not selected then
			UI.button("SELECT", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(110, 44), BackgroundColor3 = class.color, TextColor3 = Color3.new(0, 0, 0), Parent = c }, function()
				Net.event("SelectClass"):FireServer(id)
				Menus.Close()
			end)
		end
	end
end

function Pages.Missions(state)
	title.Text = "MISSION TABLE"
	if state and state.chapter then
		local c = card(54)
		UI.label({ Text = ("%s — Week %d: %s"):format(state.chapter.season, state.chapter.week, state.chapter.title), Size = UDim2.new(1, 0, 0, 18), TextColor3 = C.gold, Parent = c })
		local featured = state.chapter.featuredMission and Missions.Defs[state.chapter.featuredMission]
		UI.label({ Text = if featured then ("Featured: %s (double XP)%s"):format(featured.name, if state.chapter.modifier then " · Modifier: " .. state.chapter.modifier else "") else "", Size = UDim2.new(1, 0, 0, 15), Position = UDim2.fromOffset(0, 22), Font = Enum.Font.Gotham, TextColor3 = C.dim, Parent = c })
	end
	local isLeader = not state or not state.fireteam.inTeam or state.fireteam.leaderId == player.UserId
	for _, m in (state and state.missions) or {} do
		local def = Missions.Defs[m.id]
		local c = card(112)
		UI.label({ Text = ("%d. %s"):format(def.order, def.name:upper()), Size = UDim2.new(0.7, 0, 0, 24), TextColor3 = if m.lockReason then C.dim else C.accent, Parent = c })
		UI.label({ Text = ("%s  ·  Power %d  ·  Lv %d+"):format(def.location, def.recommendedPower, def.requiredLevel), Size = UDim2.new(0.72, 0, 0, 15), Position = UDim2.fromOffset(0, 28), Font = Enum.Font.Gotham, TextColor3 = C.dim, Parent = c })
		local steps = {}
		for _, s in def.steps do
			table.insert(steps, s.text)
		end
		UI.label({ Text = table.concat(steps, " → "), Size = UDim2.new(0.72, 0, 0, 30), Position = UDim2.fromOffset(0, 48), Font = Enum.Font.Gotham, TextWrapped = true, TextColor3 = C.text, Parent = c })
		UI.label({ Text = if m.completed > 0 then ("Cleared %dx"):format(m.completed) else "Not cleared yet", Size = UDim2.new(0.5, 0, 0, 14), Position = UDim2.fromOffset(0, 82), Font = Enum.Font.Gotham, TextColor3 = if m.completed > 0 then C.good else C.dim, Parent = c })
		if m.lockReason then
			UI.label({ Text = "🔒 " .. m.lockReason, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(150, 36), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = C.danger, Parent = c })
		elseif isLeader then
			UI.button("LAUNCH", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 4), Size = UDim2.fromOffset(130, 40), BackgroundColor3 = C.accent, TextColor3 = Color3.new(0, 0, 0), Parent = c }, function()
				Net.event("LaunchMission"):FireServer(m.id)
				Menus.Close()
			end)
			if not state.fireteam.inTeam then
				UI.button("FIND FIRETEAM", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 50), Size = UDim2.fromOffset(130, 36), BackgroundColor3 = C.gold, TextColor3 = Color3.new(0, 0, 0), Parent = c }, function()
					Net.event("Matchmaking"):FireServer("Join", m.id)
					Menus.Close()
				end)
			end
		else
			UI.label({ Text = "Leader launches", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(140, 30), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = C.dim, Parent = c })
		end
	end
end

function Pages.Fireteam(state)
	title.Text = "FIRETEAM"
	if not state then
		return
	end
	local team = state.fireteam
	local c = card(40 + 34 * math.max(#(team.members or {}), 1))
	UI.label({ Text = if team.inTeam then ("Your fireteam (%d/%d)"):format(#team.members, state.maxFireteam) else "You're solo. Invite players below.", Size = UDim2.new(1, 0, 0, 20), TextColor3 = C.gold, Parent = c })
	for i, m in team.members or {} do
		local leader = m.userId == team.leaderId
		UI.label({ Text = ("%s%s  ·  %s  ·  Lv %d  ·  ⚡%d"):format(if leader then "★ " else "", m.name, m.classId or "?", m.level, m.power), Size = UDim2.new(0.75, 0, 0, 22), Position = UDim2.fromOffset(0, 4 + i * 30), Font = Enum.Font.Gotham, Parent = c })
		if team.leaderId == player.UserId and m.userId ~= player.UserId then
			UI.button("Kick", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 2 + i * 30), Size = UDim2.fromOffset(60, 26), Parent = c }, function()
				Net.event("FireteamAction"):FireServer("Kick", m.userId)
				task.wait(0.3)
				Menus.Open("Fireteam")
			end)
		end
	end
	if team.inTeam then
		UI.button("Leave fireteam", { Size = UDim2.new(1, -8, 0, 40), BackgroundColor3 = Color3.fromRGB(80, 30, 30), Parent = content }, function()
			Net.event("FireteamAction"):FireServer("Leave")
			task.wait(0.3)
			Menus.Open("Fireteam")
		end)
	end

	if state.matchmaking then
		local mm = Missions.Defs[state.matchmaking]
		UI.button(("Cancel search (%s)"):format(mm and mm.name or "?"), { Size = UDim2.new(1, -8, 0, 40), BackgroundColor3 = Color3.fromRGB(90, 70, 20), Parent = content }, function()
			Net.event("Matchmaking"):FireServer("Cancel")
			task.wait(0.3)
			Menus.Open("Fireteam")
		end)
	end
	UI.label({ Text = "PLAYERS ON THIS SHIP", Size = UDim2.new(1, -8, 0, 22), TextColor3 = C.accent, Parent = content })
	if #state.players == 0 then
		UI.label({ Text = "Nobody else here yet.", Size = UDim2.new(1, -8, 0, 18), Font = Enum.Font.Gotham, TextColor3 = C.dim, Parent = content })
	end
	for _, p in state.players do
		local row = card(46)
		UI.label({ Text = ("%s  ·  %s  ·  Lv %d"):format(p.name, p.classId or "no class", p.level), Size = UDim2.new(0.7, 0, 1, 0), Font = Enum.Font.Gotham, Parent = row })
		UI.button("Invite", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(80, 30), Parent = row }, function()
			Net.event("FireteamAction"):FireServer("Invite", p.userId)
		end)
	end
end

function Pages.Story(state)
	title.Text = "SOL"
	if not state then
		return
	end
	local ch = state.chapter
	local c = card(200)
	UI.label({ Text = ch.season, Size = UDim2.new(1, 0, 0, 20), TextColor3 = C.gold, Parent = c })
	UI.label({ Text = ("Week %d — %s"):format(ch.week, ch.title), Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 24), TextColor3 = C.accent, Parent = c })
	UI.label({ Text = "\"" .. ch.message .. "\"", Size = UDim2.new(1, 0, 0, 110), Position = UDim2.fromOffset(0, 56), Font = Enum.Font.GothamMedium, TextScaled = false, TextSize = 18, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Parent = c })
	local s = state.stats
	local statsCard = card(40)
	UI.label({ Text = ("Kills %d  ·  Missions %d  ·  Deaths %d"):format(s.kills, s.missions, s.deaths), Size = UDim2.fromScale(1, 1), Font = Enum.Font.Gotham, TextColor3 = C.dim, Parent = statsCard })
end

-- A class's own hall on the Meridian
function Pages.ClassHall(state, classId: string?)
	local class = classId and Classes.Defs[classId]
	if not class then
		return
	end
	local hall = class.hall
	local isMember = state and state.classId == class.id
	title.Text = hall.name:upper()

	local c = card(170)
	c.UIStroke.Color = class.color
	UI.label({ Text = ("%s Order  ·  %s"):format(class.name, class.role), Size = UDim2.new(1, 0, 0, 22), TextColor3 = class.color, Parent = c })
	UI.label({ Text = hall.lore, Size = UDim2.new(1, 0, 0, 60), Position = UDim2.fromOffset(0, 30), Font = Enum.Font.GothamMedium, TextScaled = false, TextSize = 17, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Parent = c })
	local classLevelXp = (state and state.classXp and state.classXp[class.id]) or 0
	UI.label({ Text = if isMember then ("You are a member of this order  ·  Order XP %d"):format(classLevelXp) else "You are not a member of this order.", Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 100), Font = Enum.Font.Gotham, TextColor3 = if isMember then C.good else C.dim, Parent = c })
	if not isMember then
		UI.button(("JOIN THE %s ORDER"):format(class.name:upper()), { Position = UDim2.fromOffset(0, 124), Size = UDim2.new(0.6, 0, 0, 34), BackgroundColor3 = class.color, TextColor3 = Color3.new(0, 0, 0), Parent = c }, function()
			Net.event("SelectClass"):FireServer(class.id)
			Menus.Close()
		end)
	end

	local a = card(110)
	UI.label({ Text = "ABILITIES", Size = UDim2.new(1, 0, 0, 18), TextColor3 = C.accent, Parent = a })
	for i, key in { "Q", "E", "F" } do
		local def = class.abilities[key]
		UI.label({ Text = ("%s — %s: %s"):format(if key == "F" then "Super" else key, def.name, def.description), Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 4 + i * 22), Font = Enum.Font.Gotham, Parent = a })
	end

	-- Order Rank
	local rank = Progression.orderRank(classLevelXp)
	local nextXp = Progression.xpForOrderRank(math.min(rank + 1, Progression.MaxOrderRank))
	local r = card(40 + 22 * #Progression.OrderUpgrades)
	UI.label({ Text = ("ORDER RANK %d / %d   ·   %d / %d XP"):format(rank, Progression.MaxOrderRank, classLevelXp, nextXp), Size = UDim2.new(1, 0, 0, 20), TextColor3 = C.gold, Parent = r })
	for i, up in Progression.OrderUpgrades do
		local unlocked = rank >= up.rank
		UI.label({ Text = ("%s Rank %d — %s"):format(if unlocked then "✓" else "🔒", up.rank, up.text), Size = UDim2.new(1, 0, 0, 17), Position = UDim2.fromOffset(0, 4 + i * 22), Font = Enum.Font.Gotham, TextColor3 = if unlocked then C.good else C.dim, Parent = r })
	end

	-- Order vendor
	local v = card(120)
	UI.label({ Text = ("ORDER VENDOR   ·   You have ◆ %d Shards"):format(state and state.shards or 0), Size = UDim2.new(1, 0, 0, 20), TextColor3 = Color3.fromRGB(190, 150, 255), Parent = v })
	if isMember then
		UI.button(("Order Engram (random gear) — ◆ %d"):format(Loot.Vendor.EngramCost), { Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 34), Parent = v }, function()
			Net.event("Vendor"):FireServer("BuyEngram")
			task.wait(0.4)
			Menus.Open("ClassHall", class.id)
		end)
		local owned = state and state.cosmetics and state.cosmetics.orderArmor[class.id]
		if owned then
			UI.label({ Text = "✓ Order armor owned", Position = UDim2.fromOffset(0, 72), Size = UDim2.new(1, 0, 0, 22), TextColor3 = C.good, Parent = v })
		else
			UI.button(("%s Order Armor (cosmetic) — ◆ %d"):format(class.name, Loot.Vendor.ArmorStyleCost), { Position = UDim2.fromOffset(0, 72), Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = class.color, TextColor3 = Color3.new(0, 0, 0), Parent = v }, function()
				Net.event("Vendor"):FireServer("BuyArmorStyle")
				task.wait(0.4)
				Menus.Open("ClassHall", class.id)
			end)
		end
	else
		UI.label({ Text = "Only members of this order can trade here.", Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 20), Font = Enum.Font.Gotham, TextColor3 = C.dim, Parent = v })
	end
end

local function itemName(item): string
	if item.slot == "armor" then
		return "Armor"
	end
	local w = item.weaponId and Weapons[item.weaponId]
	return if w then w.name else "Class weapon"
end

local function itemCard(item, equipped: boolean)
	local rarity = Loot.Rarities[item.rarity or "Common"] or Loot.Rarities.Common
	local perkNames = {}
	for _, perkId in item.perks or {} do
		local perk = Loot.Perks[perkId] or Loot.ExoticPerks[perkId]
		if perk then
			table.insert(perkNames, perk.name)
		end
	end
	local c = card(if #perkNames > 0 then 76 else 56)
	c.UIStroke.Color = rarity.color
	UI.label({ Text = ("%s %s   ⚡%d"):format(rarity.name, itemName(item), item.power), Size = UDim2.new(0.62, 0, 0, 22), TextColor3 = rarity.color, Parent = c })
	UI.label({ Text = item.slot:upper() .. (if equipped then "  ·  EQUIPPED" else ""), Size = UDim2.new(0.62, 0, 0, 14), Position = UDim2.fromOffset(0, 26), Font = Enum.Font.Gotham, TextColor3 = C.dim, Parent = c })
	if #perkNames > 0 then
		UI.label({ Text = "Perks: " .. table.concat(perkNames, ", "), Size = UDim2.new(0.62, 0, 0, 14), Position = UDim2.fromOffset(0, 46), Font = Enum.Font.Gotham, Parent = c })
	end
	if not equipped then
		UI.button("Equip", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -96, 0, 6), Size = UDim2.fromOffset(84, 32), BackgroundColor3 = C.accent, TextColor3 = Color3.new(0, 0, 0), Parent = c }, function()
			Net.event("Inventory"):FireServer("Equip", item.uid)
			task.wait(0.3)
			Menus.Open("Inventory")
		end)
		UI.button(("◆ %d"):format(rarity.dismantle), { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 6), Size = UDim2.fromOffset(84, 32), BackgroundColor3 = Color3.fromRGB(80, 30, 30), Parent = c }, function()
			Net.event("Inventory"):FireServer("Dismantle", item.uid)
			task.wait(0.3)
			Menus.Open("Inventory")
		end)
	end
end

function Pages.Inventory(state)
	title.Text = "GEAR"
	if not state then
		return
	end
	UI.label({ Text = ("EQUIPPED   ·   Power ⚡%d"):format(state.power), Size = UDim2.new(1, -8, 0, 22), TextColor3 = C.accent, Parent = content })
	for _, slot in { "primary", "secondary", "armor" } do
		itemCard(state.gear[slot], true)
	end
	UI.label({ Text = ("INVENTORY (%d / %d)   ·   ◆ dismantles for Shards"):format(#state.inventory, Loot.InventoryCap), Size = UDim2.new(1, -8, 0, 22), TextColor3 = C.accent, Parent = content })
	local items = table.clone(state.inventory)
	table.sort(items, function(a, b)
		return a.power > b.power
	end)
	for _, item in items do
		itemCard(item, false)
	end
end

function Pages.Bounties(state)
	title.Text = "BOUNTIES"
	if not state then
		return
	end
	local currentPeriod = nil
	for _, b in state.bounties do
		if b.period ~= currentPeriod then
			currentPeriod = b.period
			UI.label({ Text = if b.period == "daily" then "DAILY (resets 00:00 UTC)" else "WEEKLY (resets Monday)", Size = UDim2.new(1, -8, 0, 22), TextColor3 = C.accent, Parent = content })
		end
		local c = card(58)
		UI.label({ Text = (if b.done then "✓ " else "") .. b.text, Size = UDim2.new(0.7, 0, 0, 20), TextColor3 = if b.done then C.good else C.text, Parent = c })
		UI.label({ Text = ("+%d XP  ·  ◆ %d"):format(b.xp, b.shards), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0.3, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Right, Font = Enum.Font.Gotham, TextColor3 = C.gold, Parent = c })
		local back = UI.new("Frame", { Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 0, 10), BackgroundColor3 = Color3.fromRGB(25, 28, 38), BorderSizePixel = 0, Parent = c }, { UI.corner(4) })
		UI.new("Frame", { Size = UDim2.fromScale(math.clamp(b.progress / b.target, 0, 1), 1), BackgroundColor3 = if b.done then C.good else C.gold, BorderSizePixel = 0, Parent = back }, { UI.corner(4) })
	end
end

function Pages.Lore()
	title.Text = "LORE CACHE"
	local c = card(200)
	UI.label({
		Text = "PROJECT STARFALL — Log 001\n\n\"The fragments respond to human will. Subjects show regeneration, kinetic projection, spatial displacement. Recommend the Warden program proceed.\n\nSide effect observed: fragments left unbonded begin to... grow. Network. Hollow out their containment.\n\nSOL is to keep this log sealed.\"",
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.GothamMedium,
		TextScaled = false,
		TextSize = 17,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = c,
	})
end

function Menus.Open(name: string, arg: any?)
	local page = Pages[name]
	if not page then
		return
	end
	openName = name
	window.Visible = true
	clear()
	title.Text = "..."
	local state = nil
	if name ~= "Lore" then
		local ok, result = pcall(function()
			return Net.func("GetState"):InvokeServer()
		end)
		state = if ok then result else nil
	end
	if openName ~= name then
		return
	end
	clear()
	page(state, arg)
	-- Keep visual order = creation order
	for i, c in content:GetChildren() do
		if c:IsA("GuiObject") then
			c.LayoutOrder = i
		end
	end
end

local function showInvite(invite)
	for _, c in inviteFrame:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	inviteFrame.Visible = true
	UI.label({ Text = invite.fromName .. " invited you to their fireteam", Size = UDim2.new(1, 0, 0.5, 0), TextWrapped = true, Parent = inviteFrame })
	UI.button("Accept", { Position = UDim2.fromScale(0, 0.58), Size = UDim2.fromScale(0.48, 0.4), BackgroundColor3 = C.good, TextColor3 = Color3.new(0, 0, 0), Parent = inviteFrame }, function()
		Net.event("FireteamAction"):FireServer("Accept", invite.teamId)
		inviteFrame.Visible = false
	end)
	UI.button("Decline", { Position = UDim2.fromScale(0.52, 0.58), Size = UDim2.fromScale(0.48, 0.4), Parent = inviteFrame }, function()
		Net.event("FireteamAction"):FireServer("Decline", invite.teamId)
		inviteFrame.Visible = false
	end)
	task.delay(30, function()
		inviteFrame.Visible = false
	end)
end

function Menus.Start()
	gui = UI.new("ScreenGui", { Name = "Menus", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 10, Parent = player:WaitForChild("PlayerGui") })
	window = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.9, 0, 0.82, 0),
		BackgroundColor3 = C.bg,
		BackgroundTransparency = 0.05,
		Visible = false,
		Parent = gui,
	}, { UI.corner(14), UI.stroke(C.accent, 2), UI.new("UISizeConstraint", { MaxSize = Vector2.new(760, 640) }) })
	title = UI.label({ Text = "", Position = UDim2.fromOffset(18, 12), Size = UDim2.new(1, -90, 0, 32), TextColor3 = C.accent, Font = Enum.Font.GothamBlack, Parent = window })
	UI.button("✕", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 10), Size = UDim2.fromOffset(40, 40), Parent = window }, Menus.Close)
	content = UI.new("ScrollingFrame", {
		Position = UDim2.fromOffset(12, 56),
		Size = UDim2.new(1, -24, 1, -68),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = window,
	}, { UI.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }), UI.padding(4) })

	inviteFrame = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 100), Size = UDim2.fromOffset(340, 100), BackgroundColor3 = C.bg, Visible = false, Parent = gui }, { UI.corner(10), UI.stroke(C.gold, 2), UI.padding(10) })

	Net.event("OpenMenu").OnClientEvent:Connect(Menus.Open)
	Net.event("FireteamUpdate").OnClientEvent:Connect(function(data)
		if data.invite then
			showInvite(data.invite)
		elseif openName == "Fireteam" then
			Menus.Open("Fireteam")
		end
	end)
end

return Menus
