-- Teste de fumaca dos efeitos: cria cada efeito com instancias reais do @lune/roblox, que
-- valida nomes e tipos das propriedades (pega erros que so apareceriam no Studio).
-- Metodos do motor (Emit, tweens, Debris) viram no-op.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local process = require("@lune/process")
-- Rodar de dentro de roblox/: lune run tests/smoke
local ROOT = process.cwd:gsub("[/\\]$", "") .. "/src/"
local noop = function() end
local connection = { Disconnect = noop }
local signal = {
	Connect = function()
		return connection
	end,
}

local dataModel = roblox.Instance.new("DataModel")
local workspaceFolder = dataModel:GetService("Workspace")
local terrain = roblox.Instance.new("Terrain")
terrain.Parent = workspaceFolder
local camera = roblox.Instance.new("Camera")
camera.CFrame = roblox.CFrame.new(0, 10, 20)
camera.Parent = workspaceFolder
workspaceFolder.CurrentCamera = camera

local services = {
	TweenService = {
		Create = function(_, inst, _, goal)
			for k, v in goal do
				inst[k] = v
			end -- aplica direto: valida nomes/tipos das propriedades
			return { Play = noop }
		end,
	},
	Debris = { AddItem = noop },
	RunService = { RenderStepped = signal, Heartbeat = signal, Stepped = signal },
	Players = {
		LocalPlayer = {},
		GetPlayers = function()
			return {}
		end,
	},
	Workspace = workspaceFolder,
}

local modules = {}
local function env()
	local e = {}
	for _, name in
		{
			"Instance",
			"CFrame",
			"Vector3",
			"Vector2",
			"Color3",
			"Enum",
			"ColorSequence",
			"ColorSequenceKeypoint",
			"NumberSequence",
			"NumberSequenceKeypoint",
			"NumberRange",
			"UDim",
			"UDim2",
			"TweenInfo",
		}
	do
		e[name] = roblox[name]
	end
	e.TweenInfo = e.TweenInfo or {
		new = function()
			return {}
		end,
	}
	for k, v in
		{
			math = math,
			table = table,
			string = string,
			print = print,
			pairs = pairs,
			typeof = typeof,
			tostring = tostring,
			setmetatable = setmetatable,
			assert = assert,
			os = os,
			error = error,
		}
	do
		e[k] = v
	end
	-- task.wait encerra o laco atual: loops "while true" dos controladores nao travam o teste.
	e.task = {
		delay = function(_, fn, ...)
			local ok, err = pcall(fn, ...)
			if not ok and not tostring(err):find("__fim_do_laco") then
				error(err)
			end
		end,
		spawn = function(fn, ...)
			local ok, err = pcall(fn, ...)
			if not ok and not tostring(err):find("__fim_do_laco") then
				error(err)
			end
		end,
		wait = function()
			error("__fim_do_laco")
		end,
	}
	e.game = {
		GetService = function(_, name)
			return services[name]
		end,
	}
	e.require = function(ref)
		return modules[ref]
	end
	return e
end
local function load(path: string, scriptRef)
	local e = env()
	e.script = scriptRef
	e.EMIT = noop
	-- Raycast nao existe no Lune: chao ausente (efeitos que dependem dele simplesmente nao aparecem).
	e.RAYCAST = function()
		return nil
	end
	e.RaycastParams = {
		new = function()
			return {}
		end,
	}
	e.TERRAIN = { FillBlock = noop, FillBall = noop, SetMaterialColor = noop }
	e.SIGNAL = signal
	e.VELOCITY = function()
		return roblox.Vector3.zero
	end
	e.SIGNAL_OF = function()
		return signal
	end
	e.Random = {
		new = function()
			return {
				NextNumber = function(_, a, b)
					return a + math.random() * (b - a)
				end,
			}
		end,
	}
	local source = fs.readFile(ROOT .. path)
	source = source:gsub("([%w_]+):Emit%(", "EMIT(%1, ")
	source = source:gsub("Workspace:Raycast%(", "RAYCAST(")
	if path:find("WorldService") then
		source = source:gsub("Workspace%.Terrain", "TERRAIN") -- so o mundo usa os metodos do Terrain
	end
	source = source:gsub(":WaitForChild%(", ":FindFirstChild(")
	source = source:gsub("([%w_]+):GetAttributeChangedSignal%b()", "SIGNAL_OF(%1)")
	-- O LocalPlayer simulado e uma Folder: sem personagem nem CharacterAdded.
	-- Velocidade de montagem nao e simulada no Lune: criatura parada.
	if path:find("Creatures") then
		source = source:gsub("([%w_]+)%.AssemblyLinearVelocity", "VELOCITY(%1)")
	end
	-- Som nao toca no Lune: valida so as propriedades do Sound.
	if path:find("Vfx/Audio") then
		source = source:gsub("sound:Play%(%)", "")
		source = source:gsub("sound%.Ended", "SIGNAL")
	end
	-- Eventos de botao nao existem nas instancias do Lune.
	if path:find("GrimoireController") then
		for _, event in { "Activated", "MouseEnter", "MouseLeave" } do
			source = source:gsub("[%w_%.]+%." .. event .. ":Connect", "SIGNAL:Connect")
		end
		source = source:gsub("camera%.ViewportSize", "Vector2.new(1920, 1080)") -- tela nao simulada
	end
	if path:find("HudController") then
		source = source:gsub("player%.CharacterAdded", "SIGNAL")
		source = source:gsub("player%.Character%f[^%w_]", "nil")
	end
	return luau.load(source, { environment = e })()
end

-- Arvore virtual: script.Parent.X -> chaves
local Shared = {
	Schools = "Schools",
	StaffPose = "StaffPose",
	SoundCatalog = "SoundCatalog",
	TextureCatalog = "TextureCatalog",
}
services.ReplicatedStorage = { Shared = Shared }
services.SoundService = dataModel:GetService("SoundService")
modules.Schools = load("shared/Schools.luau", {})
modules.StaffPose = load("shared/StaffPose.luau", {})
modules.SoundCatalog = load("shared/SoundCatalog.luau", {})
modules.TextureCatalog = load("shared/TextureCatalog.luau", {})

local vfxScript = {
	Parent = {
		Lib = "Lib",
		Effects = "Effects",
		Lightning = "Lightning",
		MotorOverlay = "MotorOverlay",
		Audio = "Audio",
		SpellFx = "SpellFx",
	},
}
modules.Lib = load("client/Vfx/Lib.luau", vfxScript)
modules.Effects = load("client/Vfx/Effects.luau", vfxScript)
modules.Lightning = load("client/Vfx/Lightning.luau", vfxScript)
modules.Audio = load("client/Vfx/Audio.luau", vfxScript)
modules.SpellFx = load("client/Vfx/SpellFx.luau", vfxScript)
for name in modules.SoundCatalog do
	modules.Audio.play(name, if #name % 2 == 0 then roblox.Vector3.new(0, 2, 0) else nil)
end
local Projectiles = load("client/Vfx/Projectiles.luau", vfxScript)
local LifeStream = load("client/Vfx/LifeStream.luau", vfxScript)
local Numbers = load("client/Vfx/Numbers.luau", vfxScript)

local Lib, Effects, Lightning = modules.Lib, modules.Effects, modules.Lightning
-- Lune nao deriva Part.Position do CFrame; no Roblox real isso funciona.
Lib.rootPosition = function(m)
	local r = m and m:FindFirstChild("HumanoidRootPart")
	return r and r.CFrame.Position
end
local V = roblox.Vector3
for school in modules.Schools do
	local palette = Lib.palette(school)
	for _, preset in { "Star", "Spark", "Ember", "Flame", "Smoke", "Wisp", "Glow" } do
		Lib.burst(V.new(0, 5, 0), preset, palette, 3)
	end
	Effects.flash(V.new(0, 5, 0), palette, 2, true)
	Effects.shockwave(V.new(0, 0, 0), palette, 6)
	Effects.dangerZone(V.new(0, 0, 0), 5, 1, palette.Core)()
	Effects.dangerLine(V.new(0, 0, 0), V.new(20, 0, 5), 3, 1, palette.Core)()
	Effects.crystalSpikes(V.new(0, 0, 0), V.new(20, 0, 5), 3, palette)
	Effects.runeCircle(V.new(0, 0, 0), palette, 3, 0.5)
	Lightning.bolt(V.new(0, 5, 0), V.new(30, 5, 10), palette)
	Lightning.braid(V.new(0, 5, 0), V.new(20, 5, 0), palette, 7, 0.12)
end

local fakeCaster = roblox.Instance.new("Model")
local root = roblox.Instance.new("Part")
root.Name = "HumanoidRootPart"
root.CFrame = roblox.CFrame.new(0, 3, 0)
root.Size = V.new(2, 2, 1)
root.Parent = fakeCaster
for _, spellId in
	{ "Fireball", "ArcaneMissile", "MagmaLance", "WanderingSouls", "RoseOfLaments", "BallLightning", "Outra" }
do
	Projectiles.spawn({
		Id = spellId,
		SpellId = spellId,
		Position = V.new(0, 5, 0),
		Velocity = V.new(0, 0, -30),
		Speed = 30,
		School = "Fire",
		Caster = fakeCaster,
	})
	Projectiles.finish({ Id = spellId, Position = V.new(0, 5, -20), School = "Fire", Radius = 0 })
end
LifeStream.play(V.new(10, 5, 0), fakeCaster, Lib.palette("Necromancy"))

-- Detalhes de cada magia (Vfx/SpellFx).
local SpellFx = modules.SpellFx
for _, spellId in { "Spark", "Fireball", "ArcaneMissile", "LifeDrain", "SummonedBolt", "CrimsonSpikes", "MagmaLance" } do
	SpellFx.flourish(spellId, fakeCaster, Lib.palette("Fire"), V.new(1, 4, -2))
end
SpellFx.lavaPool(V.new(0, 0, 0), 7, 4, 12345)
SpellFx.residueArcs(V.new(0, 3, -10), Lib.palette("Electricity"), 0.6)
SpellFx.fireGround(V.new(0, 3, -10), Lib.palette("Fire"), 3, 1.5)
SpellFx.runeBurst(V.new(0, 3, -10), Lib.palette("Energy"))
SpellFx.chainNode(V.new(0, 3, -10), Lib.palette("Electricity"))
SpellFx.healRing(fakeCaster, Lib.palette("Necromancy"))
SpellFx.stormWarn(V.new(0, 0, -20), 10, 0.35, Lib.palette("Electricity"))
SpellFx.groundCrackle(V.new(0, 0, -20), 10, Lib.palette("Electricity"), 1)
SpellFx.flamePillars(V.new(0, 0, 0), 18, Lib.palette("Fire"))
SpellFx.arcaneDome(V.new(0, 3, 0), V.new(0, 0, 0), 21, Lib.palette("Energy"), { V.new(5, 3, 0) })
SpellFx.bloodSpikes(V.new(0, 0, 0), V.new(0, 0, -30), 10, Lib.palette("Blood"))
print("Magias (detalhes): ok")

-- Grimorio completo: zonas, efeitos instantaneos e auras dos estados novos.
local ZoneFx = load("client/Vfx/ZoneFx.luau", vfxScript)
local StrikeFx = load("client/Vfx/StrikeFx.luau", vfxScript)
for _, mode in { "Static", "Wall", "Vortex", "Singularity", "Rain", "Hourglass" } do
	local zone = {
		Id = mode,
		Mode = mode,
		Position = V.new(0, 0, -20),
		Radius = 14,
		Duration = 2,
		School = "Fire",
		Caster = fakeCaster,
		From = V.new(-10, 0, -20),
		To = V.new(10, 0, -20),
	}
	ZoneFx.open(zone)
	ZoneFx.close(zone)
end
ZoneFx.portal({
	Id = "p",
	A = V.new(0, 0, 0),
	B = V.new(0, 0, -40),
	Facing = V.new(0, 0, -1),
	Duration = 5,
	School = "Energy",
})
ZoneFx.closePortal("p")
ZoneFx.chain(fakeCaster, fakeCaster, 2, Lib.palette("Blood"))
ZoneFx.crown(fakeCaster, 1, Lib.palette("Electricity"))
assert(ZoneFx.crownTop(fakeCaster), "coroa sem topo")
local P = Lib.palette
for _, mode in { "Storm", "Stars" } do
	StrikeFx.barrageStart({ Mode = mode, Position = V.new(0, 0, -30), Radius = 28, Duration = 3, School = "Energy" })
	StrikeFx.barrageHit({ Mode = mode, Position = V.new(3, 0, -30), Radius = 7, School = "Energy" })
end
StrikeFx.meteorWarn({ Position = V.new(0, 0, -30), Radius = 21, Duration = 1.2, School = "Fire" })
StrikeFx.meteorImpact({ Position = V.new(0, 0, -30), Radius = 21, School = "Fire" }, SpellFx.fireGround)
StrikeFx.verdictWarn({ Position = V.new(0, 0, -30), Radius = 10, Duration = 1.7, School = "Fire" })
StrikeFx.verdict({ Position = V.new(0, 0, -30), Radius = 10, School = "Fire" })
StrikeFx.arcaneBeam(V.new(0, 4, 0), V.new(0, 4, -30), P("Energy"), true)
StrikeFx.lanceCharge(V.new(0, 4, 0), 1.2, P("Energy"))
StrikeFx.firmamentLance(V.new(0, 4, 0), V.new(0, 4, -150), P("Energy"))
StrikeFx.bloodSlash(fakeCaster, V.new(0, 0, -1), 15, P("Blood"))
StrikeFx.summon(V.new(0, 0, 0), true, P("Necromancy"))
StrikeFx.army(V.new(0, 0, 0), P("Necromancy"))
StrikeFx.deathTouch(fakeCaster, fakeCaster, P("Necromancy"))
StrikeFx.curse({ Position = V.new(0, 0, 0), Radius = 14, School = "Necromancy" })
StrikeFx.rose(V.new(0, 0, 0), P("Necromancy"))
StrikeFx.prison(V.new(0, 0, -10), 7, 5, P("Energy"))
StrikeFx.hook(fakeCaster, fakeCaster, V.new(0, 3, -20), P("Blood"))
StrikeFx.hemorrhage(V.new(0, 3, -10), 18, P("Blood"))
StrikeFx.miss(V.new(0, 3, -10), P("Blood"))
StrikeFx.ritual(fakeCaster, V.new(0, 3, 0), 21, P("Blood"))
StrikeFx.pact(fakeCaster, { fakeCaster }, P("Blood"))
StrikeFx.lightningStep(V.new(0, 3, 0), V.new(0, 3, -28), P("Electricity"))
StrikeFx.orbShock(V.new(0, 3, 0), { V.new(5, 3, 0), V.new(-5, 3, 0) }, P("Electricity"))
StrikeFx.crownBolt(V.new(0, 7, 0), V.new(10, 3, 0), P("Electricity"))
Projectiles.freeze("Fireball", 2)
local Auras = load("client/Vfx/Auras.luau", vfxScript)
local auraRoot = roblox.Instance.new("Part")
auraRoot.Name = "HumanoidRootPart"
auraRoot.Parent = workspaceFolder
assert(Auras.debugBuildAll(auraRoot) >= 10, "faltam auras de estado")
print("Grimorio completo (visual): ok")
local head = roblox.Instance.new("Part")
head.Name = "Head"
head.CFrame = roblox.CFrame.new(0, 5, 0)
head.Parent = fakeCaster
Numbers.heal(fakeCaster, 2.5)
Numbers.damage(fakeCaster, 6, Lib.palette("Fire"), false)
Numbers.label(fakeCaster, "INTERROMPIDO!", roblox.Color3.new(1, 0.8, 0.3))
Effects.afterimage(fakeCaster, roblox.Color3.new(0.6, 0.85, 1))
Effects.stunStars(fakeCaster, Lib.palette("Energy"), 1)
assert(Lib.groundBelow(V.new(0, 10, 0), nil).Y < 10, "groundBelow sem chao deve descer")

-- Cajado: monta todos os estilos e confere a gema contra Shared/StaffPose.
local StaffPose = modules.StaffPose
local StaffBuilder = load("server/Combat/StaffBuilder.luau", {})
for _, school in { "Electricity", "Fire", "Energy", "Necromancy", "Blood", "Default" } do
	local staff = StaffBuilder.build(school, roblox.Color3.new(1, 0, 1))
	local gem = staff:FindFirstChild("Gem")
	assert(staff.PrimaryPart and staff.PrimaryPart.Name == "Root", "PrimaryPart deve ser Root")
	assert(math.abs(gem.CFrame.Position.X - StaffPose.GEM_DISTANCE) < 1e-3, "gema fora de GEM_DISTANCE")
	assert(staff.Root:FindFirstChild("GripPoint"), "falta GripPoint")
	-- Toda peca presa a raiz por Weld com C0 explicito (WeldConstraint desmontava o cajado).
	for _, part in staff:GetChildren() do
		if part:IsA("BasePart") and part.Name ~= "Root" then
			local weld = part:FindFirstChildWhichIsA("Weld")
			assert(weld and weld.Part0 == staff.Root, part.Name .. " sem Weld para a Root")
			assert(not part:FindFirstChildWhichIsA("WeldConstraint"), part.Name .. " usa WeldConstraint")
		end
	end
	staff.Parent = workspaceFolder
end
local castGem = StaffPose.gemWorld(roblox.CFrame.new(), "Cast")
local idleGem = StaffPose.gemWorld(roblox.CFrame.new(), "Idle")
-- Na conjuracao: a frente (-Z), a direita (+X) e na altura do ombro (raiz do R15 ~3 studs do chao).
assert(
	castGem.Z < -1.5 and castGem.X > 0.3 and castGem.Y > 1.5 and castGem.Y < 3,
	"gema da pose Cast fora do lugar: " .. tostring(castGem)
)
assert(idleGem.Y > 1.5 and idleGem.Y < 3.5, "gema da pose Idle fora do lugar: " .. tostring(idleGem))
print(
	string.format(
		"Cajado: gema Cast (%.2f, %.2f, %.2f)  Idle (%.2f, %.2f, %.2f)",
		castGem.X,
		castGem.Y,
		castGem.Z,
		idleGem.X,
		idleGem.Y,
		idleGem.Z
	)
)

-- Mundo (terreno simulado; pecas, luzes e efeitos de iluminacao reais).
local lighting = dataModel:GetService("Lighting")
services.Lighting = lighting
local WorldService = load("server/Services/WorldService.luau", {})
WorldService.init()
assert(workspaceFolder:FindFirstChild("ArcanumWorld"), "mundo nao foi criado")
print("Mundo: ok")

-- HUD e barras de inimigos (interface completa, sem rodar o loop por quadro).
local localPlayer = roblox.Instance.new("Folder")
local playerGui = roblox.Instance.new("Folder")
playerGui.Name = "PlayerGui"
playerGui.Parent = localPlayer
localPlayer:SetAttribute("Level", 1)
services.Players = {
	LocalPlayer = localPlayer,
	GetPlayers = function()
		return {}
	end,
}
local SharedFull = {
	Schools = "Schools",
	StaffPose = "StaffPose",
	SpellCatalog = "SpellCatalog",
	Spells = "Spells",
	SoundCatalog = "SoundCatalog",
	Net = "Net",
	Data = { Spells = "SpellData", SpellText = "SpellText" },
}
services.ReplicatedStorage = { Shared = SharedFull }
modules.SpellCatalog = load("shared/SpellCatalog.luau", {})
modules.Spells = {
	get = function()
		return nil
	end,
}
local controllersScript = { Parent = { CameraController = "CameraController", ClientState = "ClientState" } }
modules.CameraController = { AimTarget = nil }
modules.ClientState = { SelectedSlot = 1, Cooldowns = {}, GcdUntil = 0 }
services.UserInputService = { InputBegan = signal, InputChanged = signal }
local Hud = load("client/Controllers/HudController.luau", controllersScript)
Hud.start()
Hud.feedback("Mana", 1)
Hud.hitmarker(true)
Hud.castPulse(2)
Hud.notice("ESQUIVA PERFEITA!", roblox.Color3.new(0.6, 0.85, 1))
Hud.dodged(0.9)
local EnemyBars = load("client/Controllers/EnemyBars.luau", controllersScript)
EnemyBars.start()
local guiCount = #playerGui:GetDescendants()
assert(guiCount > 50, "HUD incompleto")
print(string.format("HUD: ok (%d elementos)", guiCount))

-- Criaturas: monta cada corpo (bolhas inteiras; humanoides sobre um R15 falso com as partes e
-- tamanhos padrao), confere solda de todas as pecas e anima um quadro de cada (Vfx/Creatures).
local CreatureBuilder = load("server/Combat/CreatureBuilder.luau", {})
modules.MotorOverlay = load("client/Vfx/MotorOverlay.luau", {})
local Creatures = load("client/Vfx/Creatures.luau", vfxScript)
services.Players.GetPlayerByUserId = function()
	return nil
end
local enemiesFolder = roblox.Instance.new("Folder")
enemiesFolder.Name = "Enemies"
enemiesFolder.Parent = workspaceFolder

local function checkWelds(model, label)
	local root = model:FindFirstChild("HumanoidRootPart")
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p ~= root and p.Name ~= "Body" and not p:FindFirstChildWhichIsA("JointInstance") then
			local isRig = p.Name:match("Torso$")
				or p.Name:match("Arm$")
				or p.Name:match("Leg$")
				or p.Name:match("Hand$")
				or p.Name:match("Foot$")
				or p.Name == "Head"
			assert(isRig, label .. ": peca solta " .. p.Name)
		end
	end
end

local creatureCount = 0
for _, rowName in { "ArcaneSlime", "ArcaneSlimeSmall", "StormBloater" } do
	local blob = CreatureBuilder.buildBlob(rowName, Lib.palette("Energy"))
	assert(blob and blob.PrimaryPart and blob:FindFirstChildOfClass("Humanoid"), rowName .. " incompleto")
	assert(blob.HumanoidRootPart:FindFirstChild("Body"), rowName .. " sem Motor6D Body")
	checkWelds(blob, rowName)
	blob.Parent = enemiesFolder
	blob:SetAttribute("Windup", if rowName == "StormBloater" then "Explode" else "Pounce")
	Creatures.debugStep(blob, 1 / 60)
	Creatures.flinch(blob, V.new(5, 0, 0), 1)
	Creatures.debugStep(blob, 1 / 60)
	creatureCount += #blob:GetDescendants()
end

local function fakeR15()
	local model = roblox.Instance.new("Model")
	local sizes = {
		HumanoidRootPart = V.new(2, 2, 1),
		Head = V.new(1.2, 1.2, 1.2),
		UpperTorso = V.new(2, 1.6, 1),
		LowerTorso = V.new(2, 0.4, 1),
		LeftUpperArm = V.new(1, 1.2, 1),
		RightUpperArm = V.new(1, 1.2, 1),
		LeftLowerArm = V.new(1, 1.2, 1),
		RightLowerArm = V.new(1, 1.2, 1),
		LeftHand = V.new(1, 0.3, 1),
		RightHand = V.new(1, 0.3, 1),
		LeftUpperLeg = V.new(1, 1.2, 1),
		LeftLowerLeg = V.new(1, 1.2, 1),
		LeftFoot = V.new(1, 0.3, 1),
	}
	for name, size in sizes do
		local p = roblox.Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = roblox.CFrame.new(0, 3, 0)
		p.Parent = model
	end
	local face = roblox.Instance.new("Decal")
	face.Name = "face"
	face.Parent = model.Head
	local neck = roblox.Instance.new("Motor6D")
	neck.Name = "Neck"
	neck.Part0 = model.UpperTorso
	neck.Part1 = model.Head
	neck.Transform = roblox.CFrame.new() -- no Studio o Animator escreve isto a cada quadro
	neck.Parent = model.Head
	local waist = roblox.Instance.new("Motor6D")
	waist.Name = "Root"
	waist.Part0 = model.HumanoidRootPart
	waist.Part1 = model.LowerTorso
	waist.Transform = roblox.CFrame.new()
	waist.Parent = model.LowerTorso
	roblox.Instance.new("Humanoid").Parent = model
	return model
end

for _, rowName in { "SkeletonMage", "CrystalGolem", "SkeletonServant", "BruteServant" } do
	local description = roblox.Instance.new("HumanoidDescription")
	CreatureBuilder.describe(rowName, description, Lib.palette("Fire"))
	local rig = fakeR15()
	CreatureBuilder.dress(rig, rowName, Lib.palette("Fire"))
	assert(rig:GetAttribute("Creature") ~= "Plain", rowName .. " sem tipo")
	assert(not rig.Head:FindFirstChildOfClass("Decal"), rowName .. " manteve o rosto padrao")
	checkWelds(rig, rowName)
	rig.Parent = enemiesFolder
	rig:SetAttribute("Staggered", true)
	Creatures.flinch(rig, V.new(0, 3, -5), 1)
	Creatures.debugStep(rig, 1 / 60)
	creatureCount += #rig:GetDescendants()
end
print(string.format("Criaturas: ok (%d pecas)", creatureCount))

-- Impacto: hit-stop (congela e solta), clarao de tela e o visual de cada reacao entre escolas.
modules.Creatures = Creatures
modules.Numbers = Numbers
local impactScript = {
	Parent = {
		Lib = "Lib",
		Effects = "Effects",
		Lightning = "Lightning",
		Creatures = "Creatures",
		Numbers = "Numbers",
		Audio = "Audio",
	},
}
local Impact = load("client/Vfx/Impact.luau", impactScript)
local frozen = enemiesFolder:GetChildren()[1]
Impact.hit(frozen, 9, true, false)
Creatures.debugStep(frozen, 1 / 60) -- congelado: nao anima
Impact.screenFlash(Lib.palette("Fire").Halo, 0.7)
assert(lighting:FindFirstChild("ArcanumImpactFlash"), "sem efeito de clarao")
local ComboMath = load("shared/Math/ComboMath.luau", {})
for _, r in ComboMath.Reactions do
	Impact.reaction({
		Id = r.Id,
		Label = r.Label,
		Target = frozen,
		Position = V.new(0, 3, 0),
		Radius = 5,
		Targets = { V.new(4, 3, 0), V.new(-4, 3, 2) },
		Source = fakeCaster,
	}, true)
end
print(string.format("Impacto: ok (%d reacoes)", #ComboMath.Reactions))

-- Esquiva: animacao procedural num R15 com quadril, joelho e ombro + linhas de velocidade.
local DodgeAnim = load("client/Vfx/DodgeAnim.luau", vfxScript)
local dodger = fakeR15()
for motorName, partName in { LeftHip = "LeftUpperLeg", LeftKnee = "LeftLowerLeg", LeftShoulder = "LeftUpperArm" } do
	local motor = roblox.Instance.new("Motor6D")
	motor.Name = motorName
	motor.Part1 = dodger[partName]
	motor.Transform = roblox.CFrame.new()
	motor.Parent = dodger[partName]
end
dodger.Parent = workspaceFolder
DodgeAnim.play(dodger, V.new(1, 0, -1))
DodgeAnim.debugStep()
DodgeAnim.debugStep()
assert(dodger.LowerTorso.Root.Transform.Position.Y < 0, "esquiva deveria abaixar o quadril")
Effects.speedLines(V.new(0, 3, 0), V.new(1, 0, -1), roblox.Color3.new(0.6, 0.85, 1))
Effects.afterimage(dodger, roblox.Color3.new(0.6, 0.85, 1), 0.5)
print("Esquiva: ok")

-- Fisica da esquiva e do empurrao: mesmas propriedades usadas no jogo.
local push = roblox.Instance.new("LinearVelocity")
push.RelativeTo = roblox.Enum.ActuatorRelativeTo.World
push.VelocityConstraintMode = roblox.Enum.VelocityConstraintMode.Vector
push.VectorVelocity = V.new(1, 0, 0)
push.MaxForce = math.huge
local dash = roblox.Instance.new("LinearVelocity")
dash.VelocityConstraintMode = roblox.Enum.VelocityConstraintMode.Plane
dash.PrimaryTangentAxis = V.new(1, 0, 0)
dash.SecondaryTangentAxis = V.new(0, 0, 1)
dash.PlaneVelocity = roblox.Vector2.new(1, 0)
print("Fisica: ok")

-- Grimorio: monta o livro com as magias reais, abre, seleciona, equipa e fecha.
modules.SpellData = load("shared/Data/Spells.luau", {})
modules.SpellText = load("shared/Data/SpellText.luau", {})
modules.Spells = load("shared/Spells.luau", { Parent = SharedFull })
local equipped = {}
modules.Net = {
	get = function()
		return {
			FireServer = function(_, id, slot)
				table.insert(equipped, { id, slot })
			end,
			OnClientEvent = signal,
		}
	end,
}
for i, id in modules.SpellCatalog.StartingSlots do
	localPlayer:SetAttribute("Slot" .. i, id)
end
modules.ClientState.SlotKey = signal
local Grimoire = load("client/Controllers/GrimoireController.luau", {
	Parent = {
		CameraController = "CameraController",
		ClientState = "ClientState",
		Parent = { Vfx = { Audio = "Audio" } },
	},
})
Grimoire.start()
Grimoire.open()
assert(Grimoire.isOpen() and modules.CameraController.MouseFree, "Grimorio deveria abrir e soltar o mouse")
Grimoire.debugSelect("MagmaLance")
Grimoire.equip(2)
assert(#equipped == 1 and equipped[1][1] == "MagmaLance" and equipped[1][2] == 2, "Grimorio nao equipou")
Grimoire.debugSelect("Meteor") -- as 42 estao implementadas: todas equipam
Grimoire.equip(3)
assert(#equipped == 2 and equipped[2][1] == "Meteor", "Meteoro deveria equipar")
Grimoire.close()
local book = playerGui:FindFirstChild("ArcanumGrimoire")
assert(book and #book:GetDescendants() > 80, "Grimorio incompleto")
print(string.format("Grimorio: ok (%d elementos)", #book:GetDescendants()))

local count = 0
for _ in workspaceFolder:GetDescendants() do
	count += 1
end
print(string.format("SMOKE VFX: ok (%d instancias criadas)", count))
