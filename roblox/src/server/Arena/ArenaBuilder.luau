--!strict
-- Monta a Arena por codigo (sem arquivo binario): coliseu flutuante bem longe do Sandbox, com
-- piso de pedra e areia, circulos runicos, muralha com 4 portoes (de onde saem as criaturas),
-- pilares com braseiros, arquibancadas em degraus, estandartes das 5 escolas, plataformas de
-- vida e mana no centro e o portal de saida. No Sandbox, um arco com portal leva ate a Arena.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Schools = require(Shared.Schools)
local TextureCatalog = require(Shared.TextureCatalog)

local ArenaBuilder = {}

ArenaBuilder.CENTER = Vector3.new(0, 60, 900) -- topo do piso no centro da Arena
ArenaBuilder.RADIUS = 90 -- raio da area de luta (studs)
ArenaBuilder.SANDBOX_PORTAL = Vector3.new(38, 0, 52) -- portal no Sandbox (perto do ponto de nascer)

export type Layout = {
	Model: Model,
	Center: Vector3,
	Radius: number,
	Gates: { CFrame }, -- de onde as criaturas saem (olhando para o centro)
	Pads: { { Kind: string, Position: Vector3 } }, -- plataformas dos coletaveis
	Exit: Vector3, -- portal de volta ao Sandbox
	Arrival: Vector3, -- onde quem entra aparece
	Entrance: Vector3, -- portal no Sandbox
}

local STONE = Color3.fromRGB(96, 90, 100)
local DARK_STONE = Color3.fromRGB(62, 58, 70)
local SAND = Color3.fromRGB(176, 152, 120)
local ARCANE = Color3.fromRGB(155, 92, 255)

local function part(parent: Instance, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CastShadow = true
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end

-- Disco deitado (cilindro com o eixo na vertical).
local function disc(parent: Instance, center: Vector3, diameter: number, height: number, props: { [string]: any }): Part
	local p = part(parent, props)
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(height, diameter, diameter)
	p.CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90))
	return p
end

-- Anel de pecas em volta de `center` (arcos retos). `skip(angle)` pula pedacos (portoes).
local function ring(
	parent: Instance,
	center: Vector3,
	radius: number,
	count: number,
	size: (arc: number) -> Vector3,
	props: { [string]: any },
	skip: ((angle: number) -> boolean)?
)
	for i = 1, count do
		local angle = (i - 0.5) / count * math.pi * 2
		if not (skip and skip(angle)) then
			local arc = 2 * math.pi * radius / count
			local s = size(arc)
			local position = center + Vector3.new(math.cos(angle) * radius, s.Y / 2, math.sin(angle) * radius)
			local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle))
			local p = part(parent, props)
			p.Size = s
			p.CFrame = CFrame.lookAt(position, position + tangent)
		end
	end
end

local function fire(parent: BasePart, scale: number)
	local attachment = Instance.new("Attachment")
	attachment.Position = Vector3.new(0, parent.Size.Y / 2, 0)
	attachment.Parent = parent
	local flame = Instance.new("ParticleEmitter")
	flame.Texture = TextureCatalog.FireColor4
	flame.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
	flame.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	flame.LightEmission = 1
	flame.LightInfluence = 0
	flame.Brightness = 1.4
	flame.Rate = 14
	flame.Lifetime = NumberRange.new(0.6, 0.9)
	flame.Speed = NumberRange.new(2, 4)
	flame.SpreadAngle = Vector2.new(10, 10)
	flame.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 2.2 * scale),
		NumberSequenceKeypoint.new(1, 3.2 * scale),
	})
	flame.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.8, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	flame.Acceleration = Vector3.new(0, 4, 0)
	flame.Parent = attachment
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 150, 70)
	light.Range = 34
	light.Brightness = 1.6
	light.Shadows = false
	light.Parent = attachment
end

-- Portal giratorio (disco escuro com borda brilhante e particulas sugando).
local function portalDisc(parent: Instance, cframe: CFrame, diameter: number, color: Color3)
	local face = part(parent, {
		Name = "PortalFace",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, diameter, diameter),
		CFrame = cframe * CFrame.Angles(0, math.rad(90), 0),
		Material = Enum.Material.Neon,
		Color = color:Lerp(Color3.new(0, 0, 0), 0.65),
		Transparency = 0.15,
		CanCollide = false,
		CanQuery = false,
	})
	local rim = part(parent, {
		Name = "PortalRim",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.5, diameter + 1.2, diameter + 1.2),
		CFrame = face.CFrame * CFrame.new(-0.1, 0, 0),
		Material = Enum.Material.Neon,
		Color = color,
		Transparency = 0.35,
		CanCollide = false,
		CanQuery = false,
	})
	rim.CastShadow = false
	face.CastShadow = false
	local attachment = Instance.new("Attachment")
	attachment.Parent = face
	local swirl = Instance.new("ParticleEmitter")
	swirl.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	swirl.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
	swirl.LightEmission = 1
	swirl.Brightness = 2
	swirl.Rate = 30
	swirl.Lifetime = NumberRange.new(0.6, 1)
	swirl.Speed = NumberRange.new(-6, -3)
	swirl.SpreadAngle = Vector2.new(180, 180)
	swirl.Size = NumberSequence.new(0.5, 0)
	swirl.Parent = attachment
	face:AddTag("ArenaPortal")
end

local function banner(parent: Instance, cframe: CFrame, palette: any)
	part(parent, {
		Name = "Banner",
		Size = Vector3.new(6, 12, 0.3),
		CFrame = cframe,
		Material = Enum.Material.Fabric,
		Color = palette.Halo:Lerp(Color3.new(0, 0, 0), 0.35),
		CanCollide = false,
	})
	local emblem = part(parent, {
		Name = "Emblem",
		Size = Vector3.new(2, 2, 0.35),
		CFrame = cframe * CFrame.new(0, 1.5, -0.05) * CFrame.Angles(0, 0, math.rad(45)),
		Material = Enum.Material.Neon,
		Color = palette.Halo,
		CanCollide = false,
	})
	emblem.CastShadow = false
	part(parent, {
		Name = "BannerRod",
		Size = Vector3.new(7, 0.4, 0.4),
		CFrame = cframe * CFrame.new(0, 6.2, 0),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(60, 50, 40),
	})
end

local function buildArena(world: Instance): Layout
	local model = Instance.new("Model")
	model.Name = "Arena"
	local center = ArenaBuilder.CENTER
	local radius = ArenaBuilder.RADIUS
	local floorY = center.Y

	-- Fundacao (ilha de pedra flutuante) e piso.
	disc(model, center - Vector3.new(0, 4, 0), radius * 2 + 70, 8, {
		Name = "Foundation",
		Material = Enum.Material.Slate,
		Color = DARK_STONE,
	})
	disc(model, center - Vector3.new(0, 14, 0), radius * 2 + 30, 14, {
		Name = "Underside",
		Material = Enum.Material.Rock,
		Color = Color3.fromRGB(70, 62, 66),
	})
	disc(model, center + Vector3.new(0, 0.05, 0), radius * 2, 0.2, {
		Name = "Sand",
		Material = Enum.Material.Sand,
		Color = SAND,
	})
	disc(model, center + Vector3.new(0, 0.1, 0), 76, 0.2, {
		Name = "RuneFloor",
		Material = Enum.Material.Slate,
		Color = STONE,
	})
	-- Anel arcano no piso e dais central.
	ring(model, center + Vector3.new(0, 0.12, 0), 38, 40, function(arc)
		return Vector3.new(0.6, 0.12, arc * 0.9)
	end, { Name = "RuneRing", Material = Enum.Material.Neon, Color = ARCANE, CanCollide = false })
	disc(model, center + Vector3.new(0, 0.6, 0), 26, 1.2, {
		Name = "Dais",
		Material = Enum.Material.Marble,
		Color = Color3.fromRGB(206, 200, 214),
	})
	ring(model, center + Vector3.new(0, 1.15, 0), 12.4, 28, function(arc)
		return Vector3.new(0.4, 0.1, arc * 0.85)
	end, { Name = "DaisRing", Material = Enum.Material.Neon, Color = ARCANE, CanCollide = false })
	-- Simbolo da Arena no dais (circulo magico pintado, brilhando de leve).
	local emblem = part(model, {
		Name = "DaisEmblem",
		Size = Vector3.new(22, 0.05, 22),
		CFrame = CFrame.new(center + Vector3.new(0, 1.25, 0)),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.LightInfluence = 0
	gui.Brightness = 1.3
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 24
	gui.Parent = emblem
	local image = Instance.new("ImageLabel")
	image.Size = UDim2.fromScale(1, 1)
	image.BackgroundTransparency = 1
	image.Image = TextureCatalog.CircleStar
	image.ImageColor3 = ARCANE
	image.ImageTransparency = 0.35
	image.Parent = gui

	-- Muralha com 4 portoes (Leste, Sul, Oeste, Norte).
	local gateAngles = { 0, math.pi / 2, math.pi, math.pi * 1.5 }
	local function nearGate(angle: number): boolean
		for _, g in gateAngles do
			local d = math.abs(((angle - g + math.pi) % (math.pi * 2)) - math.pi)
			if d < math.rad(7) then
				return true
			end
		end
		return false
	end
	ring(model, Vector3.new(center.X, floorY, center.Z), radius + 3, 48, function(arc)
		return Vector3.new(4, 16, arc * 1.04)
	end, { Name = "Wall", Material = Enum.Material.Cobblestone, Color = STONE }, nearGate)
	ring(model, Vector3.new(center.X, floorY + 16, center.Z), radius + 3, 96, function(arc)
		return Vector3.new(4.4, 2.4, arc * 0.5)
	end, { Name = "Crenel", Material = Enum.Material.Cobblestone, Color = DARK_STONE }, function(angle)
		return nearGate(angle) or math.floor(angle / (math.pi * 2) * 96) % 2 == 1
	end)

	local gates: { CFrame } = {}
	for _, angle in gateAngles do
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local side = Vector3.new(-dir.Z, 0, dir.X)
		local base = Vector3.new(center.X, floorY, center.Z) + dir * (radius + 3)
		for _, s in { -1, 1 } do
			part(model, {
				Name = "GatePillar",
				Size = Vector3.new(5, 24, 5),
				CFrame = CFrame.lookAt(
					base + side * s * 9 + Vector3.new(0, 12, 0),
					base + side * s * 9 + Vector3.new(0, 12, 0) - dir
				),
				Material = Enum.Material.Marble,
				Color = Color3.fromRGB(150, 142, 160),
			})
		end
		part(model, {
			Name = "GateLintel",
			Size = Vector3.new(24, 4, 6),
			CFrame = CFrame.lookAt(base + Vector3.new(0, 24, 0), base + Vector3.new(0, 24, 0) - dir),
			Material = Enum.Material.Marble,
			Color = Color3.fromRGB(150, 142, 160),
		})
		portalDisc(model, CFrame.lookAt(base + Vector3.new(0, 10, 0), base + Vector3.new(0, 10, 0) - dir), 16, ARCANE)
		local spawn = Vector3.new(center.X, floorY + 4, center.Z) + dir * (radius - 6)
		table.insert(gates, CFrame.lookAt(spawn, Vector3.new(center.X, spawn.Y, center.Z)))
	end

	-- Pilares com braseiros entre os portoes.
	for i = 0, 7 do
		local angle = (i + 0.5) * math.pi / 4
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local base = Vector3.new(center.X, floorY, center.Z) + dir * (radius - 1.5)
		local pillar = part(model, {
			Name = "Pillar",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(20, 4, 4),
			CFrame = CFrame.new(base + Vector3.new(0, 10, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Material = Enum.Material.Marble,
			Color = Color3.fromRGB(170, 162, 178),
		})
		pillar.Name = "Pillar"
		local bowl = part(model, {
			Name = "Brazier",
			Size = Vector3.new(5, 1.6, 5),
			CFrame = CFrame.new(base + Vector3.new(0, 20.8, 0)),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(70, 56, 44),
		})
		fire(bowl, 1.3)
		-- Estandarte da escola pendurado na muralha, entre pilar e portao.
		local schoolNames = { "Electricity", "Fire", "Energy", "Necromancy", "Blood" }
		local palette = (Schools :: any)[schoolNames[i % 5 + 1]]
		local bannerAngle = angle + math.rad(11)
		local bdir = Vector3.new(math.cos(bannerAngle), 0, math.sin(bannerAngle))
		local bpos = Vector3.new(center.X, floorY + 9, center.Z) + bdir * (radius + 0.8)
		banner(model, CFrame.lookAt(bpos, bpos - bdir), palette)
	end

	-- Arquibancadas em degraus do lado de fora da muralha.
	for tier = 1, 3 do
		local r = radius + 6 + tier * 5
		local height = 4 + tier * 5
		ring(model, Vector3.new(center.X, floorY, center.Z), r, 56, function(arc)
			return Vector3.new(5.2, height, arc * 1.04)
		end, {
			Name = "Stand",
			Material = Enum.Material.Concrete,
			Color = if tier % 2 == 0 then Color3.fromRGB(120, 112, 118) else Color3.fromRGB(104, 98, 106),
		})
	end

	-- Plataformas dos coletaveis (vida e mana alternados nas diagonais).
	local pads: { { Kind: string, Position: Vector3 } } = {}
	for i = 0, 3 do
		local angle = math.pi / 4 + i * math.pi / 2
		local kind = if i % 2 == 0 then "Health" else "Mana"
		local color = if kind == "Health" then Color3.fromRGB(90, 230, 120) else Color3.fromRGB(80, 160, 255)
		local position = Vector3.new(center.X, floorY, center.Z) + Vector3.new(math.cos(angle), 0, math.sin(angle)) * 22
		disc(model, position + Vector3.new(0, 0.4, 0), 7, 0.8, {
			Name = kind .. "Pad",
			Material = Enum.Material.Marble,
			Color = Color3.fromRGB(196, 192, 204),
		})
		ring(model, position + Vector3.new(0, 0.82, 0), 3.2, 16, function(arc)
			return Vector3.new(0.3, 0.08, arc * 0.85)
		end, { Name = kind .. "PadRing", Material = Enum.Material.Neon, Color = color, CanCollide = false })
		table.insert(pads, { Kind = kind, Position = position + Vector3.new(0, 3.2, 0) })
	end

	-- Portal de saida (de volta ao Sandbox) e ponto de chegada.
	local exitAngle = math.rad(45) -- diagonal (longe dos portoes e dos braseiros)
	local exitDir = Vector3.new(math.cos(exitAngle), 0, math.sin(exitAngle))
	local exitBase = Vector3.new(center.X, floorY, center.Z) + exitDir * (radius - 14)
	disc(model, exitBase + Vector3.new(0, 0.3, 0), 9, 0.6, {
		Name = "ExitPad",
		Material = Enum.Material.Marble,
		Color = Color3.fromRGB(196, 192, 204),
	})
	portalDisc(
		model,
		CFrame.lookAt(exitBase + Vector3.new(0, 5.5, 0), exitBase + Vector3.new(0, 5.5, 0) - exitDir),
		8,
		Color3.fromRGB(120, 220, 255)
	)
	local arrival = Vector3.new(center.X, floorY + 4, center.Z) + exitDir * (radius - 26)

	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p:AddTag("ArenaGeometry")
		end
	end
	model.Parent = world
	return {
		Model = model,
		Center = Vector3.new(center.X, floorY, center.Z),
		Radius = radius,
		Gates = gates,
		Pads = pads,
		Exit = exitBase + Vector3.new(0, 3, 0),
		Arrival = arrival,
		Entrance = ArenaBuilder.SANDBOX_PORTAL,
	}
end

-- Arco com portal no Sandbox (leva a Arena) com placa flutuante.
local function buildEntrance(world: Instance)
	local model = Instance.new("Model")
	model.Name = "ArenaEntrance"
	local base = ArenaBuilder.SANDBOX_PORTAL
	local facing = Vector3.new(-1, 0, 0) -- de frente para o ponto de nascer
	local side = Vector3.new(0, 0, 1)
	for _, s in { -1, 1 } do
		part(model, {
			Name = "ArchPillar",
			Size = Vector3.new(3, 16, 3),
			CFrame = CFrame.new(base + side * s * 7 + Vector3.new(0, 8, 0)),
			Material = Enum.Material.Marble,
			Color = Color3.fromRGB(170, 162, 178),
		})
	end
	part(model, {
		Name = "ArchTop",
		Size = Vector3.new(3.4, 3, 18),
		CFrame = CFrame.new(base + Vector3.new(0, 17, 0)),
		Material = Enum.Material.Marble,
		Color = Color3.fromRGB(170, 162, 178),
	})
	disc(model, base + Vector3.new(0, 0.3, 0), 14, 0.6, {
		Name = "EntrancePad",
		Material = Enum.Material.Slate,
		Color = DARK_STONE,
	})
	portalDisc(model, CFrame.lookAt(base + Vector3.new(0, 8, 0), base + Vector3.new(0, 8, 0) + facing), 11, ARCANE)
	local sign = part(model, {
		Name = "Sign",
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.new(base + Vector3.new(0, 22, 0)),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(260, 70)
	billboard.LightInfluence = 0
	billboard.MaxDistance = 220
	billboard.Parent = sign
	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 0.6)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(230, 210, 255)
	title.TextStrokeTransparency = 0.2
	title.Text = "ARENA ARCANA"
	title.Parent = billboard
	local sub = Instance.new("TextLabel")
	sub.Size = UDim2.fromScale(1, 0.4)
	sub.Position = UDim2.fromScale(0, 0.6)
	sub.BackgroundTransparency = 1
	sub.Font = Enum.Font.GothamBold
	sub.TextScaled = true
	sub.TextColor3 = Color3.fromRGB(255, 255, 255)
	sub.TextStrokeTransparency = 0.3
	sub.Text = "Entre no portal para lutar"
	sub.Parent = billboard
	model.Parent = world
end

function ArenaBuilder.build(world: Instance): Layout
	for _, name in { "Arena", "ArenaEntrance" } do
		local existing = world:FindFirstChild(name)
		if existing then
			existing:Destroy()
		end
	end
	buildEntrance(world)
	return buildArena(world)
end

return ArenaBuilder
