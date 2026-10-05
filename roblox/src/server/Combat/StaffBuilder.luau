--!strict
-- Cajados montados por codigo (sem assets), com estilo por escola:
--   haste afunilada com entalhe em espiral, empunhadura de couro com aneis, ponteira,
--   meia-lua que abraca a gema, gema em tres camadas (nucleo branco, cristal Neon, casca de vidro)
--   e tres fragmentos flutuantes (Welds "ShardN" que o cliente faz orbitar).
-- Construido deitado no eixo X local da haste (topo em +X); o StaffService o poe em pe.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StaffPose = require(ReplicatedStorage.Shared.StaffPose)

export type Style = {
	Wood: Color3,
	WoodMaterial: Enum.Material,
	Metal: Color3,
	Wrap: Color3,
}

local STYLES: { [string]: Style } = {
	Default = {
		Wood = Color3.fromRGB(92, 62, 42),
		WoodMaterial = Enum.Material.Wood,
		Metal = Color3.fromRGB(214, 170, 76),
		Wrap = Color3.fromRGB(70, 40, 34),
	},
	Electricity = {
		Wood = Color3.fromRGB(60, 66, 84),
		WoodMaterial = Enum.Material.Slate,
		Metal = Color3.fromRGB(190, 200, 215),
		Wrap = Color3.fromRGB(32, 48, 80),
	},
	Fire = {
		Wood = Color3.fromRGB(40, 32, 34),
		WoodMaterial = Enum.Material.Basalt,
		Metal = Color3.fromRGB(205, 120, 50),
		Wrap = Color3.fromRGB(90, 30, 20),
	},
	Energy = {
		Wood = Color3.fromRGB(92, 62, 42),
		WoodMaterial = Enum.Material.Wood,
		Metal = Color3.fromRGB(214, 170, 76),
		Wrap = Color3.fromRGB(60, 36, 90),
	},
	Necromancy = {
		Wood = Color3.fromRGB(214, 206, 180),
		WoodMaterial = Enum.Material.Limestone,
		Metal = Color3.fromRGB(80, 96, 88),
		Wrap = Color3.fromRGB(30, 40, 34),
	},
	Blood = {
		Wood = Color3.fromRGB(58, 26, 30),
		WoodMaterial = Enum.Material.Wood,
		Metal = Color3.fromRGB(170, 160, 165),
		Wrap = Color3.fromRGB(110, 14, 30),
	},
}

local StaffBuilder = {}

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

local function segment(
	model: Model,
	name: string,
	from: Vector3,
	to: Vector3,
	thickness: number,
	color: Color3,
	material: Enum.Material
)
	local length = (to - from).Magnitude
	piece(
		model,
		name,
		Enum.PartType.Block,
		Vector3.new(thickness, thickness, length + thickness * 0.5),
		CFrame.lookAt((from + to) / 2, to),
		color,
		material
	)
end

function StaffBuilder.build(school: string?, gemColor: Color3): Model
	local style = STYLES[school or "Default"] or STYLES.Default
	local model = Instance.new("Model")
	model.Name = "ArcanumStaff"

	local length = StaffPose.SHAFT_LENGTH
	local top = length / 2
	local gemX = StaffPose.GEM_DISTANCE

	-- Raiz invisivel no centro do cajado: e ela que o StaffService prende ao corpo.
	local root = piece(
		model,
		"Root",
		Enum.PartType.Block,
		Vector3.one * 0.1,
		CFrame.identity,
		style.Wood,
		Enum.Material.SmoothPlastic
	)
	root.Transparency = 1
	model.PrimaryPart = root

	-- Haste: parte superior mais grossa, inferior afunilada.
	piece(
		model,
		"Shaft",
		Enum.PartType.Cylinder,
		Vector3.new(length * 0.55, 0.28, 0.28),
		CFrame.new(top - length * 0.275, 0, 0),
		style.Wood,
		style.WoodMaterial
	)
	piece(
		model,
		"ShaftLower",
		Enum.PartType.Cylinder,
		Vector3.new(length * 0.47, 0.22, 0.22),
		CFrame.new(-top + length * 0.235, 0, 0),
		style.Wood,
		style.WoodMaterial
	)

	-- Entalhe em espiral (metal) na metade de cima.
	local turns, steps = 2.5, 18
	for i = 0, steps - 1 do
		local t0, t1 = i / steps, (i + 1) / steps
		local function at(t: number): Vector3
			local angle = t * turns * math.pi * 2
			return Vector3.new(top - 0.2 - t * length * 0.45, math.cos(angle) * 0.15, math.sin(angle) * 0.15)
		end
		segment(model, "Inlay" .. i, at(t0), at(t1), 0.05, style.Metal, Enum.Material.Metal)
	end

	-- Empunhadura de couro com aneis.
	local grip = StaffPose.GRIP_DISTANCE
	piece(
		model,
		"Wrap",
		Enum.PartType.Cylinder,
		Vector3.new(1.0, 0.3, 0.3),
		CFrame.new(grip, 0, 0),
		style.Wrap,
		Enum.Material.Fabric
	)
	for i, x in { grip - 0.55, grip + 0.55, top - 0.1 } do
		piece(
			model,
			"Ring" .. i,
			Enum.PartType.Cylinder,
			Vector3.new(0.1, 0.34, 0.34),
			CFrame.new(x, 0, 0),
			style.Metal,
			Enum.Material.Metal
		)
	end

	-- Ponteira.
	piece(
		model,
		"Pommel",
		Enum.PartType.Ball,
		Vector3.one * 0.32,
		CFrame.new(-top, 0, 0),
		style.Metal,
		Enum.Material.Metal
	)

	-- Meia-lua: arco de segmentos no plano X/Y abracando a gema, aberto para cima.
	local arcRadius, arcSteps = 0.62, 9
	local function arcPoint(i: number): Vector3
		local angle = math.rad(-150 + 300 * i / arcSteps) -- de -150 a +150 graus, aberto no topo
		return Vector3.new(gemX - math.cos(angle) * arcRadius, math.sin(angle) * arcRadius, 0)
	end
	for i = 0, arcSteps - 1 do
		segment(model, "Crescent" .. i, arcPoint(i), arcPoint(i + 1), 0.09, style.Metal, Enum.Material.Metal)
	end
	segment(model, "Neck", Vector3.new(top, 0, 0), arcPoint(arcSteps / 2), 0.12, style.Metal, Enum.Material.Metal)
	for i, side in { 1, -1 } do
		piece(
			model,
			"Tip" .. i,
			Enum.PartType.Ball,
			Vector3.one * 0.16,
			CFrame.new(arcPoint(if side > 0 then 0 else arcSteps)),
			gemColor,
			Enum.Material.Neon
		)
	end

	-- Gema em tres camadas.
	local gemCf = CFrame.new(gemX, 0, 0)
	local gem = piece(model, "Gem", Enum.PartType.Ball, Vector3.one * 0.55, gemCf, gemColor, Enum.Material.Neon)
	piece(model, "GemCore", Enum.PartType.Ball, Vector3.one * 0.25, gemCf, Color3.new(1, 1, 1), Enum.Material.Neon)
	local shell = piece(model, "GemShell", Enum.PartType.Ball, Vector3.one * 0.8, gemCf, gemColor, Enum.Material.Glass)
	shell.Transparency = 0.6

	local muzzle = Instance.new("Attachment")
	muzzle.Name = "Muzzle"
	muzzle.Parent = gem

	local light = Instance.new("PointLight")
	light.Name = "GemLight"
	light.Color = gemColor
	light.Range = 8
	light.Brightness = 1.5
	light.Parent = gem

	local glow = Instance.new("ParticleEmitter")
	glow.Name = "GemGlow"
	glow.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	glow.Color = ColorSequence.new(gemColor)
	glow.LightEmission = 1
	glow.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.22), NumberSequenceKeypoint.new(1, 0) })
	glow.Transparency = NumberSequence.new(0.2, 1)
	glow.Lifetime = NumberRange.new(0.4, 0.8)
	glow.Rate = 5
	glow.Speed = NumberRange.new(0.3, 1)
	glow.SpreadAngle = Vector2.new(180, 180)
	glow.Parent = muzzle

	-- Ponto onde a mao segura (alvo do IKControl).
	local gripPoint = Instance.new("Attachment")
	gripPoint.Name = "GripPoint"
	gripPoint.Position = Vector3.new(grip, 0, 0)
	gripPoint.Parent = root

	-- Tudo preso a raiz com Weld e deslocamento explicito (C0). NAO usar WeldConstraint aqui: ela
	-- grava o deslocamento no instante em que entra no mundo, quando a raiz ja foi levada ao
	-- personagem e as pecas ainda estao na origem (o cajado se desmontava).
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and child ~= root then
			local weld = Instance.new("Weld")
			weld.Part0 = root
			weld.Part1 = child
			weld.C0 = root.CFrame:ToObjectSpace(child.CFrame)
			weld.Parent = child
		end
	end
	for i = 1, 3 do
		local shard = piece(
			model,
			"Shard" .. i,
			Enum.PartType.Block,
			Vector3.new(0.14, 0.32, 0.14),
			CFrame.identity,
			gemColor,
			Enum.Material.Neon
		)
		local weld = Instance.new("Weld")
		weld.Name = "ShardWeld"
		weld.Part0 = root
		weld.Part1 = shard
		-- Orbita inicial ao redor da gema (o cliente anima).
		local angle = (i / 3) * math.pi * 2
		weld.C0 = CFrame.new(gemX, math.cos(angle) * 0.75, math.sin(angle) * 0.75)
		weld.Parent = shard
	end

	return model
end

return StaffBuilder
