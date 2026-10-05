--!strict
-- Monta o cajado do mago por codigo (sem assets): haste de madeira, empunhadura de couro,
-- garras douradas e gema Neon com o anexo "Muzzle" (de onde saem as magias).
-- O cajado e construido "deitado" no eixo X da haste; o StaffService o prende na mao.

local StaffBuilder = {}

local SHAFT_LENGTH = 5.4
local WOOD = Color3.fromRGB(86, 58, 40)
local LEATHER = Color3.fromRGB(58, 36, 30)
local GOLD = Color3.fromRGB(214, 170, 76)

local function piece(
	model: Model,
	name: string,
	shape: Enum.PartType,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

-- Retorna o Model do cajado (PrimaryPart = Shaft) com a gema na cor inicial.
function StaffBuilder.build(gemColor: Color3): Model
	local model = Instance.new("Model")
	model.Name = "ArcanumStaff"

	-- Haste: cilindro ao longo do X local. Topo em +X.
	local shaft = piece(
		model,
		"Shaft",
		Enum.PartType.Cylinder,
		Vector3.new(SHAFT_LENGTH, 0.26, 0.26),
		CFrame.identity,
		WOOD,
		Enum.Material.Wood
	)
	model.PrimaryPart = shaft
	local top = SHAFT_LENGTH / 2

	-- Empunhadura e aneis
	piece(
		model,
		"Grip",
		Enum.PartType.Cylinder,
		Vector3.new(1.1, 0.32, 0.32),
		CFrame.new(-0.4, 0, 0),
		LEATHER,
		Enum.Material.Fabric
	)
	for i, x in { top - 0.35, -top + 0.2 } do
		piece(
			model,
			"Band" .. i,
			Enum.PartType.Cylinder,
			Vector3.new(0.14, 0.36, 0.36),
			CFrame.new(x, 0, 0),
			GOLD,
			Enum.Material.Metal
		)
	end

	-- Garras: 4 hastes curvas (2 segmentos cada) que saem do topo e abraçam a gema.
	local gemCenter = top + 0.75
	local function segment(name: string, from: Vector3, to: Vector3, thickness: number)
		local length = (to - from).Magnitude
		piece(
			model,
			name,
			Enum.PartType.Block,
			Vector3.new(thickness, thickness, length),
			CFrame.lookAt((from + to) / 2, to),
			GOLD,
			Enum.Material.Metal
		)
	end
	for i = 0, 3 do
		local angle = i * math.pi / 2 + math.pi / 4
		local radial = Vector3.new(0, math.cos(angle), math.sin(angle))
		local base = Vector3.new(top - 0.05, 0, 0) + radial * 0.1
		local elbow = Vector3.new(gemCenter - 0.15, 0, 0) + radial * 0.5
		local tip = Vector3.new(gemCenter + 0.5, 0, 0) + radial * 0.18
		segment("Claw" .. i .. "A", base, elbow, 0.1)
		segment("Claw" .. i .. "B", elbow, tip, 0.08)
	end

	-- Gema: nucleo Neon + casca translucida.
	local gem = piece(
		model,
		"Gem",
		Enum.PartType.Ball,
		Vector3.one * 0.62,
		CFrame.new(gemCenter, 0, 0),
		gemColor,
		Enum.Material.Neon
	)
	local shell =
		piece(model, "GemShell", Enum.PartType.Ball, Vector3.one * 0.85, gem.CFrame, gemColor, Enum.Material.Glass)
	shell.Transparency = 0.55

	local muzzle = Instance.new("Attachment")
	muzzle.Name = "Muzzle"
	muzzle.Parent = gem

	local light = Instance.new("PointLight")
	light.Name = "GemLight"
	light.Color = gemColor
	light.Range = 7
	light.Brightness = 1.2
	light.Parent = gem

	local glow = Instance.new("ParticleEmitter")
	glow.Name = "GemGlow"
	glow.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	glow.Color = ColorSequence.new(gemColor)
	glow.LightEmission = 1
	glow.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
	glow.Transparency = NumberSequence.new(0.2, 1)
	glow.Lifetime = NumberRange.new(0.4, 0.8)
	glow.Rate = 6
	glow.Speed = NumberRange.new(0.5, 1.5)
	glow.SpreadAngle = Vector2.new(180, 180)
	glow.Parent = muzzle

	-- Tudo preso a haste (posicoes relativas ja definidas acima).
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and child ~= shaft then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = shaft
			weld.Part1 = child
			weld.Parent = child
		end
	end
	return model
end

return StaffBuilder
