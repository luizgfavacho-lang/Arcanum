--!strict
-- Efeitos presos ao personagem enquanto um estado estiver ativo (atributos State_* do servidor).

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Lib = require(script.Parent.Lib)
local Lightning = require(script.Parent.Lightning)
local Schools = require(game:GetService("ReplicatedStorage").Shared.Schools)

local Auras = {}

type Factory = (root: BasePart) -> Instance

local function attachmentWith(root: BasePart, build: (Attachment) -> ()): Instance
	local a = Instance.new("Attachment")
	a.Name = "ArcanumAura"
	a.Parent = root
	build(a)
	return a
end

-- Parte decorativa presa ao corpo (bolha, selo) que segue o HumanoidRootPart.
local function welded(root: BasePart, size: Vector3, color: Color3, offset: CFrame, props: { [string]: any }): BasePart
	local p = Instance.new("Part")
	p.Name = "ArcanumAura"
	p.Size = size
	p.Color = color
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	for k, v in props do
		(p :: any)[k] = v
	end
	p.CFrame = root.CFrame * offset
	local weld = Instance.new("Weld")
	weld.Part0 = root
	weld.Part1 = p
	weld.C0 = offset
	weld.Parent = p
	p.Parent = root
	return p
end

local CURSE = {
	Core = Color3.fromRGB(240, 220, 255),
	Halo = Color3.fromRGB(150, 60, 220),
	Accent = Color3.fromRGB(90, 20, 140),
	Shape = "",
}
local POISON = {
	Core = Color3.fromRGB(220, 255, 200),
	Halo = Color3.fromRGB(110, 220, 60),
	Accent = Color3.fromRGB(40, 120, 30),
	Shape = "",
}

local FACTORIES: { [string]: Factory } = {
	-- Escudo de Mana: bolha translucida com brilho.
	ManaShield = function(root)
		local bubble = welded(root, Vector3.one * 7, Schools.Energy.Halo, CFrame.new(0, 0.3, 0), {
			Shape = Enum.PartType.Ball,
			Material = Enum.Material.ForceField,
		})
		attachmentWith(bubble, function(a)
			Lib.emitter(a, "Star", Schools.Energy, { Rate = 6, Speed = NumberRange.new(2, 4) })
		end)
		return bubble
	end,
	-- Armadura de Brasas: chamas e brasas cobrindo o corpo, luz quente.
	EmberArmor = function(root)
		return attachmentWith(root, function(a)
			Lib.emitter(a, "Flame", Schools.Fire, {
				Rate = 26,
				Size = Lib.seq(2.2, 1.4, 0),
				Speed = NumberRange.new(1, 3),
				Acceleration = Vector3.new(0, 10, 0),
				Lifetime = NumberRange.new(0.3, 0.5),
			})
			Lib.emitter(a, "Ember", Schools.Fire, { Rate = 18, Speed = NumberRange.new(3, 7) })
			local light = Instance.new("PointLight")
			light.Color = Schools.Fire.Halo
			light.Range = 12
			light.Brightness = 1.8
			light.Parent = a
		end)
	end,
	-- Fortalecido (Ritual/Pacto): aura carmesim pulsando.
	Empowered = function(root)
		return attachmentWith(root, function(a)
			a.Position = Vector3.new(0, -2.5, 0)
			Lib.emitter(a, "Wisp", Schools.Blood, {
				Rate = 20,
				Speed = NumberRange.new(2, 5),
				SpreadAngle = Vector2.new(40, 40),
				EmissionDirection = Enum.NormalId.Top,
			})
			local light = Instance.new("PointLight")
			light.Color = Schools.Blood.Halo
			light.Range = 9
			light.Brightness = 1.5
			light.Parent = a
		end)
	end,
	-- Maldicao: selo roxo girando sobre a cabeca.
	Cursed = function(root)
		local seal = welded(
			root,
			Vector3.new(0.1, 2.2, 2.2),
			CURSE.Halo,
			CFrame.new(0, 4.2, 0) * CFrame.Angles(0, 0, math.rad(90)),
			{
				Shape = Enum.PartType.Cylinder,
				Material = Enum.Material.ForceField,
			}
		)
		attachmentWith(seal, function(a)
			Lib.emitter(a, "Star", CURSE, { Rate = 8, Speed = NumberRange.new(0.5, 1.5) })
		end)
		return seal
	end,
	Poisoned = function(root)
		return attachmentWith(root, function(a)
			Lib.emitter(a, "Smoke", POISON, {
				Color = ColorSequence.new(POISON.Halo, POISON.Accent),
				Rate = 6,
				Size = Lib.seq(1, 2.4),
				Transparency = Lib.seq(0.5, 1),
				Speed = NumberRange.new(0.5, 1.5),
			})
			Lib.emitter(
				a,
				"Spark",
				POISON,
				{ Rate = 6, Speed = NumberRange.new(1, 3), Acceleration = Vector3.new(0, -20, 0) }
			)
		end)
	end,
	-- Encharcado: gotas pingando e brilho umido (prepara Conducao e Vaporizar).
	Wet = function(root)
		return attachmentWith(root, function(a)
			a.Position = Vector3.new(0, 1.2, 0)
			local water = Schools.Electricity
			Lib.emitter(a, "Spark", water, {
				Color = ColorSequence.new(Color3.fromRGB(190, 225, 255), Color3.fromRGB(90, 150, 230)),
				Rate = 14,
				Brightness = 1.2,
				Size = Lib.seq(0.18, 0.1),
				Speed = NumberRange.new(0, 0.5),
				Acceleration = Vector3.new(0, -40, 0),
				Lifetime = NumberRange.new(0.35, 0.6),
			})
		end)
	end,
	-- Fraqueza: fiapos escuros caindo.
	Weakened = function(root)
		return attachmentWith(root, function(a)
			a.Position = Vector3.new(0, 1.5, 0)
			Lib.emitter(a, "Smoke", Schools.Necromancy, {
				Color = ColorSequence.new(Color3.fromRGB(40, 50, 44), Color3.fromRGB(10, 12, 10)),
				Rate = 8,
				Size = Lib.seq(0.8, 1.8),
				Transparency = Lib.seq(0.4, 1),
				Speed = NumberRange.new(0.5, 1.5),
				Acceleration = Vector3.new(0, -3, 0),
			})
		end)
	end,
	Burning = function(root)
		return attachmentWith(root, function(a)
			Lib.emitter(a, "Flame", Schools.Fire, {
				Rate = 30,
				Size = Lib.seq(2, 1.2, 0),
				Speed = NumberRange.new(2, 5),
				Acceleration = Vector3.new(0, 8, 0),
			})
			Lib.emitter(a, "Ember", Schools.Fire, { Rate = 12 })
			local light = Instance.new("PointLight")
			light.Color = Schools.Fire.Halo
			light.Range = 8
			light.Parent = a
		end)
	end,
	Paralyzed = function(root)
		return attachmentWith(root, function(a)
			Lib.emitter(a, "Spark", Schools.Electricity, { Rate = 18, Speed = NumberRange.new(4, 8) })
		end)
	end,
	ArcaneCharge = function(root)
		return attachmentWith(root, function(a)
			a.Position = Vector3.new(0, 2.5, 0)
			Lib.emitter(
				a,
				"Star",
				Schools.Energy,
				{ Rate = 10, Speed = NumberRange.new(0.5, 1.5), Lifetime = NumberRange.new(0.5, 0.9) }
			)
			local light = Instance.new("PointLight")
			light.Color = Schools.Energy.Halo
			light.Range = 7
			light.Brightness = 2
			light.Parent = a
		end)
	end,
	Bleeding = function(root)
		return attachmentWith(root, function(a)
			Lib.emitter(
				a,
				"Spark",
				Schools.Blood,
				{ Rate = 10, Speed = NumberRange.new(1, 3), Acceleration = Vector3.new(0, -20, 0) }
			)
		end)
	end,
}

local attached: { [Model]: { [string]: Instance } } = setmetatable({}, { __mode = "k" }) :: any

local function candidates(): { Model }
	local list: { Model } = {}
	local world = Workspace:FindFirstChild("ArcanumWorld")
	for _, folderName in { "Enemies", "Minions" } do
		local folder = world and world:FindFirstChild(folderName)
		if folder then
			for _, child in folder:GetChildren() do
				if child:IsA("Model") then
					table.insert(list, child)
				end
			end
		end
	end
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(list, player.Character)
		end
	end
	return list
end

local function refresh()
	for _, model in candidates() do
		local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local current = attached[model] or {}
			attached[model] = current
			for state, factory in FACTORIES do
				local on = model:GetAttribute("State_" .. state) == true
				if on and not current[state] then
					current[state] = factory(root)
				elseif not on and current[state] then
					current[state]:Destroy()
					current[state] = nil
				end
			end
			-- Paralisia: estalos de raio em volta do corpo.
			if current.Paralyzed and math.random() < 0.6 then
				local center = root.Position
				local offset = Vector3.new(math.random() - 0.5, math.random() * 2 - 1, math.random() - 0.5) * 3
				Lightning.bolt(
					center + offset,
					center - offset * 0.6,
					Schools.Electricity,
					{ Width = 0.08, Forks = 0, Flickers = 1, Duration = 0.08 }
				)
			end
		end
	end
end

-- Para o teste de fumaca: cria a aura de cada estado num modelo.
function Auras.debugBuildAll(root: BasePart): number
	local count = 0
	for _, factory in FACTORIES do
		factory(root)
		count += 1
	end
	return count
end

function Auras.start()
	task.spawn(function()
		while true do
			refresh()
			task.wait(0.2)
		end
	end)
end

return Auras
