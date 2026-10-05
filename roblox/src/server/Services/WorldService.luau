--!strict
-- Monta o mapa de teste (Sandbox) por codigo se ele nao existir no lugar. Assim o projeto roda
-- so com `rojo serve`, sem nenhum arquivo binario. Quando houver mapa feito no Studio, basta ter
-- um Model/Folder "ArcanumWorld" no Workspace com uma pasta "EnemySpawns" (Parts com o
-- atributo EnemyRow = nome da linha em Data/Enemies.csv).

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local WorldService = {}

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	return p
end

local function spawnPoint(parent: Instance, rowName: string, position: Vector3)
	local p = part({
		Name = "Spawn_" .. rowName,
		Size = Vector3.new(2, 1, 2),
		Position = position,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
	p:SetAttribute("EnemyRow", rowName)
	p.Parent = parent
end

local function buildSandbox(): Folder
	-- O template "Baseplate" do Studio briga visualmente com o nosso chao.
	local baseplate = Workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end

	local world = Instance.new("Folder")
	world.Name = "ArcanumWorld"

	part({
		Name = "Ground",
		Size = Vector3.new(700, 4, 700),
		Position = Vector3.new(0, -2, 0),
		Material = Enum.Material.Grass,
		Color = Color3.fromRGB(110, 140, 84),
	}).Parent =
		world

	-- Pilares e rochas para testar cobertura, mira e colisao de projeteis.
	local rng = Random.new(42)
	for i = 1, 14 do
		local angle = (i / 14) * math.pi * 2
		local radius = rng:NextNumber(60, 160)
		part({
			Name = "Rock" .. i,
			Size = Vector3.new(rng:NextNumber(6, 14), rng:NextNumber(6, 22), rng:NextNumber(6, 14)),
			Position = Vector3.new(math.cos(angle) * radius, 4, math.sin(angle) * radius),
			Material = Enum.Material.Slate,
			Color = Color3.fromRGB(120, 116, 130),
		}).Parent =
			world
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.Position = Vector3.new(0, 0.5, 40)
	spawn.Material = Enum.Material.Marble
	spawn.Color = Color3.fromRGB(155, 92, 255)
	spawn.Neutral = true
	spawn.Parent = world

	local spawns = Instance.new("Folder")
	spawns.Name = "EnemySpawns"
	spawns.Parent = world
	-- Grupo de 5 Ossomantes juntos (bom para Corrente em Cadeia), slimes, um bulbo e um golem.
	for i = 0, 4 do
		spawnPoint(spawns, "SkeletonMage", Vector3.new(-16 + i * 8, 3, -30 - (i % 2) * 6))
	end
	for i = 0, 2 do
		spawnPoint(spawns, "ArcaneSlime", Vector3.new(50 + i * 8, 3, -20))
	end
	spawnPoint(spawns, "StormBloater", Vector3.new(-50, 3, -20))
	spawnPoint(spawns, "CrystalGolem", Vector3.new(0, 3, -120))

	world.Parent = Workspace
	return world
end

local function setupLighting()
	-- Visual estilizado: cores quentes, bloom forte para as magias, ambientes menos saturados.
	Lighting.ClockTime = 16.5
	Lighting.Brightness = 2.2
	Lighting.OutdoorAmbient = Color3.fromRGB(120, 115, 150)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.3

	local function ensure(className: string, name: string): Instance
		local existing = Lighting:FindFirstChild(name)
		if existing then
			return existing
		end
		local inst = Instance.new(className)
		inst.Name = name
		inst.Parent = Lighting
		return inst
	end

	local atmosphere = ensure("Atmosphere", "ArcanumAtmosphere") :: Atmosphere
	atmosphere.Density = 0.32
	atmosphere.Haze = 1.4
	atmosphere.Color = Color3.fromRGB(214, 196, 230)
	atmosphere.Decay = Color3.fromRGB(110, 90, 140)

	local bloom = ensure("BloomEffect", "ArcanumBloom") :: BloomEffect
	bloom.Intensity = 1.1
	bloom.Size = 28
	bloom.Threshold = 0.95

	local grading = ensure("ColorCorrectionEffect", "ArcanumGrading") :: ColorCorrectionEffect
	grading.Saturation = -0.15
	grading.Contrast = 0.08
	grading.TintColor = Color3.fromRGB(255, 244, 232)
end

function WorldService.getWorld(): Instance
	return Workspace:FindFirstChild("ArcanumWorld") or buildSandbox()
end

function WorldService.init()
	WorldService.getWorld()
	setupLighting()
end

return WorldService
