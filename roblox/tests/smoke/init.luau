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
	RunService = { RenderStepped = signal, Heartbeat = signal },
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
	e.task = {
		delay = function(_, fn, ...)
			fn(...)
		end,
		spawn = function(fn, ...)
			fn(...)
		end,
		wait = noop,
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
	local source = fs.readFile(ROOT .. path):gsub("([%w_]+):Emit%(", "EMIT(%1, ")
	return luau.load(source, { environment = e })()
end

-- Arvore virtual: script.Parent.X -> chaves
local Shared = { Schools = "Schools", StaffPose = "StaffPose" }
services.ReplicatedStorage = { Shared = Shared }
modules.Schools = load("shared/Schools.luau", {})
modules.StaffPose = load("shared/StaffPose.luau", {})

local vfxScript = { Parent = { Lib = "Lib", Effects = "Effects", Lightning = "Lightning" } }
modules.Lib = load("client/Vfx/Lib.luau", vfxScript)
modules.Effects = load("client/Vfx/Effects.luau", vfxScript)
modules.Lightning = load("client/Vfx/Lightning.luau", vfxScript)
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
for _, spellId in { "Fireball", "ArcaneMissile", "Outra" } do
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
local head = roblox.Instance.new("Part")
head.Name = "Head"
head.CFrame = roblox.CFrame.new(0, 5, 0)
head.Parent = fakeCaster
Numbers.heal(fakeCaster, 2.5)
Numbers.damage(fakeCaster, 6, Lib.palette("Fire"), false)

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

local count = 0
for _ in workspaceFolder:GetDescendants() do
	count += 1
end
print(string.format("SMOKE VFX: ok (%d instancias criadas)", count))
