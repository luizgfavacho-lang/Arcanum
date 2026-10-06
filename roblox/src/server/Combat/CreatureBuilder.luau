--!strict
-- Corpos das criaturas montados por codigo (sem assets), para nao parecerem bonecos padrao:
--   Skeleton  (Ossomante): esqueleto magro de osso, capuz e manto rasgado, costelas a mostra,
--             olhos em brasa na cor da escola e nevoa escura nos pes.
--   Golem     (Golem de Cristal): pedra escura, punhos e bracadeiras de rocha, cristais nos ombros,
--             costas e cabeca, nucleo brilhante no peito.
--   Slime     (Gosma e Gosminha): gelatina translucida com nucleo, bolhas internas e olhos.
--   Bloater   (Bulbo Tempestuoso): bulbo flutuante de membrana eletrica, nucleo e tentaculos.
-- Skeleton/Golem usam o rig R15 (animacoes do Roblox) + pecas soldadas, dimensionadas pelo tamanho
-- real de cada parte (funciona depois de ScaleTo). Slime/Bloater sao "bolhas": so HumanoidRootPart
-- invisivel + Humanoid (HipHeight) e a peca "Body" num Motor6D "Body"; o cliente anima o Transform
-- e a escala da malha (client/Vfx/Creatures). Todas recebem o atributo "Creature" (tipo).

export type Palette = { Core: Color3, Halo: Color3, Accent: Color3, Shape: string }

local CreatureBuilder = {}

local KINDS: { [string]: string } = {
	SkeletonMage = "Skeleton",
	UndeadMage = "Skeleton",
	CrystalGolem = "Golem",
	ArcaneSlime = "Slime",
	ArcaneSlimeSmall = "Slime",
	StormBloater = "Bloater",
}

local BLOB_SIZE: { [string]: number } = { ArcaneSlime = 1, ArcaneSlimeSmall = 0.6, StormBloater = 1 }

local BONE = Color3.fromRGB(168, 156, 132) -- osso envelhecido (claro demais estoura ao sol)
local SOCKET = Color3.fromRGB(22, 16, 24)
local ROBE = Color3.fromRGB(36, 28, 42)
local STONE = Color3.fromRGB(66, 68, 84)
local STONE_DARK = Color3.fromRGB(42, 42, 56)
local WHITE = Color3.new(1, 1, 1)

function CreatureBuilder.kind(rowName: string): string
	return KINDS[rowName] or "Plain"
end

function CreatureBuilder.isBlob(rowName: string): boolean
	local kind = CreatureBuilder.kind(rowName)
	return kind == "Slime" or kind == "Bloater"
end

-- Peca decorativa soldada (Weld com C0 explicito) a uma parte do corpo. Sem colisao, mas
-- consultavel: magias acertam o manto/cristais como se fossem o corpo.
local function attach(
	parent: BasePart,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material,
	props: { [string]: any }?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material
	p.CanCollide = false
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if material == Enum.Material.Neon then
		p.CastShadow = false
	end
	if props then
		for key, value in props do
			(p :: any)[key] = value
		end
	end
	p.CFrame = parent.CFrame * offset
	local weld = Instance.new("Weld")
	weld.Part0 = parent
	weld.Part1 = p
	weld.C0 = offset
	weld.Parent = p
	p.Parent = parent.Parent
	return p
end

local function light(parent: Instance, color: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = parent
end

local function emitter(parent: BasePart, props: { [string]: any }): ParticleEmitter
	local attachment = Instance.new("Attachment")
	attachment.Name = "AuraAttachment"
	attachment.Parent = parent
	local e = Instance.new("ParticleEmitter")
	e.LightInfluence = 0
	for key, value in props do
		(e :: any)[key] = value
	end
	e.Parent = attachment
	return e
end

local function part(model: Instance, name: string): BasePart?
	local p = model:FindFirstChild(name)
	return if p and p:IsA("BasePart") then p else nil
end

local function removeFace(head: BasePart)
	for _, child in head:GetChildren() do
		if child:IsA("Decal") then
			child:Destroy()
		end
	end
end

local function legLength(model: Model): number
	local total = 0
	for _, name in { "LeftUpperLeg", "LeftLowerLeg", "LeftFoot" } do
		local p = part(model, name)
		total += if p then p.Size.Y else 0
	end
	return if total > 0 then total else 2
end

-- Cristal: casca de vidro + miolo Neon, girado 45 graus (le como prisma).
local function crystal(parent: BasePart, offset: CFrame, length: number, thickness: number, palette: Palette)
	local cf = offset * CFrame.Angles(0, math.rad(45), 0)
	attach(
		parent,
		"Crystal",
		Vector3.new(thickness, length, thickness),
		cf,
		palette.Halo:Lerp(WHITE, 0.25),
		Enum.Material.Glass,
		{ Transparency = 0.25, Reflectance = 0.15 }
	)
	attach(
		parent,
		"CrystalCore",
		Vector3.new(thickness * 0.45, length * 0.82, thickness * 0.45),
		cf,
		palette.Halo,
		Enum.Material.Neon
	)
end

---------------------------------------------------------------------------------------------------
-- Humanoides (R15)

-- Proporcoes do rig antes de montar (HumanoidDescription).
function CreatureBuilder.describe(rowName: string, description: HumanoidDescription, palette: Palette?)
	local kind = CreatureBuilder.kind(rowName)
	local body: Color3
	if kind == "Skeleton" then
		body = BONE
		description.WidthScale = 0.72
		description.DepthScale = 0.75
		description.HeightScale = 1.05
	elseif kind == "Golem" then
		body = STONE
		description.WidthScale = 1
		description.DepthScale = 1
	else
		body = if palette then palette.Halo:Lerp(Color3.new(0.2, 0.2, 0.25), 0.55) else Color3.fromRGB(90, 90, 100)
	end
	description.HeadColor = body
	description.TorsoColor = body
	description.LeftArmColor = body
	description.RightArmColor = body
	description.LeftLegColor = body
	description.RightLegColor = body
end

local function skeleton(model: Model, palette: Palette)
	local head, upper, lower = part(model, "Head"), part(model, "UpperTorso"), part(model, "LowerTorso")
	if not head or not upper or not lower then
		return
	end
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
			p.Color = BONE
			p.Material = Enum.Material.Limestone
		end
	end
	removeFace(head)
	local robe = ROBE:Lerp(palette.Halo, 0.1)
	local hs = head.Size
	local s = hs.Y

	-- Cranio: orbitas escuras com brasas, dentes.
	for _, side in { -1, 1 } do
		attach(
			head,
			"EyeSocket",
			Vector3.one * s * 0.28,
			CFrame.new(side * hs.X * 0.19, s * 0.05, -hs.Z * 0.4),
			SOCKET,
			Enum.Material.SmoothPlastic,
			{ Shape = Enum.PartType.Ball }
		)
		attach(
			head,
			"Eye",
			Vector3.one * s * 0.13,
			CFrame.new(side * hs.X * 0.19, s * 0.05, -hs.Z * 0.5),
			palette.Halo:Lerp(WHITE, 0.2),
			Enum.Material.Neon,
			{ Shape = Enum.PartType.Ball }
		)
	end
	attach(
		head,
		"Teeth",
		Vector3.new(hs.X * 0.42, s * 0.07, 0.06),
		CFrame.new(0, -s * 0.27, -hs.Z * 0.49),
		SOCKET,
		Enum.Material.SmoothPlastic
	)

	-- Capuz (topo, laterais, nuca e bico caido para tras).
	attach(
		head,
		"HoodTop",
		Vector3.new(hs.X * 1.32, s * 0.18, hs.Z * 1.25),
		CFrame.new(0, s * 0.6, hs.Z * 0.06),
		robe,
		Enum.Material.Fabric
	)
	for _, side in { -1, 1 } do
		attach(
			head,
			"HoodSide",
			Vector3.new(s * 0.14, s * 1.15, hs.Z * 1.2),
			CFrame.new(side * hs.X * 0.6, s * 0.06, hs.Z * 0.08),
			robe,
			Enum.Material.Fabric
		)
	end
	attach(
		head,
		"HoodBack",
		Vector3.new(hs.X * 1.32, s * 1.2, s * 0.16),
		CFrame.new(0, s * 0.04, hs.Z * 0.62),
		robe,
		Enum.Material.Fabric
	)
	attach(
		head,
		"HoodPeak",
		Vector3.new(hs.X * 0.9, s * 0.55, hs.Z * 0.8),
		CFrame.new(0, s * 0.86, hs.Z * 0.42) * CFrame.Angles(math.rad(-25), math.rad(180), 0),
		robe,
		Enum.Material.Fabric,
		{ Shape = Enum.PartType.Wedge }
	)

	-- Manto: peito, costelas a mostra, pingente brilhante, cinto, saia em 6 paineis rasgados e capa.
	local u, l = upper.Size, lower.Size
	attach(upper, "RobeChest", u * Vector3.new(1.08, 1.02, 1.12), CFrame.new(), robe, Enum.Material.Fabric)
	for i = 0, 2 do
		attach(
			upper,
			"Rib",
			Vector3.new(u.X * (0.55 - i * 0.08), u.Y * 0.07, 0.08),
			CFrame.new(0, u.Y * (0.22 - i * 0.17), -u.Z * 0.58),
			BONE,
			Enum.Material.Limestone
		)
	end
	attach(
		upper,
		"Sternum",
		Vector3.new(u.X * 0.08, u.Y * 0.5, 0.09),
		CFrame.new(0, u.Y * 0.05, -u.Z * 0.6),
		BONE,
		Enum.Material.Limestone
	)
	attach(
		upper,
		"Pendant",
		Vector3.new(0.26, 0.26, 0.1),
		CFrame.new(0, -u.Y * 0.32, -u.Z * 0.62) * CFrame.Angles(0, 0, math.rad(45)),
		palette.Halo,
		Enum.Material.Neon
	)
	for _, side in { -1, 1 } do
		attach(
			upper,
			"Pauldron",
			Vector3.one * u.Y * 0.5,
			CFrame.new(side * u.X * 0.52, u.Y * 0.36, 0),
			BONE,
			Enum.Material.Limestone,
			{ Shape = Enum.PartType.Ball }
		)
		attach(
			upper,
			"PauldronSpike",
			Vector3.new(0.12, u.Y * 0.45, 0.12),
			CFrame.new(side * u.X * 0.6, u.Y * 0.62, 0) * CFrame.Angles(0, 0, math.rad(-side * 25)),
			BONE,
			Enum.Material.Limestone
		)
	end
	attach(
		lower,
		"Belt",
		Vector3.new(l.X * 1.15, l.Y * 0.45, l.Z * 1.22),
		CFrame.new(0, l.Y * 0.25, 0),
		palette.Accent:Lerp(Color3.new(0, 0, 0), 0.6),
		Enum.Material.Leather
	)
	local legs = legLength(model)
	local radius = math.max(l.X, l.Z) * 0.5
	for i = 0, 5 do
		local angle = i * math.pi / 3
		local width = 2 * radius * math.tan(math.pi / 6) * 1.3
		local height = legs * (0.78 + (i % 2) * 0.12) -- barra irregular (rasgada)
		local offset = CFrame.Angles(0, angle, 0)
			* CFrame.new(0, -l.Y * 0.1, -radius)
			* CFrame.Angles(math.rad(11), 0, 0)
			* CFrame.new(0, -height / 2, 0)
		attach(lower, "RobeSkirt", Vector3.new(width, height, 0.12), offset, robe, Enum.Material.Fabric)
	end
	local capeLength = u.Y + legs * 0.75
	attach(
		upper,
		"Cape",
		Vector3.new(u.X * 0.9, capeLength, 0.1),
		CFrame.new(0, u.Y * 0.45, u.Z * 0.58) * CFrame.Angles(math.rad(-7), 0, 0) * CFrame.new(0, -capeLength / 2, 0),
		robe:Lerp(Color3.new(0, 0, 0), 0.25),
		Enum.Material.Fabric
	)

	-- Brasas subindo do manto e nevoa escura nos pes.
	emitter(upper, {
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Color = ColorSequence.new(palette.Halo),
		LightEmission = 0.4,
		Size = NumberSequence.new(0.16, 0),
		Transparency = NumberSequence.new(0.35, 1),
		Lifetime = NumberRange.new(1, 1.6),
		Speed = NumberRange.new(0.4, 1.2),
		Acceleration = Vector3.new(0, 2, 0),
		SpreadAngle = Vector2.new(180, 180),
		Rate = 2,
	})
	local foot = part(model, "LeftFoot") or lower
	emitter(foot, {
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(30, 22, 36)),
		LightEmission = 0,
		Size = NumberSequence.new(1.2, 3),
		Transparency = NumberSequence.new(0.75, 1),
		Lifetime = NumberRange.new(1, 1.6),
		Speed = NumberRange.new(0.2, 0.6),
		SpreadAngle = Vector2.new(180, 20),
		Rate = 5,
	})
end

local function golem(model: Model, palette: Palette)
	local head, upper = part(model, "Head"), part(model, "UpperTorso")
	if not head or not upper then
		return
	end
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
			p.Color = STONE
			p.Material = Enum.Material.Slate
		end
	end
	removeFace(head)
	local hs, u = head.Size, upper.Size

	-- Rosto: testa pesada e olhos em fenda.
	attach(
		head,
		"Brow",
		Vector3.new(hs.X * 1.1, hs.Y * 0.24, hs.Z * 0.45),
		CFrame.new(0, hs.Y * 0.28, -hs.Z * 0.35),
		STONE_DARK,
		Enum.Material.Slate
	)
	for _, side in { -1, 1 } do
		attach(
			head,
			"Eye",
			Vector3.new(hs.X * 0.24, hs.Y * 0.08, 0.06),
			CFrame.new(side * hs.X * 0.2, hs.Y * 0.08, -hs.Z * 0.5),
			palette.Core:Lerp(palette.Halo, 0.3),
			Enum.Material.Neon
		)
	end
	crystal(
		head,
		CFrame.new(-hs.X * 0.2, hs.Y * 0.55, hs.Z * 0.1) * CFrame.Angles(0, 0, math.rad(18)),
		hs.Y * 0.8,
		hs.X * 0.18,
		palette
	)
	crystal(
		head,
		CFrame.new(hs.X * 0.22, hs.Y * 0.5, 0) * CFrame.Angles(math.rad(-10), 0, math.rad(-22)),
		hs.Y * 0.6,
		hs.X * 0.15,
		palette
	)

	-- Peito: placa de pedra e nucleo de energia.
	attach(
		upper,
		"ChestPlate",
		u * Vector3.new(1.1, 0.75, 1.15),
		CFrame.new(0, u.Y * 0.12, 0),
		STONE_DARK,
		Enum.Material.Basalt
	)
	local core = attach(
		upper,
		"Core",
		Vector3.one * u.X * 0.26,
		CFrame.new(0, u.Y * 0.12, -u.Z * 0.6),
		palette.Core,
		Enum.Material.Neon,
		{ Shape = Enum.PartType.Ball }
	)
	attach(
		upper,
		"CoreShell",
		Vector3.one * u.X * 0.4,
		CFrame.new(0, u.Y * 0.12, -u.Z * 0.55),
		palette.Halo,
		Enum.Material.Glass,
		{ Shape = Enum.PartType.Ball, Transparency = 0.45 }
	)
	light(core, palette.Halo, 12, 1.1)

	-- Cristais nos ombros (abrindo para fora) e nas costas (inclinados para tras).
	for _, side in { -1, 1 } do
		for k = 0, 2 do
			local lean = math.rad(-side * (18 + k * 16))
			local twist = math.rad((k - 1) * 14)
			crystal(
				upper,
				CFrame.new(side * u.X * (0.42 + k * 0.05), u.Y * 0.5, (k - 1) * u.Z * 0.22)
					* CFrame.Angles(twist, 0, lean)
					* CFrame.new(0, u.Y * (0.35 + 0.12 * (2 - k)), 0),
				u.Y * (0.7 + 0.25 * (2 - k)),
				u.X * 0.12,
				palette
			)
		end
	end
	for k = 0, 3 do
		local x = (k - 1.5) * u.X * 0.22
		crystal(
			upper,
			CFrame.new(x, u.Y * (0.2 + (k % 2) * 0.15), u.Z * 0.45)
				* CFrame.Angles(math.rad(38), 0, math.rad(-x * 12))
				* CFrame.new(0, u.Y * 0.4, 0),
			u.Y * (0.8 + (k % 2) * 0.35),
			u.X * 0.14,
			palette
		)
	end

	-- Bracos de rocha: bracadeiras e punhos enormes com cristal nos nos dos dedos.
	for _, side in { "Left", "Right" } do
		local lowerArm = part(model, side .. "LowerArm")
		local hand = part(model, side .. "Hand")
		if lowerArm then
			attach(
				lowerArm,
				"Bracer",
				lowerArm.Size * Vector3.new(1.55, 0.85, 1.55),
				CFrame.new(),
				STONE_DARK,
				Enum.Material.Basalt
			)
		end
		if hand then
			local fist = Vector3.one * math.max(hand.Size.X, hand.Size.Z) * 2.3
			attach(hand, "Fist", fist, CFrame.new(0, -hand.Size.Y * 0.35, 0), STONE_DARK, Enum.Material.Slate)
			crystal(
				hand,
				CFrame.new(0, -hand.Size.Y * 0.35, -fist.Z * 0.45) * CFrame.Angles(math.rad(-70), 0, 0),
				fist.Y * 0.7,
				fist.X * 0.2,
				palette
			)
		end
	end

	emitter(upper, {
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Color = ColorSequence.new(palette.Halo, palette.Core),
		LightEmission = 1,
		Size = NumberSequence.new(0.6, 0),
		Transparency = NumberSequence.new(0.1, 1),
		Lifetime = NumberRange.new(0.8, 1.4),
		Speed = NumberRange.new(1, 3),
		SpreadAngle = Vector2.new(180, 180),
		Rate = 6,
	})
end

-- Veste um modelo R15 ja montado (e ja escalado) conforme o tipo da criatura.
function CreatureBuilder.dress(model: Model, rowName: string, palette: Palette)
	local kind = CreatureBuilder.kind(rowName)
	model:SetAttribute("Creature", kind)
	if kind == "Skeleton" then
		skeleton(model, palette)
	elseif kind == "Golem" then
		golem(model, palette)
	end
end

---------------------------------------------------------------------------------------------------
-- Bolhas (sem rig)

type BlobSpec = { RootSize: Vector3, HipHeight: number, BodySize: Vector3 }

local function blobBase(name: string, spec: BlobSpec): (Model, BasePart, Part)
	local model = Instance.new("Model")
	model.Name = name
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = spec.RootSize
	root.Transparency = 1
	root.CanCollide = true
	root.TopSurface = Enum.SurfaceType.Smooth
	root.BottomSurface = Enum.SurfaceType.Smooth
	root.Parent = model
	model.PrimaryPart = root

	-- Centro do corpo em relacao a raiz: a raiz flutua HipHeight acima do chao.
	local offsetY = spec.BodySize.Y / 2 - (spec.HipHeight + spec.RootSize.Y / 2)
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = spec.BodySize
	body.CanCollide = false
	body.CanTouch = false
	body.Massless = true
	body.CFrame = root.CFrame * CFrame.new(0, offsetY, 0)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = body
	local motor = Instance.new("Motor6D")
	motor.Name = "Body"
	motor.Part0 = root
	motor.Part1 = body
	motor.C0 = CFrame.new(0, offsetY, 0)
	motor.Parent = root
	body.Parent = model

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = spec.HipHeight
	humanoid.RequiresNeck = false
	humanoid.Parent = model
	return model, root, body
end

local function slime(name: string, palette: Palette, k: number): Model
	local model, _, body = blobBase(name, {
		RootSize = Vector3.new(2.4, 1.6, 2.4) * k,
		HipHeight = 0.3 * k,
		BodySize = Vector3.new(3.3, 2.6, 3.3) * k,
	})
	body.Color = palette.Halo:Lerp(WHITE, 0.12)
	body.Material = Enum.Material.SmoothPlastic
	body.Transparency = 0.32
	body.Reflectance = 0.08

	local core = attach(
		body,
		"Core",
		Vector3.one * 1.1 * k,
		CFrame.new(0, -0.15 * k, 0.15 * k),
		palette.Core,
		Enum.Material.Neon,
		{ Shape = Enum.PartType.Ball }
	)
	light(core, palette.Halo, 6 * k + 3, 0.8)
	for i = 1, 3 do
		local angle = i * 2.1
		attach(
			body,
			"Bubble",
			Vector3.one * (0.3 + 0.12 * i) * k,
			CFrame.new(math.cos(angle) * 0.8 * k, (-0.5 + 0.35 * i) * k, math.sin(angle) * 0.7 * k),
			palette.Accent,
			Enum.Material.Neon,
			{ Shape = Enum.PartType.Ball, Transparency = 0.35 }
		)
	end
	for _, side in { -1, 1 } do
		attach(
			body,
			"Eye",
			Vector3.one * 0.6 * k,
			CFrame.new(side * 0.5 * k, 0.4 * k, -1.32 * k),
			Color3.fromRGB(26, 18, 42),
			Enum.Material.SmoothPlastic,
			{ Shape = Enum.PartType.Ball }
		)
		attach(
			body,
			"EyeShine",
			Vector3.one * 0.2 * k,
			CFrame.new(side * 0.5 * k + 0.1 * k, 0.53 * k, -1.6 * k),
			WHITE,
			Enum.Material.Neon,
			{ Shape = Enum.PartType.Ball }
		)
	end
	model:SetAttribute("BarOffset", 2.6 * k + 0.6)
	return model
end

local function bloater(name: string, palette: Palette): Model
	local model, _, body = blobBase(name, {
		RootSize = Vector3.new(2.2, 2.2, 2.2),
		HipHeight = 3.4,
		BodySize = Vector3.new(3.8, 3.5, 3.8),
	})
	-- Assenta o corpo na altura da raiz (flutua) em vez de encostar no chao.
	local motor = (model:FindFirstChild("HumanoidRootPart") :: BasePart):FindFirstChild("Body") :: Motor6D
	motor.C0 = CFrame.new(0, 0.6, 0)
	body.CFrame = (model:FindFirstChild("HumanoidRootPart") :: BasePart).CFrame * motor.C0

	body.Color = palette.Halo:Lerp(WHITE, 0.2)
	body.Material = Enum.Material.Glass
	body.Transparency = 0.45
	attach(
		body,
		"Field",
		Vector3.one * 3.45,
		CFrame.new(),
		palette.Halo,
		Enum.Material.ForceField,
		{ Shape = Enum.PartType.Ball }
	)
	local core = attach(
		body,
		"Core",
		Vector3.one * 1.5,
		CFrame.new(),
		palette.Accent:Lerp(WHITE, 0.3),
		Enum.Material.Neon,
		{ Shape = Enum.PartType.Ball }
	)
	light(core, palette.Halo, 10, 1)
	attach(body, "Cap", Vector3.new(1.1, 0.5, 1.1), CFrame.new(0, 1.75, 0), STONE_DARK, Enum.Material.Slate)
	attach(
		body,
		"CapTip",
		Vector3.new(0.35, 0.7, 0.35),
		CFrame.new(0, 2.2, 0) * CFrame.Angles(0, math.rad(45), 0),
		palette.Accent,
		Enum.Material.Neon
	)
	for i = 0, 4 do
		local angle = i * math.pi * 2 / 5
		local length = 2.2 + (i % 2) * 0.6
		local tendril = CFrame.Angles(0, angle, 0)
			* CFrame.new(0, -1.4, -0.85)
			* CFrame.Angles(math.rad(-14), 0, 0)
			* CFrame.new(0, -length / 2, 0)
		attach(
			body,
			"Tendril",
			Vector3.new(0.2, length, 0.2),
			tendril,
			Color3.fromRGB(46, 50, 86),
			Enum.Material.SmoothPlastic
		)
		attach(
			body,
			"TendrilTip",
			Vector3.one * 0.38,
			tendril * CFrame.new(0, -length / 2, 0),
			palette.Accent,
			Enum.Material.Neon,
			{ Shape = Enum.PartType.Ball }
		)
	end
	emitter(core :: BasePart, {
		Texture = "rbxasset://textures/particles/fire_sparks_main.dds",
		Color = ColorSequence.new(palette.Core, palette.Accent),
		LightEmission = 1,
		Size = NumberSequence.new(0.3, 0),
		Transparency = NumberSequence.new(0, 1),
		Lifetime = NumberRange.new(0.2, 0.4),
		Speed = NumberRange.new(6, 10),
		SpreadAngle = Vector2.new(180, 180),
		Rate = 8,
	})
	model:SetAttribute("BarOffset", 3.2)
	return model
end

-- Monta uma criatura sem rig (bolha). Retorna nil para quem usa o R15.
function CreatureBuilder.buildBlob(rowName: string, palette: Palette): Model?
	local kind = CreatureBuilder.kind(rowName)
	local model: Model? = nil
	if kind == "Slime" then
		model = slime(rowName, palette, BLOB_SIZE[rowName] or 1)
	elseif kind == "Bloater" then
		model = bloater(rowName, palette)
	end
	if model then
		model:SetAttribute("Creature", kind)
	end
	return model
end

return CreatureBuilder
