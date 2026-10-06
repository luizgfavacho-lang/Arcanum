--!strict
-- Detalhes proprios de cada magia (so visual, no cliente):
--   flourish     floreio na gema ao conjurar (arcos, chamas, almas, runas...)
--   lavaPool     poca de lava irregular onde a Lanca de Magma cai: borbulha, brilha e esfria
--   residueArcs  arcos eletricos que ficam pulando no alvo da Faisca
--   fireGround   anel de chamas e destrocos caindo no impacto da Bola de Fogo
--   runeBurst    selo runico e estilhacos no impacto do Missil Arcano
--   chainNode    no de luz em cada elo da Corrente em Cadeia
--   healRing     circulo de cura aos pes de quem drena vida
--   stormWarn    nuvem e circulo antes do Raio Invocado; groundCrackle: chao eletrificado depois
--   flamePillars colunas de fogo em volta da Nova Flamejante
--   arcaneDome   cupula de energia do Pulso Arcano + estouro dos projeteis apagados
--   bloodSpikes  espinhos carmesins com rachadura e nevoa (sangue estilizado)

local TweenService = game:GetService("TweenService")

local Lib = require(script.Parent.Lib)
local Effects = require(script.Parent.Effects)
local Lightning = require(script.Parent.Lightning)

local SpellFx = {}

local UP = Vector3.new(0, 1, 0)

local function randomUnit(): Vector3
	local v = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5)
	return if v.Magnitude > 0.01 then v.Unit else UP
end

local function flatDisc(position: Vector3, diameter: number, color: Color3, props: { [string]: any }?): Part
	local cf = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	local options: { [string]: any } = { Shape = Enum.PartType.Cylinder }
	if props then
		for k, v in props do
			options[k] = v
		end
	end
	return Lib.part(Vector3.new(0.08, diameter, diameter), color, cf, options)
end

---------------------------------------------------------------------------------------------------
-- Conjuracao

function SpellFx.flourish(spellId: string?, caster: Model, palette: Lib.Palette, gem: Vector3, school: string?)
	if spellId == "Spark" or spellId == "ChainLightning" then
		for _ = 1, 3 do
			Lightning.bolt(
				gem,
				gem + randomUnit() * 1.4,
				palette,
				{ Width = 0.07, Forks = 0, Flickers = 1, Duration = 0.08, Glow = false }
			)
		end
	elseif spellId == "Fireball" or spellId == "MagmaLance" then
		Lib.burst(gem, "Flame", palette, 6, { Speed = NumberRange.new(2, 5), Size = Lib.seq(1.2, 0.6, 0) })
		Lib.burst(gem, "Ember", palette, 10, { Speed = NumberRange.new(4, 9) })
	elseif spellId == "ArcaneMissile" then
		Lib.burst(gem, "Star", palette, 10, { Speed = NumberRange.new(3, 6) })
	elseif spellId == "LifeDrain" or spellId == "WanderingSouls" then
		Lib.burst(gem, "Wisp", palette, 10, { Speed = NumberRange.new(-4, -2), Lifetime = NumberRange.new(0.3, 0.5) })
	elseif spellId == "SummonedBolt" then
		Lib.burst(
			gem,
			"Spark",
			palette,
			14,
			{ EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(20, 20) }
		)
		Lightning.bolt(
			gem,
			gem + Vector3.new(0, 6, 0),
			palette,
			{ Width = 0.1, Forks = 1, Flickers = 2, Duration = 0.12 }
		)
	elseif spellId == "CrimsonSpikes" then
		local feet = Lib.groundBelow(Lib.rootPosition(caster) or gem, caster)
		Lib.burst(feet, "Smoke", palette, 6, {
			Color = ColorSequence.new(palette.Halo, palette.Accent),
			Speed = NumberRange.new(1, 3),
		})
		Lib.burst(feet + UP * 0.3, "Star", palette, 8)
	elseif school == "Electricity" then
		for _ = 1, 2 do
			Lightning.bolt(
				gem,
				gem + randomUnit() * 1.6,
				palette,
				{ Width = 0.07, Forks = 0, Flickers = 1, Duration = 0.08, Glow = false }
			)
		end
		Lib.burst(gem, "Spark", palette, 8)
	elseif school == "Fire" then
		Lib.burst(gem, "Flame", palette, 5, { Speed = NumberRange.new(2, 5), Size = Lib.seq(1.2, 0.6, 0) })
		Lib.burst(gem, "Ember", palette, 8)
	elseif school == "Energy" then
		Lib.burst(gem, "Star", palette, 10, { Speed = NumberRange.new(3, 7) })
	elseif school == "Necromancy" then
		Lib.burst(gem, "Wisp", palette, 10, { Speed = NumberRange.new(-4, -2), Lifetime = NumberRange.new(0.3, 0.5) })
	elseif school == "Blood" then
		Lib.burst(
			gem,
			"Smoke",
			palette,
			4,
			{ Color = ColorSequence.new(palette.Halo, palette.Accent), Speed = NumberRange.new(1, 3) }
		)
		Lib.burst(gem, "Spark", palette, 8, { Acceleration = Vector3.new(0, -40, 0) })
	end
end

---------------------------------------------------------------------------------------------------
-- Lanca de Magma: poca de lava

local LAVA_DEEP = Color3.fromRGB(150, 28, 10) -- superficie
local LAVA_HOT = Color3.fromRGB(230, 70, 18) -- veios incandescentes
local LAVA_CORE = Color3.fromRGB(255, 135, 45) -- pontos mais quentes
local LAVA_COOL = Color3.fromRGB(45, 14, 10)
local CRUST = Color3.fromRGB(32, 14, 12)

-- Poca irregular: lobos de tamanhos diferentes em volta do centro (forma vinda do servidor pela
-- semente, igual para todos), crosta escura na borda, veios incandescentes pulsando, bolhas que
-- estouram, brasas e fumaca. O terreno embaixo vira lava rachada (a grama nao cobre a poca).
function SpellFx.lavaPool(center: Vector3, radius: number, duration: number, seed: number)
	local rng = Random.new(seed)
	local palette = Lib.palette("Fire")
	Lib.swapGround(center, radius * 1.1, Enum.Material.CrackedLava, duration + 0.6)
	local base = center + UP * 0.12

	type Lobe = { Offset: Vector3, Diameter: number }
	local lobes: { Lobe } = { { Offset = Vector3.zero, Diameter = radius * 1.25 } }
	local count = 7
	for i = 1, count do
		local angle = i / count * math.pi * 2 + rng:NextNumber(-0.35, 0.35)
		local distance = radius * rng:NextNumber(0.35, 0.7)
		table.insert(lobes, {
			Offset = Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance),
			Diameter = radius * rng:NextNumber(0.55, 0.95),
		})
	end

	local crust: { BasePart } = {}
	local surface: { BasePart } = {}
	local veins: { BasePart } = {}
	local function grow(part: BasePart, delay: number)
		local size = part.Size
		part.Size = Vector3.new(size.X, size.Y * 0.1, size.Z * 0.1)
		task.delay(delay, function()
			TweenService
				:Create(part, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = size })
				:Play()
		end)
	end
	for i, lobe in lobes do
		local at = base + lobe.Offset
		local edge = flatDisc(at, lobe.Diameter * 1.18, CRUST, { Material = Enum.Material.Basalt })
		local lava = flatDisc(at + UP * 0.03, lobe.Diameter, LAVA_DEEP)
		grow(edge, i * 0.02)
		grow(lava, i * 0.02)
		table.insert(crust, edge)
		table.insert(surface, lava)
	end
	for i = 1, 7 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = radius * rng:NextNumber(0, 0.7)
		local at = base + Vector3.new(math.cos(angle) * distance, 0.06, math.sin(angle) * distance)
		local vein = flatDisc(at, radius * rng:NextNumber(0.18, 0.4), if i <= 2 then LAVA_CORE else LAVA_HOT)
		grow(vein, 0.1 + i * 0.02)
		table.insert(veins, vein)
		TweenService:Create(
			vein,
			TweenInfo.new(rng:NextNumber(0.5, 0.9), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Color = if i <= 2 then LAVA_HOT else LAVA_CORE }
		):Play()
	end

	-- Respingo ao abrir, luz, brasas e fumaca.
	Lib.burst(base + UP * 0.5, "Flame", palette, 10, { Speed = NumberRange.new(4, 9), Size = Lib.seq(1.6, 0.8, 0) })
	Lib.burst(base + UP * 0.5, "Ember", palette, 24, { Speed = NumberRange.new(8, 16) })
	local emitters: { ParticleEmitter } = {}
	local light: PointLight? = nil
	for i, lobe in lobes do
		if i % 2 == 1 then
			local anchor = Lib.anchor(base + lobe.Offset + UP * 0.2, duration + 1.5)
			table.insert(emitters, Lib.emitter(anchor, "Ember", palette, { Rate = 3, Speed = NumberRange.new(1, 4) }))
			table.insert(emitters, Lib.emitter(anchor, "Smoke", palette, { Rate = 1.2, Size = Lib.seq(0.8, 2.6) }))
			if i == 1 then
				local l = Instance.new("PointLight")
				l.Color = LAVA_HOT
				l.Range = radius * 2.4
				l.Brightness = 1.4
				l.Parent = anchor
				light = l
			end
		end
	end

	-- Bolhas que incham e estouram em pontos aleatorios.
	local finished = false
	task.spawn(function()
		while not finished do
			local angle = math.random() * math.pi * 2
			local at = base + Vector3.new(math.cos(angle), 0, math.sin(angle)) * radius * math.random() * 0.75
			local bubble =
				Lib.part(Vector3.one * 0.25, LAVA_HOT, CFrame.new(at + UP * 0.1), { Shape = Enum.PartType.Ball })
			TweenService:Create(bubble, TweenInfo.new(0.35), { Size = Vector3.one * 0.9 }):Play()
			task.delay(0.35, function()
				Lib.burst(at + UP * 0.3, "Ember", palette, 4, { Speed = NumberRange.new(3, 6) })
				Lib.fade(bubble, 0.1, { Transparency = 1, Size = Vector3.one * 1.2 })
			end)
			task.wait(0.18 + math.random() * 0.3)
		end
	end)

	-- Esfria no fim (escurece de fora para dentro) e some.
	task.delay(math.max(duration - 0.9, 0), function()
		finished = true
		for _, e in emitters do
			e.Enabled = false
		end
		if light then
			TweenService:Create(light, TweenInfo.new(0.9), { Brightness = 0 }):Play()
		end
		for _, v in veins do
			Lib.fade(v, 0.6, { Transparency = 1 })
		end
		for _, p in surface do
			TweenService:Create(p, TweenInfo.new(0.9), { Color = LAVA_COOL }):Play()
		end
		task.delay(0.9, function()
			for _, p in surface do
				Lib.fade(p, 0.5, { Transparency = 1 })
			end
			for _, p in crust do
				Lib.fade(p, 0.5, { Transparency = 1 })
			end
		end)
	end)
end

---------------------------------------------------------------------------------------------------
-- Impactos e detalhes

-- Arcos que ficam pulando em volta do ponto atingido (Faisca).
function SpellFx.residueArcs(position: Vector3, palette: Lib.Palette, duration: number)
	local started = os.clock()
	task.spawn(function()
		while os.clock() - started < duration do
			local a = position + randomUnit() * 1.5
			local b = position + randomUnit() * 1.5
			Lightning.bolt(a, b, palette, { Width = 0.07, Forks = 0, Flickers = 1, Duration = 0.07, Glow = false })
			task.wait(0.07)
		end
	end)
	Lib.burst(position, "Spark", palette, 10, { Speed = NumberRange.new(4, 10) })
end

-- Anel de chamas que fica queimando no chao e destrocos incandescentes caindo (Bola de Fogo).
function SpellFx.fireGround(position: Vector3, palette: Lib.Palette, radius: number, duration: number)
	local ground = Lib.groundBelow(position + UP * 1, nil)
	for i = 1, 8 do
		local angle = i * math.pi / 4 + math.random() * 0.3
		local at = ground + Vector3.new(math.cos(angle), 0.2, math.sin(angle)) * radius * (0.6 + math.random() * 0.4)
		local anchor = Lib.anchor(at, duration + 1)
		local flame = Lib.emitter(anchor, "Flame", palette, {
			Rate = 14,
			Speed = NumberRange.new(1, 3),
			Size = Lib.seq(1, 0.6, 0),
			EmissionDirection = Enum.NormalId.Top,
			SpreadAngle = Vector2.new(15, 15),
		})
		task.delay(duration * (0.6 + math.random() * 0.4), function()
			flame.Enabled = false
		end)
	end
	Lib.burst(position, "Spark", palette, 18, {
		Speed = NumberRange.new(14, 28),
		Acceleration = Vector3.new(0, -70, 0),
		Lifetime = NumberRange.new(0.6, 1.1),
		Size = Lib.seq(0.5, 0),
	})
end

-- Selo runico rapido e estilhacos (Missil Arcano).
function SpellFx.runeBurst(position: Vector3, palette: Lib.Palette)
	Effects.runeCircle(position, palette, 1.3, 0.45)
	Lib.burst(position, "Spark", palette, 8, { Speed = NumberRange.new(8, 16), Acceleration = Vector3.new(0, -30, 0) })
end

-- No de luz em cada elo da cadeia.
function SpellFx.chainNode(position: Vector3, palette: Lib.Palette)
	local node = Lib.part(Vector3.one * 1.3, palette.Halo, CFrame.new(position), {
		Shape = Enum.PartType.Ball,
		Transparency = 0.45,
	})
	Lib.fade(node, 0.12, { Size = Vector3.one * 0.3, Transparency = 1 })
end

-- Circulo de cura aos pes de quem drena (Drenar Vida).
function SpellFx.healRing(caster: Model, palette: Lib.Palette)
	local root = Lib.rootPosition(caster)
	if not root then
		return
	end
	Effects.runeCircle(Lib.groundBelow(root, caster) + UP * 0.1, palette, 2, 0.6)
	Lib.burst(root, "Wisp", palette, 10, { Speed = NumberRange.new(2, 5) })
end

-- Nuvem escura que se forma e circulo eletrico no chao antes do Raio Invocado.
function SpellFx.stormWarn(position: Vector3, radius: number, duration: number, palette: Lib.Palette)
	local cloud = position + Vector3.new(0, 24, 0)
	Lib.burst(cloud, "Smoke", palette, 16, {
		Color = ColorSequence.new(Color3.fromRGB(40, 44, 60), Color3.fromRGB(20, 22, 32)),
		Size = Lib.seq(6, 10),
		Transparency = Lib.seq(0.2, 1),
		Speed = NumberRange.new(2, 6),
		Lifetime = NumberRange.new(0.8, 1.2),
		Acceleration = Vector3.zero,
	})
	for i = 1, 3 do
		task.delay(i * duration / 4, function()
			Lightning.bolt(
				cloud + randomUnit() * 4,
				cloud + randomUnit() * 4,
				palette,
				{ Width = 0.15, Forks = 1, Flickers = 1, Duration = 0.08 }
			)
		end)
	end
	Effects.runeCircle(position + UP * 0.1, palette, radius, duration + 0.1)
end

-- Chao eletrificado depois do raio.
function SpellFx.groundCrackle(position: Vector3, radius: number, palette: Lib.Palette, duration: number)
	local started = os.clock()
	task.spawn(function()
		while os.clock() - started < duration do
			local angle = math.random() * math.pi * 2
			local from = position + Vector3.new(math.cos(angle), 0, math.sin(angle)) * radius * math.random() + UP * 0.2
			local to = from + Vector3.new(math.random() - 0.5, 0, math.random() - 0.5) * 3 + UP * 0.2
			Lightning.bolt(from, to, palette, { Width = 0.07, Forks = 0, Flickers = 1, Duration = 0.08, Glow = false })
			task.wait(0.06)
		end
	end)
end

-- Colunas de fogo que sobem em volta (Nova Flamejante) + marca de queimado.
function SpellFx.flamePillars(center: Vector3, radius: number, palette: Lib.Palette)
	for i = 1, 10 do
		local angle = i * math.pi / 5
		local at = center + Vector3.new(math.cos(angle), 0.2, math.sin(angle)) * radius * 0.85
		task.delay(i * 0.012, function()
			Lib.burst(at, "Flame", palette, 10, {
				EmissionDirection = Enum.NormalId.Top,
				SpreadAngle = Vector2.new(8, 8),
				Speed = NumberRange.new(10, 18),
				Size = Lib.seq(2, 1.4, 0),
				Lifetime = NumberRange.new(0.35, 0.55),
			})
		end)
	end
	local scorch = flatDisc(center + UP * 0.04, radius * 2, Color3.fromRGB(30, 18, 16), {
		Material = Enum.Material.SmoothPlastic,
		Transparency = 0.35,
	})
	Lib.fade(scorch, 3, { Transparency = 1 }, Enum.EasingStyle.Sine)
end

-- Cupula de energia que se expande (Pulso Arcano) e estouro dos projeteis apagados.
function SpellFx.arcaneDome(
	center: Vector3,
	ground: Vector3,
	radius: number,
	palette: Lib.Palette,
	popped: { Vector3 }?
)
	local dome = Lib.part(Vector3.one * 2, palette.Halo, CFrame.new(center), {
		Shape = Enum.PartType.Ball,
		Material = Enum.Material.ForceField,
		Transparency = 0,
	})
	Lib.fade(dome, 0.4, { Size = Vector3.one * radius * 2.1, Transparency = 1 }, Enum.EasingStyle.Quint)
	Effects.runeCircle(ground + UP * 0.1, palette, radius * 0.6, 0.6)
	for _, position in popped or {} do
		Effects.flash(position, palette, 1, false)
		Lib.burst(position, "Star", palette, 10)
	end
end

-- Espinhos carmesins (sangue estilizado): sobem em sequencia, racham o chao e recolhem.
function SpellFx.bloodSpikes(from: Vector3, to: Vector3, width: number, palette: Lib.Palette)
	local delta = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local length = delta.Magnitude
	if length < 0.5 then
		return
	end
	local direction = delta.Unit
	local side = direction:Cross(UP)
	local mid = (from + to) / 2 + UP * 0.06
	local crack = Lib.part(
		Vector3.new(0.3, 0.06, length),
		Color3.fromRGB(30, 6, 10),
		CFrame.lookAt(mid, to + UP * 0.06),
		{ Material = Enum.Material.SmoothPlastic }
	)
	Lib.fade(crack, 1.6, { Transparency = 1 }, Enum.EasingStyle.Sine)
	local glow = Lib.part(Vector3.new(0.12, 0.07, length), palette.Halo, crack.CFrame, { Transparency = 0.2 })
	Lib.fade(glow, 0.8, { Transparency = 1 })

	local count = math.max(math.floor(length / 1.6), 3)
	for i = 1, count do
		task.delay(i * 0.028, function()
			local offset = side * (math.random() - 0.5) * width
			local base = from + direction * (i - 0.5) * (length / count) + offset
			local height = 2.4 + math.random() * 2.2
			local lean = CFrame.fromAxisAngle(
				direction:Cross(UP).Unit,
				math.rad(math.random(-12, 12) + (if offset:Dot(side) > 0 then -10 else 10))
			)
			local final = CFrame.new(base) * lean * CFrame.new(0, height * 0.45, 0)
			local hidden = final - Vector3.new(0, height, 0)
			local spike =
				Lib.part(Vector3.new(0.55, height, 0.55), palette.Halo:Lerp(Color3.new(0, 0, 0), 0.35), hidden, {
					Material = Enum.Material.SmoothPlastic,
				})
			local core = Lib.part(Vector3.new(0.18, height * 0.9, 0.18), palette.Halo, hidden)
			local tip = Lib.part(Vector3.one * 0.4, palette.Core, hidden * CFrame.new(0, height / 2, 0), {
				Shape = Enum.PartType.Ball,
			})
			local info = TweenInfo.new(0.09, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			TweenService:Create(spike, info, { CFrame = final }):Play()
			TweenService:Create(core, info, { CFrame = final }):Play()
			TweenService:Create(tip, info, { CFrame = final * CFrame.new(0, height / 2, 0) }):Play()
			Lib.burst(base + UP * 0.3, "Smoke", palette, 2, {
				Color = ColorSequence.new(palette.Halo, palette.Accent),
				Speed = NumberRange.new(1, 3),
			})
			Lib.burst(base + UP * height * 0.8, "Spark", palette, 4)
			task.delay(0.75, function()
				for _, p in { spike, core, tip } do
					Lib.fade(p, 0.35, { CFrame = p.CFrame - Vector3.new(0, height * 0.8, 0), Transparency = 1 })
				end
			end)
		end)
	end
end

return SpellFx
