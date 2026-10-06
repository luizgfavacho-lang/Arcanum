--!strict
-- Peso dos golpes e reacoes entre escolas (so cliente):
--   hit-stop: a criatura congela um instante quando um golpe SEU acerta forte;
--   clarao de tela: pulso de cor curto nos golpes grandes e nas reacoes;
--   reacao: visual proprio de cada combo (Math/ComboMath) + texto grande sobre o alvo.

local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Lib = require(script.Parent.Lib)
local Effects = require(script.Parent.Effects)
local Lightning = require(script.Parent.Lightning)
local Creatures = require(script.Parent.Creatures)
local Numbers = require(script.Parent.Numbers)
local Audio = require(script.Parent.Audio)

local Impact = {}

local flashEffect: ColorCorrectionEffect? = nil

-- Pulso de cor na tela (forca 0..1). Efeito proprio, separado da gradacao do mundo.
function Impact.screenFlash(color: Color3, strength: number)
	local effect = flashEffect
	if not effect or not effect.Parent then
		local e = Instance.new("ColorCorrectionEffect")
		e.Name = "ArcanumImpactFlash"
		e.Parent = Lighting
		flashEffect = e
		effect = e
	end
	local fx = effect :: ColorCorrectionEffect
	local s = math.clamp(strength, 0, 1)
	fx.TintColor = Color3.new(1, 1, 1):Lerp(color, 0.35 * s)
	fx.Brightness = 0.12 * s
	fx.Contrast = 0.15 * s
	TweenService:Create(fx, TweenInfo.new(0.18 + 0.12 * s, Enum.EasingStyle.Quad), {
		TintColor = Color3.new(1, 1, 1),
		Brightness = 0,
		Contrast = 0,
	}):Play()
end

-- Golpe direto que acertou: quanto maior, mais congela (40..110 ms).
function Impact.hit(target: Model, amount: number, mine: boolean, killed: boolean)
	if not mine then
		return
	end
	local stop = math.clamp(0.03 + amount * 0.012, 0.04, 0.11)
	if killed then
		stop = 0.14
	end
	Creatures.hitStop(target, stop)
end

local function rootOf(model: any): Vector3?
	return if typeof(model) == "Instance" then Lib.rootPosition(model) else nil
end

-- Particulas viajando de um ponto a outro (almas, esporos).
local function stream(from: Vector3, to: Vector3, color: Color3, count: number, duration: number)
	for i = 1, count do
		task.delay(i * 0.04, function()
			local orb = Lib.part(Vector3.one * 0.35, color, CFrame.new(from), { Shape = Enum.PartType.Ball })
			local mid = (from + to) / 2
				+ Vector3.new((math.random() - 0.5) * 3, 1.5 + math.random() * 2, (math.random() - 0.5) * 3)
			local started = os.clock()
			local conn: RBXScriptConnection
			conn = RunService.RenderStepped:Connect(function()
				local t = math.min((os.clock() - started) / duration, 1)
				local a = from:Lerp(mid, t)
				local b = mid:Lerp(to, t)
				orb.CFrame = CFrame.new(a:Lerp(b, t))
				orb.Size = Vector3.one * (0.35 * (1 - t * 0.6))
				if t >= 1 then
					conn:Disconnect()
					orb:Destroy()
				end
			end)
		end)
	end
end

local VISUALS: { [string]: (p: any, center: Vector3, mine: boolean) -> () } = {
	-- Fogo + raio: explosao bicolor, anel, arcos para quem levou o respingo.
	Overload = function(p, center)
		local fire, storm = Lib.palette("Fire"), Lib.palette("Electricity")
		Effects.flash(center, fire, 2.6, true)
		Lib.burst(center, "Zap", storm, 2, { Size = Lib.seq(5, 11) })
		Lib.burst(center, "Blaze", fire, 4, { Speed = NumberRange.new(6, 12), Size = Lib.seq(2.5, 3.5) })
		Lib.burst(center, "Arc", storm, 8, { Speed = NumberRange.new(8, 16) })
		Effects.shockwave(Lib.groundBelow(center) + Vector3.new(0, 0.1, 0), storm, math.max(p.Radius or 6, 6))
		for _, pos in p.Targets or {} do
			Lightning.bolt(center, pos, storm, { Width = 0.16, Forks = 1, Flickers = 2 })
		end
	end,
	-- Fogo + agua: nuvem de vapor branca que sobe e chiado.
	Vaporize = function(_, center)
		local steam = { Core = Color3.new(1, 1, 1), Halo = Color3.fromRGB(220, 230, 240), Accent = Color3.new(1, 1, 1) }
		Lib.burst(center, "Smoke", steam :: any, 14, {
			Color = ColorSequence.new(Color3.fromRGB(235, 240, 245), Color3.fromRGB(190, 200, 210)),
			Size = Lib.seq(2, 7),
			Transparency = Lib.seq(0.25, 1),
			Speed = NumberRange.new(4, 9),
			Acceleration = Vector3.new(0, 9, 0),
			Lifetime = NumberRange.new(0.8, 1.4),
		})
		Effects.flash(center, Lib.palette("Fire"), 1.6, false)
	end,
	-- Raio na agua: arcos saltando entre os encharcados.
	Conduct = function(p, center)
		local storm = Lib.palette("Electricity")
		local last = center
		for i, pos in p.Targets or {} do
			task.delay(i * 0.05, function()
				Lightning.bolt(last, pos, storm, { Width = 0.2, Forks = 2, Flickers = 3 })
				Lib.burst(pos, "Zap", storm, 1)
				last = pos
			end)
		end
		Lib.burst(center, "Arc", storm, 10, { Speed = NumberRange.new(4, 10) })
		Lib.burst(center + Vector3.new(0, -2, 0), "Ring", storm, 1, { Size = Lib.seq(1, 9) })
	end,
	-- Energia quebra a paralisia: estilhacos de cristal voando.
	Rupture = function(_, center)
		local energy = Lib.palette("Energy")
		Effects.flash(center, energy, 2, true)
		for _ = 1, 10 do
			local dir = Vector3.new(math.random() - 0.5, math.random() * 0.8, math.random() - 0.5).Unit
			local shard = Lib.part(
				Vector3.new(0.25, 0.25, 0.9 + math.random() * 0.8),
				energy.Halo:Lerp(Color3.new(1, 1, 1), 0.35),
				CFrame.lookAt(center, center + dir),
				{ Material = Enum.Material.Glass, Transparency = 0.15 }
			)
			Lib.fade(shard, 0.45, {
				CFrame = CFrame.lookAt(center + dir * 6, center + dir * 7) * CFrame.Angles(math.random() * 3, 0, 0),
				Transparency = 1,
			})
		end
		Lib.burst(center, "Ring", energy, 1, { Size = Lib.seq(1, 10) })
	end,
	-- Necromancia no sangrando: almas carmesim voam do alvo para o conjurador.
	Harvest = function(p, center)
		local necro = Lib.palette("Necromancy")
		local to = rootOf(p.Source)
		if to then
			stream(center, to, necro.Halo, 6, 0.45)
			stream(center, to, Lib.palette("Blood").Halo, 3, 0.5)
		end
		Lib.burst(center, "Wisp", necro, 12)
	end,
	-- Sangue no envenenado: esporos e fios carmesim-esverdeados ate os vizinhos.
	Contagion = function(p, center)
		local blood, necro = Lib.palette("Blood"), Lib.palette("Necromancy")
		Lib.burst(center, "Smoke", necro, 10, {
			Color = ColorSequence.new(Color3.fromRGB(90, 160, 60), Color3.fromRGB(70, 20, 30)),
			Size = Lib.seq(1.5, 5),
			Transparency = Lib.seq(0.35, 1),
		})
		for _, pos in p.Targets or {} do
			stream(center, pos, blood.Halo:Lerp(necro.Halo, 0.4), 4, 0.35)
		end
		local seal =
			Lib.groundDecal(Lib.groundBelow(center), 7, Lib.Catalog.CircleThorns, blood.Halo, { Brightness = 2 })
		Lib.tween(seal.Image, 0.8, { ImageTransparency = 1 })
		Lib.tween(seal.Part, 0.8, { CFrame = seal.Part.CFrame * CFrame.Angles(0, 1.2, 0) })
		Debris:AddItem(seal.Part, 0.85)
	end,
}

local LABEL_COLORS: { [string]: Color3 } = {
	Overload = Color3.fromRGB(255, 190, 60),
	Vaporize = Color3.fromRGB(230, 240, 255),
	Conduct = Color3.fromRGB(110, 200, 255),
	Rupture = Color3.fromRGB(200, 150, 255),
	Harvest = Color3.fromRGB(110, 255, 160),
	Contagion = Color3.fromRGB(200, 60, 90),
}

function Impact.reaction(p: any, mine: boolean)
	local center: Vector3 = p.Position
	local visual = VISUALS[p.Id]
	if visual then
		visual(p, center, mine)
	end
	local color = LABEL_COLORS[p.Id] or Color3.new(1, 1, 1)
	if typeof(p.Target) == "Instance" and p.Target.Parent then
		Numbers.label(p.Target, tostring(p.Label) .. "!", color)
		Creatures.hitStop(p.Target, 0.12)
	end
	Audio.play("Reaction_" .. tostring(p.Id), center)
	if mine then
		Impact.screenFlash(color, 0.7)
	end
end

return Impact
