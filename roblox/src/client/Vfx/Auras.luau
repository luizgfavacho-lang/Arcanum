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

local FACTORIES: { [string]: Factory } = {
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
	local enemies = world and world:FindFirstChild("Enemies")
	if enemies then
		for _, child in enemies:GetChildren() do
			if child:IsA("Model") then
				table.insert(list, child)
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

function Auras.start()
	task.spawn(function()
		while true do
			refresh()
			task.wait(0.2)
		end
	end)
end

return Auras
