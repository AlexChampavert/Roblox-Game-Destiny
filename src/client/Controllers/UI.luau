-- Small helpers to build UI from code (swap for a UI framework later if you want).

local UI = {}

UI.Colors = {
	bg = Color3.fromRGB(12, 16, 28),
	panel = Color3.fromRGB(20, 26, 42),
	accent = Color3.fromRGB(60, 200, 255),
	gold = Color3.fromRGB(255, 200, 90),
	text = Color3.fromRGB(235, 240, 250),
	dim = Color3.fromRGB(140, 150, 170),
	danger = Color3.fromRGB(255, 80, 80),
	good = Color3.fromRGB(90, 230, 130),
}

function UI.new(className: string, props: { [string]: any }, children: { Instance }?): any
	local inst = Instance.new(className)
	for k, v in props do
		if k ~= "Parent" then
			(inst :: any)[k] = v
		end
	end
	local list: { Instance } = children or {}
	for _, child in list do
		child.Parent = inst
	end
	if props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

function UI.corner(radius: number?): UICorner
	return UI.new("UICorner", { CornerRadius = UDim.new(0, radius or 8) })
end

function UI.stroke(color: Color3?, thickness: number?): UIStroke
	return UI.new("UIStroke", { Color = color or UI.Colors.accent, Thickness = thickness or 1, Transparency = 0.4 })
end

function UI.padding(px: number): UIPadding
	local u = UDim.new(0, px)
	return UI.new("UIPadding", { PaddingTop = u, PaddingBottom = u, PaddingLeft = u, PaddingRight = u })
end

function UI.label(props: { [string]: any }): TextLabel
	local defaults = {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextColor3 = UI.Colors.text,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}
	for k, v in props do
		defaults[k] = v
	end
	return UI.new("TextLabel", defaults)
end

function UI.button(text: string, props: { [string]: any }, onClick: () -> ()): TextButton
	local defaults = {
		Text = text,
		BackgroundColor3 = UI.Colors.panel,
		TextColor3 = UI.Colors.text,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		AutoButtonColor = true,
	}
	for k, v in props do
		defaults[k] = v
	end
	local b = UI.new("TextButton", defaults, { UI.corner(8), UI.stroke(), UI.padding(6) })
	b.Activated:Connect(onClick)
	return b
end

return UI
