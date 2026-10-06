--!strict
-- Blocos basicos dos efeitos (so cliente): Parts Neon, anexos no mundo, beams, emissores com
-- presets e animacao de fade. Texturas: as embutidas no Roblox (rbxasset://) e as publicas de
-- Shared/TextureCatalog (flipbooks de fogo e fumaca, circulos magicos, aneis, raios).

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Schools = require(ReplicatedStorage.Shared.Schools)
local StaffPose = require(ReplicatedStorage.Shared.StaffPose)
local TextureCatalog = require(ReplicatedStorage.Shared.TextureCatalog)

export type Palette = Schools.Palette

local Lib = {}

Lib.Textures = table.freeze({
	Sparkle = "rbxasset://textures/particles/sparkles_main.dds",
	Fire = "rbxasset://textures/particles/fire_main.dds",
	Sparks = "rbxasset://textures/particles/fire_sparks_main.dds",
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
	Glow = "rbxasset://textures/particles/forcefield_glow_main.dds",
	Vortex = "rbxasset://textures/particles/forcefield_vortex_main.dds",
})
Lib.Catalog = TextureCatalog

-- Circulo magico de cada escola (desenho no chao).
local CIRCLES = table.freeze({
	Energy = TextureCatalog.CircleStar,
	Fire = TextureCatalog.CircleOrnate,
	Electricity = TextureCatalog.CircleRunes,
	Necromancy = TextureCatalog.CircleThorns,
	Blood = TextureCatalog.CircleThorns,
})

local folder: Folder? = nil

function Lib.folder(): Folder
	if not folder then
		local f = Instance.new("Folder")
		f.Name = "ClientEffects"
		f.Parent = Workspace
		folder = f
	end
	return folder :: Folder
end

function Lib.palette(school: any): Palette
	return (if typeof(school) == "string" then Schools[school] else nil) or Schools.Energy
end

-- Nome da escola de uma paleta (as paletas sao as tabelas congeladas de Shared/Schools).
function Lib.schoolOf(palette: Palette): string
	for name, value in Schools :: any do
		if value == palette then
			return name
		end
	end
	return "Energy"
end

function Lib.circleTexture(palette: Palette): string
	return (CIRCLES :: any)[Lib.schoolOf(palette)] or TextureCatalog.CircleStar
end

-- Part decorativa (Neon por padrao), sem colisao nem consulta.
function Lib.part(size: Vector3, color: Color3, cframe: CFrame, options: { [string]: any }?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Size = size
	p.Color = color
	p.CFrame = cframe
	if options then
		for key, value in options do
			(p :: any)[key] = value
		end
	end
	p.Parent = Lib.folder()
	return p
end

-- Tween generico + destruicao ao fim.
function Lib.fade(inst: Instance, duration: number, goal: { [string]: any }, style: Enum.EasingStyle?)
	local info = TweenInfo.new(duration, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(inst, info, goal):Play()
	Debris:AddItem(inst, duration + 0.05)
end

function Lib.tween(
	inst: Instance,
	duration: number,
	goal: { [string]: any },
	style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?
)
	local tween = TweenService:Create(
		inst,
		TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
		goal
	)
	tween:Play()
	return tween
end

-- Anexo em coordenadas de mundo (preso ao Terrain).
function Lib.anchor(position: Vector3, lifetime: number?): Attachment
	local a = Instance.new("Attachment")
	a.Position = position
	a.Parent = Workspace.Terrain
	if lifetime then
		Debris:AddItem(a, lifetime)
	end
	return a
end

function Lib.beam(a0: Attachment, a1: Attachment, props: { [string]: any }): Beam
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Segments = 12
	for key, value in props do
		(beam :: any)[key] = value
	end
	beam.Parent = a0
	return beam
end

-- Desenho deitado no chao (circulo magico, anel, aviso): ImageLabel numa SurfaceGui que nao recebe
-- luz e brilha acima do limite do bloom. Fica 0,35 stud acima do chao para nao sumir na grama.
-- Gire/mova pela Part; anime cor/transparencia pela Image.
export type GroundDecal = { Part: Part, Image: ImageLabel }

function Lib.groundDecal(
	center: Vector3,
	size: number,
	texture: string,
	color: Color3,
	options: { Brightness: number?, Transparency: number?, Lift: number? }?
): GroundDecal
	local o = options or {}
	local part = Lib.part(
		Vector3.new(size, 0.05, size),
		color,
		CFrame.new(center + Vector3.new(0, o.Lift or 0.35, 0)),
		{ Transparency = 1 }
	)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.LightInfluence = 0
	gui.Brightness = o.Brightness or 2.5
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = math.clamp(512 / math.max(size, 1), 8, 64)
	gui.Parent = part
	local image = Instance.new("ImageLabel")
	image.AnchorPoint = Vector2.new(0.5, 0.5)
	image.Position = UDim2.fromScale(0.5, 0.5)
	image.Size = UDim2.fromScale(1, 1)
	image.BackgroundTransparency = 1
	image.Image = texture
	image.ImageColor3 = color
	image.ImageTransparency = o.Transparency or 0
	image.Parent = gui
	return { Part = part, Image = image }
end

local function seq(...: number): NumberSequence
	local values = { ... }
	if #values == 2 then
		return NumberSequence.new(values[1], values[2])
	end
	local keys = {}
	for i, v in values do
		table.insert(keys, NumberSequenceKeypoint.new((i - 1) / (#values - 1), v))
	end
	return NumberSequence.new(keys)
end
Lib.seq = seq

-- Presets de particula (Docs/03 §8, "Partículas base").
local PRESETS: { [string]: (Palette) -> { [string]: any } } = {
	-- Estrela de 4 pontas que gira e pisca.
	Star = function(p)
		return {
			Texture = Lib.Textures.Sparkle,
			Color = ColorSequence.new(p.Core, p.Halo),
			Size = seq(0.6, 0.9, 0),
			Transparency = seq(0, 0.2, 1),
			Lifetime = NumberRange.new(0.3, 0.6),
			Speed = NumberRange.new(6, 14),
			RotSpeed = NumberRange.new(-180, 180),
			Rotation = NumberRange.new(0, 360),
			Drag = 5,
		}
	end,
	-- Faisca com gravidade.
	Spark = function(p)
		return {
			Texture = Lib.Textures.Sparks,
			Color = ColorSequence.new(p.Core, p.Accent),
			Size = seq(0.35, 0),
			Transparency = seq(0, 1),
			Lifetime = NumberRange.new(0.3, 0.7),
			Speed = NumberRange.new(12, 26),
			Acceleration = Vector3.new(0, -45, 0),
			Drag = 1,
		}
	end,
	-- Brasa que sobe e esfria para vermelho.
	Ember = function(p)
		return {
			Texture = Lib.Textures.Sparkle,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, p.Core),
				ColorSequenceKeypoint.new(0.4, p.Halo),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 20, 10)),
			}),
			Size = seq(0.3, 0.2, 0),
			Transparency = seq(0, 0.3, 1),
			Lifetime = NumberRange.new(0.6, 1.2),
			Speed = NumberRange.new(3, 9),
			Acceleration = Vector3.new(0, 10, 0),
			Drag = 2,
		}
	end,
	-- Lingua de fogo animada (flipbook 8x8 branco, tingido: branca -> cor -> escura).
	Flame = function(p)
		return {
			Texture = TextureCatalog.FireWhite8,
			FlipbookLayout = Enum.ParticleFlipbookLayout.Grid8x8,
			FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, p.Core),
				ColorSequenceKeypoint.new(0.35, p.Halo),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(70, 15, 10)),
			}),
			Size = seq(1.8, 2.1, 1.4),
			Transparency = seq(0.05, 0.2, 1),
			Lifetime = NumberRange.new(0.35, 0.6),
			Speed = NumberRange.new(0.5, 2),
			Rotation = NumberRange.new(-15, 15),
		}
	end,
	-- Labareda pintada (flipbook 4x4 colorido): fogo "de verdade", sem tingir.
	Blaze = function(_)
		return {
			Texture = TextureCatalog.FireColor4,
			FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
			FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
			Color = ColorSequence.new(Color3.new(1, 1, 1)),
			Brightness = 2.2,
			Size = seq(2.2, 2.6),
			Transparency = seq(0, 0.1, 0.6),
			Lifetime = NumberRange.new(0.45, 0.7),
			Speed = NumberRange.new(0.5, 2.5),
			Acceleration = Vector3.new(0, 6, 0),
			Rotation = NumberRange.new(-10, 10),
		}
	end,
	-- Arco eletrico curto (pisca e some).
	Arc = function(p)
		return {
			Texture = TextureCatalog.ElectricArc,
			Color = ColorSequence.new(p.Core, p.Halo),
			Size = seq(1.6, 2.2),
			Transparency = seq(0, 0.3, 1),
			Lifetime = NumberRange.new(0.08, 0.16),
			Speed = NumberRange.new(0, 1),
			Rotation = NumberRange.new(0, 360),
		}
	end,
	-- Explosao radial de raios (um quadro grande).
	Zap = function(p)
		return {
			Texture = TextureCatalog.ElectricBurst,
			Color = ColorSequence.new(p.Core, p.Halo),
			Size = seq(3, 6),
			Transparency = seq(0, 1),
			Lifetime = NumberRange.new(0.15, 0.2),
			Speed = NumberRange.new(0, 0),
			Rotation = NumberRange.new(0, 360),
		}
	end,
	-- Anel deitado que cresce (onda de choque); deitado porque a velocidade e vertical.
	Ring = function(p)
		return {
			Texture = TextureCatalog.Ring,
			Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
			EmissionDirection = Enum.NormalId.Top,
			SpreadAngle = Vector2.zero,
			Color = ColorSequence.new(p.Core, p.Halo),
			Size = seq(0.5, 8),
			Transparency = seq(0, 1),
			Lifetime = NumberRange.new(0.35, 0.35),
			Speed = NumberRange.new(0.01, 0.01),
		}
	end,
	-- Fumaca animada (flipbook 4x4; translucida, NAO aditiva).
	Smoke = function(_)
		return {
			Texture = TextureCatalog.Smoke4,
			FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
			FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
			Color = ColorSequence.new(Color3.fromRGB(60, 52, 58), Color3.fromRGB(30, 28, 32)),
			LightEmission = 0,
			Brightness = 1,
			Size = seq(1, 3.5),
			Transparency = seq(0.5, 1),
			Lifetime = NumberRange.new(0.6, 1.2),
			Speed = NumberRange.new(1, 4),
			Acceleration = Vector3.new(0, 4, 0),
			RotSpeed = NumberRange.new(-40, 40),
			Rotation = NumberRange.new(0, 360),
			Drag = 2,
		}
	end,
	-- Luz que sobe em espiral (almas, fogos-fatuos, runas subindo).
	Wisp = function(p)
		return {
			Texture = Lib.Textures.Sparkle,
			Color = ColorSequence.new(p.Halo, p.Core),
			Size = seq(0.4, 0),
			Transparency = seq(0.1, 1),
			Lifetime = NumberRange.new(0.6, 1),
			Speed = NumberRange.new(1, 3),
			Acceleration = Vector3.new(0, 8, 0),
			SpreadAngle = Vector2.new(25, 25),
			RotSpeed = NumberRange.new(90, 270),
		}
	end,
	-- Brilho grande e unico (clarao).
	Glow = function(p)
		return {
			Texture = Lib.Textures.Glow,
			Color = ColorSequence.new(p.Core, p.Halo),
			Size = seq(4, 0),
			Transparency = seq(0.1, 1),
			Lifetime = NumberRange.new(0.25, 0.25),
			Speed = NumberRange.new(0, 0),
		}
	end,
}

function Lib.emitter(parent: Instance, preset: string, palette: Palette, overrides: { [string]: any }?): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Brightness = 3.5 -- acima do limite do bloom: a magia brilha, o cenario nao
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rate = 0
	for key, value in PRESETS[preset](palette) do
		(e :: any)[key] = value
	end
	if overrides then
		for key, value in overrides do
			(e :: any)[key] = value
		end
	end
	e.Parent = parent
	return e
end

-- Rajada unica de particulas num ponto do mundo.
function Lib.burst(position: Vector3, preset: string, palette: Palette, count: number, overrides: { [string]: any }?)
	local anchor = Lib.anchor(position, 2)
	local e = Lib.emitter(anchor, preset, palette, overrides)
	e:Emit(count)
end

-- Ponto de saida das magias: a gema na pose de conjuracao. Mesma conta do servidor
-- (Shared/StaffPose), entao o efeito nasce exatamente onde o cajado fica ao conjurar.
function Lib.muzzleOf(model: Instance?, fallback: Vector3): Vector3
	local root = model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root and model and model:FindFirstChild("ArcanumStaff") then
		return StaffPose.gemWorld(root.CFrame, "Cast")
	end
	return fallback
end

-- A grama alta do Terrain cobre qualquer efeito rente ao chao. Para efeitos de chao que precisam
-- aparecer (lava), troca a grama por outro material SO NESTE CLIENTE enquanto o efeito dura e depois
-- devolve. Conta por bloco de voxel: efeitos sobrepostos nao devolvem a grama antes da hora.
local swapped: { [string]: number } = {}

function Lib.swapGround(position: Vector3, radius: number, material: Enum.Material, duration: number)
	local ok, region = pcall(function()
		return Region3.new(position - Vector3.new(radius, 4, radius), position + Vector3.new(radius, 2, radius))
			:ExpandToGrid(4)
	end)
	if not ok then
		return
	end
	local key = tostring(region.CFrame.Position) .. "|" .. tostring(region.Size) .. "|" .. material.Name
	local count = swapped[key] or 0
	if count == 0 then
		pcall(function()
			Workspace.Terrain:ReplaceMaterial(region, 4, Enum.Material.Grass, material)
		end)
	end
	swapped[key] = count + 1
	task.delay(duration, function()
		local left = (swapped[key] or 1) - 1
		if left <= 0 then
			swapped[key] = nil
			pcall(function()
				Workspace.Terrain:ReplaceMaterial(region, 4, material, Enum.Material.Grass)
			end)
		else
			swapped[key] = left
		end
	end)
end

-- Chao logo abaixo de um ponto (ignora o proprio modelo e os efeitos). Sem chao: 2,8 studs abaixo.
function Lib.groundBelow(position: Vector3, ignore: Instance?): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = if ignore then { Lib.folder(), ignore } else { Lib.folder() }
	local hit = Workspace:Raycast(position, Vector3.new(0, -40, 0), params)
	return if hit then hit.Position else position - Vector3.new(0, 2.8, 0)
end

function Lib.rootPosition(model: Instance?): Vector3?
	local root = model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
	return if root then root.Position else nil
end

return Lib
