--!strict
-- Monta o mapa de teste (Sandbox) por codigo se ele nao existir no lugar. Assim o projeto roda
-- so com `rojo serve`, sem nenhum arquivo binario. Quando houver mapa feito no Studio, basta ter
-- um Model/Folder "ArcanumWorld" no Workspace com uma pasta "EnemySpawns" (Parts com o
-- atributo EnemyRow = nome da linha em Data/Enemies.csv).
--
-- Visual: Terrain com grama decorativa e colinas suaves, rochas, arvores estilizadas, ruinas
-- arcanas com pilares e arco, cristais de mana brilhando; iluminacao quente com sombras frias.

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local WorldService = {}

local GROUND_Y = 0
local rng = Random.new(1337)

local function part(props: { [string]: any }, parent: Instance): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = parent
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
	}, parent)
	p:SetAttribute("EnemyRow", rowName)
end

-- Arvore estilizada: tronco levemente torto + copa de 3 bolas (formas grandes e legiveis).
local function tree(parent: Instance, base: Vector3, scale: number)
	local model = Instance.new("Model")
	model.Name = "Tree"
	local trunkHeight = 9 * scale
	local lean = CFrame.Angles(math.rad(rng:NextNumber(-6, 6)), 0, math.rad(rng:NextNumber(-6, 6)))
	local trunkCf = CFrame.new(base) * lean * CFrame.new(0, trunkHeight / 2, 0)
	part({
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(trunkHeight, 1.6 * scale, 1.6 * scale),
		CFrame = trunkCf * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Wood,
		Color = Color3.fromRGB(96, 70, 56),
	}, model)
	local top = (trunkCf * CFrame.new(0, trunkHeight / 2, 0)).Position
	local leafColors = { Color3.fromRGB(86, 128, 72), Color3.fromRGB(104, 146, 80), Color3.fromRGB(74, 112, 70) }
	for i = 1, 3 do
		local offset = Vector3.new(rng:NextNumber(-2.5, 2.5), rng:NextNumber(0, 2.5), rng:NextNumber(-2.5, 2.5)) * scale
		local size = rng:NextNumber(7, 10) * scale
		part({
			Name = "Leaves",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * size,
			Position = top + offset,
			Material = Enum.Material.Grass,
			Color = leafColors[i],
			CastShadow = true,
		}, model)
	end
	model.Parent = parent
end

-- Cristal de mana: prismas Neon inclinados com luz suave.
local function crystal(parent: Instance, base: Vector3, color: Color3)
	local model = Instance.new("Model")
	model.Name = "ManaCrystal"
	for i = 1, 4 do
		local height = rng:NextNumber(2.5, 6)
		local tilt = CFrame.Angles(
			math.rad(rng:NextNumber(-25, 25)),
			math.rad(rng:NextNumber(0, 360)),
			math.rad(rng:NextNumber(-25, 25))
		)
		local cf = CFrame.new(base) * tilt * CFrame.new(0, height / 2 - 0.5, 0)
		local shard = part({
			Name = "Shard",
			Size = Vector3.new(0.9, height, 0.9),
			CFrame = cf * CFrame.Angles(0, math.rad(45), 0),
			Material = if i == 1 then Enum.Material.Neon else Enum.Material.Glass,
			Color = color,
			Transparency = if i == 1 then 0.1 else 0.35,
			CastShadow = false,
		}, model)
		if i == 1 then
			local light = Instance.new("PointLight")
			light.Color = color
			light.Range = 14
			light.Brightness = 1.4
			light.Parent = shard
		end
	end
	model.Parent = parent
end

-- Ruina arcana: anel de pilares quebrados ao redor de um piso runico, com um arco.
local function ruin(parent: Instance, center: Vector3)
	local model = Instance.new("Model")
	model.Name = "ArcaneRuin"
	local stone = Color3.fromRGB(150, 146, 160)
	part({
		Name = "Floor",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, 26, 26),
		CFrame = CFrame.new(center + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Cobblestone,
		Color = Color3.fromRGB(130, 126, 140),
	}, model)
	-- Circulo runico gravado (anel de blocos Neon fracos).
	for i = 1, 24 do
		local angle = (i / 24) * math.pi * 2
		local pos = center + Vector3.new(math.cos(angle) * 8, 0.95, math.sin(angle) * 8)
		part({
			Name = "Rune",
			Size = Vector3.new(0.4, 0.1, 1.6),
			CFrame = CFrame.lookAt(pos, pos + Vector3.new(-math.sin(angle), 0, math.cos(angle))),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(155, 92, 255),
			Transparency = 0.35,
			CastShadow = false,
		}, model)
	end
	for i = 1, 6 do
		local angle = (i / 6) * math.pi * 2 + 0.3
		local height = if i % 3 == 0 then 4 else rng:NextNumber(8, 15)
		local pos = center + Vector3.new(math.cos(angle) * 12, height / 2 + 0.8, math.sin(angle) * 12)
		part({
			Name = "Pillar",
			Size = Vector3.new(2.6, height, 2.6),
			CFrame = CFrame.new(pos) * CFrame.Angles(0, angle, math.rad(rng:NextNumber(-4, 4))),
			Material = Enum.Material.Limestone,
			Color = stone,
		}, model)
		part({
			Name = "Capital",
			Size = Vector3.new(3.4, 0.8, 3.4),
			CFrame = CFrame.new(pos + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, angle, 0),
			Material = Enum.Material.Limestone,
			Color = stone:Lerp(Color3.new(1, 1, 1), 0.15),
		}, model)
	end
	-- Arco
	for _, x in { -5, 5 } do
		part({
			Name = "ArchLeg",
			Size = Vector3.new(2.4, 12, 2.4),
			Position = center + Vector3.new(x, 6.8, -12),
			Material = Enum.Material.Limestone,
			Color = stone,
		}, model)
	end
	part({
		Name = "ArchTop",
		Size = Vector3.new(13, 2.2, 2.8),
		Position = center + Vector3.new(0, 13.6, -12),
		Material = Enum.Material.Limestone,
		Color = stone,
	}, model)
	model.Parent = parent
end

local function buildTerrain()
	local terrain = Workspace.Terrain
	-- Grama 3D animada pelo vento. Em algumas versoes a propriedade nao e alteravel por script:
	-- nesse caso ligue em Workspace > Terrain > Decoration no Studio.
	local ok = pcall(function()
		(terrain :: any).Decoration = true
	end)
	if not ok then
		warn("[World] Terrain.Decoration nao pode ser ligado por script; ligue no Studio (Terrain > Decoration).")
	end
	terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(106, 140, 82))
	terrain:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(110, 92, 72))
	terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(122, 118, 132))
	terrain:FillBlock(CFrame.new(0, GROUND_Y - 6, 0), Vector3.new(900, 12, 900), Enum.Material.Grass)
	-- Colinas suaves na borda (enquadram a arena sem bloquear a mira no centro).
	for i = 1, 16 do
		local angle = (i / 16) * math.pi * 2
		local radius = rng:NextNumber(230, 320)
		terrain:FillBall(
			Vector3.new(math.cos(angle) * radius, GROUND_Y - 18, math.sin(angle) * radius),
			rng:NextNumber(45, 70),
			Enum.Material.Grass
		)
	end
	-- Trilha de terra ate a ruina.
	terrain:FillBlock(CFrame.new(0, GROUND_Y - 0.6, -20), Vector3.new(10, 1.4, 120), Enum.Material.Ground)
	-- Rochas
	for i = 1, 22 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(55, 190)
		local center = Vector3.new(math.cos(angle) * radius, GROUND_Y + 1, math.sin(angle) * radius)
		terrain:FillBall(center, rng:NextNumber(3, 7), if i % 3 == 0 then Enum.Material.Slate else Enum.Material.Rock)
	end
end

local function buildSandbox(): Folder
	-- O template "Baseplate" do Studio briga visualmente com o terreno.
	local baseplate = Workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end

	local world = Instance.new("Folder")
	world.Name = "ArcanumWorld"

	buildTerrain()

	local scenery = Instance.new("Folder")
	scenery.Name = "Scenery"
	scenery.Parent = world
	ruin(scenery, Vector3.new(0, GROUND_Y, -95))
	for i = 1, 26 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(70, 210)
		tree(
			scenery,
			Vector3.new(math.cos(angle) * radius, GROUND_Y, math.sin(angle) * radius),
			rng:NextNumber(0.8, 1.3)
		)
	end
	local crystalColors = { Color3.fromRGB(155, 92, 255), Color3.fromRGB(63, 169, 255), Color3.fromRGB(61, 255, 138) }
	for i = 1, 9 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(35, 140)
		crystal(
			scenery,
			Vector3.new(math.cos(angle) * radius, GROUND_Y, math.sin(angle) * radius),
			crystalColors[i % 3 + 1]
		)
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 0.6, 10)
	spawn.Position = Vector3.new(0, GROUND_Y + 0.3, 40)
	spawn.Material = Enum.Material.Marble
	spawn.Color = Color3.fromRGB(196, 182, 222)
	spawn.Neutral = true
	spawn.Parent = world

	local spawns = Instance.new("Folder")
	spawns.Name = "EnemySpawns"
	spawns.Parent = world
	-- Grupo de 5 Ossomantes juntos (bom para Corrente em Cadeia), slimes, um bulbo e o golem na ruina.
	for i = 0, 4 do
		spawnPoint(spawns, "SkeletonMage", Vector3.new(-16 + i * 8, GROUND_Y + 3, -30 - (i % 2) * 6))
	end
	for i = 0, 2 do
		spawnPoint(spawns, "ArcaneSlime", Vector3.new(50 + i * 8, GROUND_Y + 3, -20))
	end
	spawnPoint(spawns, "StormBloater", Vector3.new(-50, GROUND_Y + 3, -20))
	spawnPoint(spawns, "CrystalGolem", Vector3.new(0, GROUND_Y + 3, -95))

	world.Parent = Workspace
	return world
end

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

local function setupLighting()
	-- Fim de tarde: luz quente, sombras frias (Docs/03), bloom forte para as magias.
	Lighting.ClockTime = 16.8
	Lighting.GeographicLatitude = 35
	Lighting.Brightness = 2.6
	Lighting.Ambient = Color3.fromRGB(60, 56, 82)
	Lighting.OutdoorAmbient = Color3.fromRGB(118, 112, 150)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 226, 184)
	Lighting.EnvironmentDiffuseScale = 0.7
	Lighting.EnvironmentSpecularScale = 0.4
	Lighting.ShadowSoftness = 0.25

	local atmosphere = ensure("Atmosphere", "ArcanumAtmosphere") :: Atmosphere
	atmosphere.Density = 0.3
	atmosphere.Offset = 0.15
	atmosphere.Haze = 1.6
	atmosphere.Glare = 0.4
	atmosphere.Color = Color3.fromRGB(222, 202, 236)
	atmosphere.Decay = Color3.fromRGB(120, 96, 156)

	local bloom = ensure("BloomEffect", "ArcanumBloom") :: BloomEffect
	bloom.Intensity = 1.2
	bloom.Size = 32
	bloom.Threshold = 0.92

	local grading = ensure("ColorCorrectionEffect", "ArcanumGrading") :: ColorCorrectionEffect
	grading.Saturation = -0.12
	grading.Contrast = 0.12
	grading.Brightness = 0.02
	grading.TintColor = Color3.fromRGB(255, 244, 232)

	local rays = ensure("SunRaysEffect", "ArcanumSunRays") :: SunRaysEffect
	rays.Intensity = 0.06
	rays.Spread = 0.6

	local depth = ensure("DepthOfFieldEffect", "ArcanumDepth") :: DepthOfFieldEffect
	depth.FarIntensity = 0.12
	depth.FocusDistance = 60
	depth.InFocusRadius = 80
	depth.NearIntensity = 0
end

function WorldService.getWorld(): Instance
	return Workspace:FindFirstChild("ArcanumWorld") or buildSandbox()
end

function WorldService.init()
	WorldService.getWorld()
	setupLighting()
end

return WorldService
