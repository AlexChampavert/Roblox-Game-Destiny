-- Tiny helper for building blockout geometry from code.

local Build = {}

export type PartProps = {
	name: string?,
	size: Vector3,
	cframe: CFrame?,
	position: Vector3?,
	color: Color3?,
	material: Enum.Material?,
	transparency: number?,
	shape: Enum.PartType?,
	collide: boolean?,
	parent: Instance,
	wedge: boolean?,
	light: { color: Color3, range: number, brightness: number }?,
}

function Build.part(props: PartProps): BasePart
	local p: BasePart
	if props.wedge then
		p = Instance.new("WedgePart")
	else
		local part = Instance.new("Part")
		part.Shape = props.shape or Enum.PartType.Block
		p = part
	end
	p.Name = props.name or "Part"
	p.Size = props.size
	if props.cframe then
		p.CFrame = props.cframe
	elseif props.position then
		p.Position = props.position
	end
	p.Color = props.color or Color3.fromRGB(200, 200, 200)
	p.Material = props.material or Enum.Material.SmoothPlastic
	p.Transparency = props.transparency or 0
	p.Anchored = true
	p.CanCollide = if props.collide == nil then true else props.collide
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props.light then
		local l = Instance.new("PointLight")
		l.Color = props.light.color
		l.Range = props.light.range
		l.Brightness = props.light.brightness
		l.Parent = p
	end
	p.Parent = props.parent
	return p
end

function Build.model(name: string, parent: Instance): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

-- A text sign (SurfaceGui on the front face)
function Build.sign(part: BasePart, text: string, color: Color3?): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = color or Color3.fromRGB(180, 240, 255)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextWrapped = true
	label.Text = text
	label.Parent = gui
	return label
end

return Build
