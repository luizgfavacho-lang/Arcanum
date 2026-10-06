--!strict
-- Efeitos instantaneos das magias do Grimorio completo (so visual):
-- tempestade e chuva de estrelas, meteoro, veredito, lanca do firmamento, raio arcano, lamina de
-- sangue, invocacao, jaula, anzol, toque mortal, maldicao, hemorragia, ritual, pacto, passo
-- relampago, rosa dos lamentos e choques da bola de relampago.

local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Lib = require(script.Parent.Lib)
local Effects = require(script.Parent.Effects)
local Lightning = require(script.Parent.Lightning)

local StrikeFx = {}

local UP = Vector3.new(0, 1, 0)
local GOLD = {
	Core = Color3.fromRGB(255, 252, 230),
	Halo = Color3.fromRGB(255, 205, 90),
	Accent = Color3.fromRGB(255, 150, 50),
	Shape = "",
}

local function randomUnit(): Vector3
	local v = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5)
	return if v.Magnitude > 0.01 then v.Unit else UP
end

local function beamPart(from: Vector3, to: Vector3, width: number, color: Color3, props: { [string]: any }?): Part
	local length = (to - from).Magnitude
	return Lib.part(Vector3.new(width, width, length), color, CFrame.lookAt((from + to) / 2, to), props)
end

---------------------------------------------------------------------------------------------------
-- Tempestade e Chuva de Estrelas

function StrikeFx.barrageStart(p: any)
	local palette = Lib.palette(p.School)
	local sky = p.Position + UP * 32
	if p.Mode == "Storm" then
		local anchor = Lib.anchor(sky, p.Duration + 3)
		local cloud = Lib.emitter(anchor, "Smoke", palette, {
			Color = ColorSequence.new(Color3.fromRGB(46, 50, 70), Color3.fromRGB(20, 22, 34)),
			Size = Lib.seq(10, 16),
			Transparency = Lib.seq(0.25, 1),
			Lifetime = NumberRange.new(2, 3),
			Speed = NumberRange.new(2, 6),
			Acceleration = Vector3.zero,
			SpreadAngle = Vector2.new(180, 15),
			Rate = 18,
		})
		Lib.burst(sky, "Smoke", palette, 20, {
			Color = ColorSequence.new(Color3.fromRGB(46, 50, 70), Color3.fromRGB(20, 22, 34)),
			Size = Lib.seq(12, 18),
			Speed = NumberRange.new(4, 10),
			Acceleration = Vector3.zero,
		})
		task.delay(p.Duration + 0.5, function()
			cloud.Enabled = false
		end)
	else
		local anchor = Lib.anchor(sky, p.Duration + 3)
		local stars = Lib.emitter(
			anchor,
			"Star",
			palette,
			{ Rate = 30, Speed = NumberRange.new(2, 8), Lifetime = NumberRange.new(0.6, 1.2) }
		)
		task.delay(p.Duration + 0.3, function()
			stars.Enabled = false
		end)
	end
	Effects.runeCircle(p.Position + UP * 0.2, palette, p.Radius, p.Duration + 0.4)
end

function StrikeFx.barrageHit(p: any)
	local palette = Lib.palette(p.School)
	if p.Mode == "Storm" then
		local sky = p.Position + Vector3.new(math.random(-6, 6), 32, math.random(-6, 6))
		Lightning.bolt(sky, p.Position, palette, { Width = 0.5, Forks = 4, Flickers = 3, Duration = 0.25 })
		Effects.flash(p.Position + UP, palette, 2.4, true)
		Effects.shockwave(p.Position + UP * 0.2, palette, p.Radius)
		Lib.burst(p.Position, "Spark", palette, 20)
	else
		-- Estrela cadente: cai na diagonal deixando rastro e estoura em luz (a final e maior).
		local scale = if p.Big then 2.4 else 1
		local start = p.Position + Vector3.new(math.random(-14, 14), 40, math.random(-14, 14))
		local star =
			Lib.part(Vector3.one * 1.2 * scale, palette.Core, CFrame.new(start), { Shape = Enum.PartType.Ball })
		local glow = Lib.part(
			Vector3.one * 2.6 * scale,
			palette.Halo,
			CFrame.new(start),
			{ Shape = Enum.PartType.Ball, Transparency = 0.5 }
		)
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, 0.5, 0)
		a0.Parent = star
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, -0.5, 0)
		a1.Parent = star
		local trail = Instance.new("Trail")
		trail.Attachment0, trail.Attachment1 = a0, a1
		trail.Color = ColorSequence.new(palette.Core, palette.Halo)
		trail.LightEmission = 1
		trail.Lifetime = 0.35
		trail.WidthScale = Lib.seq(1, 0)
		trail.Transparency = Lib.seq(0, 1)
		trail.FaceCamera = true
		trail.Parent = star
		local info = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(star, info, { CFrame = CFrame.new(p.Position) }):Play()
		TweenService:Create(glow, info, { CFrame = CFrame.new(p.Position) }):Play()
		task.delay(0.18, function()
			star:Destroy()
			glow:Destroy()
			Effects.flash(p.Position + UP, palette, 2.2 * scale, true)
			Effects.shockwave(p.Position + UP * 0.2, palette, p.Radius)
			Lib.burst(p.Position + UP, "Star", palette, math.floor(22 * scale), { Speed = NumberRange.new(10, 20) })
			if p.Big then
				Effects.runeCircle(p.Position, palette, p.Radius, 0.8)
			end
		end)
	end
end

---------------------------------------------------------------------------------------------------
-- Meteoro e Veredito da Aurora

function StrikeFx.meteorWarn(p: any)
	local palette = Lib.palette(p.School)
	Effects.dangerZone(p.Position, p.Radius, p.Duration, palette.Halo)
	Effects.runeCircle(p.Position + UP * 0.2, palette, p.Radius * 0.7, p.Duration)
	local start = p.Position + Vector3.new(30, 90, 20)
	local rock = Lib.part(Vector3.one * 6, Color3.fromRGB(46, 30, 26), CFrame.new(start), {
		Shape = Enum.PartType.Ball,
		Material = Enum.Material.Basalt,
	})
	local magma = Lib.part(Vector3.one * 6.6, palette.Halo, CFrame.new(start), {
		Shape = Enum.PartType.Ball,
		Material = Enum.Material.ForceField,
	})
	local attachment = Instance.new("Attachment")
	attachment.Parent = rock
	Lib.emitter(attachment, "Flame", palette, { Rate = 120, Size = Lib.seq(6, 4, 0), Speed = NumberRange.new(2, 6) })
	Lib.emitter(attachment, "Smoke", palette, { Rate = 30, Size = Lib.seq(4, 9), Speed = NumberRange.new(1, 4) })
	Lib.emitter(attachment, "Ember", palette, { Rate = 40, Speed = NumberRange.new(6, 14) })
	local light = Instance.new("PointLight")
	light.Color = palette.Halo
	light.Range = 30
	light.Brightness = 3
	light.Parent = rock
	local info = TweenInfo.new(p.Duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	TweenService:Create(rock, info, { CFrame = CFrame.new(p.Position + UP * 2) }):Play()
	TweenService:Create(magma, info, { CFrame = CFrame.new(p.Position + UP * 2) }):Play()
	task.delay(p.Duration, function()
		rock:Destroy()
		magma:Destroy()
	end)
end

function StrikeFx.meteorImpact(p: any, fireGround: (Vector3, Lib.Palette, number, number) -> ())
	local palette = Lib.palette(p.School)
	Effects.flash(p.Position + UP * 2, palette, 7, true)
	Effects.shockwave(p.Position + UP * 0.2, palette, p.Radius * 1.3)
	task.delay(0.1, Effects.shockwave, p.Position + UP * 0.5, palette, p.Radius * 2)
	Lib.burst(p.Position + UP, "Flame", palette, 40, { Speed = NumberRange.new(14, 30), Size = Lib.seq(4, 2, 0) })
	Lib.burst(p.Position + UP, "Smoke", palette, 24, { Speed = NumberRange.new(6, 14), Size = Lib.seq(4, 10) })
	Lib.burst(p.Position + UP, "Blaze", palette, 10, { Speed = NumberRange.new(8, 18), Size = Lib.seq(5, 7) })
	Lib.burst(
		p.Position + UP * 0.3,
		"Ring",
		palette,
		1,
		{ Size = Lib.seq(2, (p.Radius or 6) * 2.6), Lifetime = NumberRange.new(0.5, 0.5) }
	)
	for _ = 1, 10 do
		local chunk =
			Lib.part(Vector3.one * (0.6 + math.random()), Color3.fromRGB(46, 30, 26), CFrame.new(p.Position + UP * 2), {
				Material = Enum.Material.Basalt,
			})
		local dir = randomUnit() * Vector3.new(1, 0, 1) + UP * (0.8 + math.random())
		local landing = p.Position + dir * Vector3.new(p.Radius * 1.6, 0, p.Radius * 1.6)
		TweenService:Create(chunk, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = CFrame.new(landing + UP * 0.3) * CFrame.Angles(math.random() * 6, math.random() * 6, 0),
		}):Play()
		task.delay(2.5, function()
			Lib.fade(chunk, 0.6, { Transparency = 1 })
		end)
	end
	fireGround(p.Position, palette, p.Radius * 0.9, 4)
	Lib.swapGround(p.Position, p.Radius, Enum.Material.CrackedLava, 6)
end

function StrikeFx.verdictWarn(p: any)
	Effects.runeCircle(p.Position + UP * 0.2, GOLD, p.Radius + 2, p.Duration)
	local sun = p.Position + UP * 40
	local disc = Lib.part(Vector3.one * 2, GOLD.Core, CFrame.new(sun), { Shape = Enum.PartType.Ball })
	TweenService:Create(disc, TweenInfo.new(p.Duration), { Size = Vector3.one * 9 }):Play()
	local anchor = Lib.anchor(sun, p.Duration + 1)
	local gather = Lib.emitter(anchor, "Star", GOLD, {
		Rate = 40,
		Speed = NumberRange.new(-14, -8),
		Lifetime = NumberRange.new(0.5, 0.8),
	})
	task.delay(p.Duration, function()
		gather.Enabled = false
		disc:Destroy()
	end)
end

function StrikeFx.verdict(p: any)
	local top = p.Position + UP * 60
	local column = beamPart(top, p.Position, p.Radius * 2.2, GOLD.Core, { Transparency = 0.05 })
	local halo = beamPart(top, p.Position, p.Radius * 3.6, GOLD.Halo, { Transparency = 0.4 })
	Lib.fade(column, 0.7, { Size = Vector3.new(0.2, 0.2, column.Size.Z), Transparency = 1 })
	Lib.fade(halo, 0.9, { Size = Vector3.new(0.4, 0.4, halo.Size.Z), Transparency = 1 })
	Effects.flash(p.Position + UP * 2, GOLD, 6, true)
	Effects.shockwave(p.Position + UP * 0.2, GOLD, p.Radius * 3)
	Lib.burst(p.Position + UP, "Star", GOLD, 40, { Speed = NumberRange.new(12, 26) })
	Lib.burst(p.Position + UP, "Ember", GOLD, 30, { Speed = NumberRange.new(10, 20) })
end

---------------------------------------------------------------------------------------------------
-- Feixes e laminas

-- Raio Arcano: feixe CONTINUO enquanto a canalizacao dura. O servidor manda o ponto final a cada
-- tique (0,1 s); aqui o feixe vive por quadro: sai sempre da gema atual, desliza ate o ponto do
-- servidor (ou segue a mira local, para o proprio jogador), tremula, tem energia correndo por dentro,
-- orbes em espiral, selo na gema e clarao com faiscas onde bate. Apaga em ChannelEnd ou sem tique.
type BeamState = {
	Caster: Model,
	Palette: Lib.Palette,
	To: Vector3,
	Target: Vector3,
	Hit: boolean,
	Range: number,
	Aim: (() -> Vector3)?,
	LastUpdate: number,
	Started: number,
	Core: Part,
	Outer: Part,
	Shell: Part,
	Flow: Beam,
	A0: Attachment,
	A1: Attachment,
	Spiral: { Part },
	MuzzleGlow: Part,
	EndGlow: Part,
	EndAnchor: Attachment,
	Stars: ParticleEmitter,
	Sparks: ParticleEmitter,
	Light: PointLight,
	Seal: Lib.GroundDecal,
	Connection: RBXScriptConnection?,
}

local beams: { [Model]: BeamState } = {}
local BEAM_TIMEOUT = 0.35 -- sem tique do servidor por este tempo: o feixe apaga

local function placeBeam(part: BasePart, from: Vector3, to: Vector3, width: number)
	local length = math.max((to - from).Magnitude, 0.05)
	part.Size = Vector3.new(width, width, length)
	part.CFrame = CFrame.lookAt((from + to) / 2, to)
end

local function endBeam(state: BeamState)
	if beams[state.Caster] == state then
		beams[state.Caster] = nil
	end
	if state.Connection then
		state.Connection:Disconnect()
	end
	state.Stars.Enabled = false
	state.Sparks.Enabled = false
	state.Flow.Enabled = false
	for _, part in { state.Core, state.Outer, state.Shell, state.MuzzleGlow, state.EndGlow } do
		Lib.fade(part, 0.15, { Transparency = 1, Size = part.Size * Vector3.new(0.2, 0.2, 1) })
	end
	for _, orb in state.Spiral do
		orb:Destroy()
	end
	Lib.fade(state.Light, 0.15, { Brightness = 0 })
	Lib.tween(state.Seal.Image, 0.15, { ImageTransparency = 1 })
	Debris:AddItem(state.Seal.Part, 0.2)
	Debris:AddItem(state.A0, 0.2)
	Debris:AddItem(state.EndAnchor, 1)
	Lib.burst(state.To, "Spark", state.Palette, 6, { Color = ColorSequence.new(state.Palette.Halo), Brightness = 1.4 })
end

local function stepBeam(state: BeamState, dt: number)
	local now = os.clock()
	local caster = state.Caster
	if not caster.Parent or now - state.LastUpdate > BEAM_TIMEOUT then
		endBeam(state)
		return
	end
	local palette = state.Palette
	local from = Lib.muzzleOf(caster, state.To)
	local goal = state.Target
	if state.Aim then
		-- Proprio jogador: segue a mira na hora (o servidor confirma o dano no tique).
		local aim = state.Aim()
		local offset = aim - from
		goal = if offset.Magnitude > state.Range then from + offset.Unit * state.Range else aim
		if state.Hit and (state.Target - goal).Magnitude < 6 then
			goal = state.Target -- gruda no alvo que o servidor acertou
		end
	end
	state.To = state.To:Lerp(goal, 1 - math.exp(-dt * 30))
	local to = state.To
	local t = now - state.Started
	local open = math.min(t / 0.08, 1) -- abre rapido no primeiro quadro
	local flicker = 0.95 + 0.05 * math.sin(t * 47) -- laser: firme, so um zumbido leve

	placeBeam(state.Core, from, to, 0.16 * flicker * open)
	placeBeam(state.Outer, from, to, 0.42 * (0.95 + 0.05 * math.sin(t * 23)) * open)
	placeBeam(state.Shell, from, to, 0.9 * (0.9 + 0.1 * math.sin(t * 9)) * open)
	state.A0.WorldPosition = from
	state.A1.WorldPosition = to
	state.EndAnchor.WorldPosition = to

	local direction = (to - from)
	local length = direction.Magnitude
	local frame = CFrame.lookAt(from, to)
	-- Orbes correndo em espiral pelo feixe, da gema ao alvo.
	for i, orb in state.Spiral do
		local phase = (t * 1.6 + i / #state.Spiral) % 1
		local angle = t * 14 + i * math.pi * 2 / #state.Spiral
		local radius = 0.3 * (1 - phase * 0.4)
		orb.CFrame = frame * CFrame.new(math.cos(angle) * radius, math.sin(angle) * radius, -length * phase)
		orb.Transparency = 0.3 + phase * 0.6
	end

	state.MuzzleGlow.CFrame = CFrame.new(from)
	state.MuzzleGlow.Size = Vector3.one * (0.55 + 0.08 * math.sin(t * 31)) * open
	local endSize = if state.Hit then 0.9 else 0.55
	state.EndGlow.CFrame = CFrame.new(to)
	state.EndGlow.Size = Vector3.one * endSize * (0.85 + 0.2 * math.sin(t * 27))
	state.Sparks.Enabled = state.Hit
	state.Stars.Rate = if state.Hit then 14 else 4
	state.Light.Brightness = (if state.Hit then 2 else 1.2) * flicker

	-- Selo de runas na gema, de frente para quem conjura, girando.
	state.Seal.Part.CFrame = frame * CFrame.new(0, 0, -0.4) * CFrame.Angles(math.rad(90), t * 4, 0)
end

local function newBeam(caster: Model, to: Vector3, palette: Lib.Palette): BeamState
	local from = Lib.muzzleOf(caster, to)
	-- Laser: nucleo lilas fino e firme, corpo roxo e brilho externo roxo escuro. Nada de branco
	-- puro (o bloom transformaria o feixe numa mancha branca).
	local coreColor = palette.Halo:Lerp(Color3.new(1, 1, 1), 0.45)
	local glowColor = palette.Halo:Lerp(Color3.new(0, 0, 0), 0.35)
	local core = beamPart(from, to, 0.16, coreColor, { Transparency = 0 })
	local outer = beamPart(from, to, 0.42, palette.Halo, { Transparency = 0.35 })
	local shell = beamPart(from, to, 0.9, glowColor, { Transparency = 0.78 })
	-- Energia correndo por dentro (textura animada ao longo do feixe).
	local a0 = Lib.anchor(from)
	local a1 = Instance.new("Attachment")
	a1.Parent = a0.Parent
	a1.WorldPosition = to
	local flow = Lib.beam(a0, a1, {
		Texture = Lib.Textures.Sparkle,
		TextureMode = Enum.TextureMode.Wrap,
		TextureLength = 3,
		TextureSpeed = 6,
		Width0 = 0.55,
		Width1 = 0.45,
		Brightness = 1.2,
		Color = ColorSequence.new(palette.Halo),
		Transparency = NumberSequence.new(0.55),
	})
	local spiral = {}
	for _ = 1, 2 do
		table.insert(spiral, Lib.part(Vector3.one * 0.14, coreColor, CFrame.new(from), { Shape = Enum.PartType.Ball }))
	end
	local muzzleGlow =
		Lib.part(Vector3.one, palette.Halo, CFrame.new(from), { Shape = Enum.PartType.Ball, Transparency = 0.35 })
	local endGlow =
		Lib.part(Vector3.one, palette.Halo, CFrame.new(to), { Shape = Enum.PartType.Ball, Transparency = 0.45 })
	local endAnchor = Lib.anchor(to)
	local purple = ColorSequence.new(coreColor, palette.Halo)
	local stars = Lib.emitter(endAnchor, "Star", palette, {
		Rate = 6,
		Color = purple,
		Brightness = 1.4,
		Size = Lib.seq(0.35, 0),
		Speed = NumberRange.new(3, 7),
	})
	local sparks = Lib.emitter(endAnchor, "Spark", palette, {
		Rate = 25,
		Enabled = false,
		Color = purple,
		Brightness = 1.6,
		Size = Lib.seq(0.2, 0),
	})
	local light = Instance.new("PointLight")
	light.Color = palette.Halo
	light.Range = 10
	light.Brightness = 1.5
	light.Parent = endGlow
	local seal = Lib.groundDecal(
		from,
		1.6,
		Lib.circleTexture(palette),
		palette.Halo,
		{ Brightness = 1.2, Transparency = 0.25, Lift = 0 }
	)
	Lib.burst(from, "Ring", palette, 1, { Size = Lib.seq(0.4, 2.5), Color = purple, Brightness = 1.4 })
	return {
		Caster = caster,
		Palette = palette,
		To = to,
		Target = to,
		Hit = false,
		Range = 70,
		Aim = nil,
		LastUpdate = os.clock(),
		Started = os.clock(),
		Core = core,
		Outer = outer,
		Shell = shell,
		Flow = flow,
		A0 = a0,
		A1 = a1,
		Spiral = spiral,
		MuzzleGlow = muzzleGlow,
		EndGlow = endGlow,
		EndAnchor = endAnchor,
		Stars = stars,
		Sparks = sparks,
		Light = light,
		Seal = seal,
		Connection = nil,
	}
end

-- Tique do servidor: cria o feixe na primeira vez e atualiza o ponto final/acerto nas seguintes.
-- `aim` (opcional, so o proprio jogador): ponto da mira local, para o feixe seguir sem atraso.
function StrikeFx.arcaneBeam(
	caster: Model,
	to: Vector3,
	palette: Lib.Palette,
	hit: boolean,
	range: number?,
	aim: (() -> Vector3)?
)
	local state = beams[caster]
	if not state then
		local created = newBeam(caster, to, palette)
		beams[caster] = created
		created.Connection = RunService.RenderStepped:Connect(function(dt)
			stepBeam(created, dt)
		end)
		state = created
	end
	local s = state :: BeamState
	if hit and not s.Hit then
		Lib.burst(to, "Spark", palette, 8, { Color = ColorSequence.new(palette.Halo), Brightness = 1.6 }) -- encostou no alvo
	end
	s.Target = to
	s.Hit = hit
	s.Range = range or s.Range
	s.Aim = aim
	s.LastUpdate = os.clock()
end

-- Para o teste de fumaca: anima um quadro de todos os feixes ativos.
function StrikeFx.debugStepBeams(dt: number)
	for _, state in beams do
		stepBeam(state, dt)
	end
end

-- Fim da canalizacao (soltou o botao, sem mana, paralisado...).
function StrikeFx.arcaneBeamEnd(caster: Model)
	local state = beams[caster]
	if state then
		endBeam(state)
	end
end

function StrikeFx.lanceCharge(gem: Vector3, duration: number, palette: Lib.Palette)
	local orb = Lib.part(Vector3.one * 0.3, palette.Core, CFrame.new(gem), { Shape = Enum.PartType.Ball })
	local halo =
		Lib.part(Vector3.one * 0.6, palette.Halo, CFrame.new(gem), { Shape = Enum.PartType.Ball, Transparency = 0.5 })
	TweenService:Create(orb, TweenInfo.new(duration), { Size = Vector3.one * 1.4 }):Play()
	TweenService:Create(halo, TweenInfo.new(duration), { Size = Vector3.one * 3.2 }):Play()
	local anchor = Lib.anchor(gem, duration + 0.5)
	local gather = Lib.emitter(
		anchor,
		"Star",
		palette,
		{ Rate = 60, Speed = NumberRange.new(-10, -6), Lifetime = NumberRange.new(0.3, 0.4) }
	)
	for i = 1, 4 do
		task.delay(i * duration / 5, function()
			Lightning.bolt(
				gem + randomUnit() * 3,
				gem,
				palette,
				{ Width = 0.08, Forks = 0, Flickers = 1, Duration = 0.08, Glow = false }
			)
		end)
	end
	task.delay(duration, function()
		gather.Enabled = false
		orb:Destroy()
		halo:Destroy()
	end)
end

function StrikeFx.firmamentLance(from: Vector3, to: Vector3, palette: Lib.Palette)
	local core = beamPart(from, to, 1.2, palette.Core, { Transparency = 0 })
	local outer = beamPart(from, to, 3.2, palette.Halo, { Transparency = 0.45 })
	local shell = beamPart(from, to, 5, palette.Accent, { Transparency = 0.8 })
	Lib.fade(core, 0.45, { Size = Vector3.new(0.1, 0.1, core.Size.Z), Transparency = 1 })
	Lib.fade(outer, 0.55, { Size = Vector3.new(0.2, 0.2, outer.Size.Z), Transparency = 1 })
	Lib.fade(shell, 0.4, { Size = Vector3.new(7, 7, shell.Size.Z), Transparency = 1 })
	Effects.flash(from, palette, 3, true)
	Effects.flash(to, palette, 3, true)
	local dir = (to - from).Unit
	local length = (to - from).Magnitude
	for d = 4, length, 6 do
		Lib.burst(from + dir * d, "Star", palette, 3, { Speed = NumberRange.new(4, 10) })
	end
end

-- Lamina de Sangue: arco cortante a frente (crescente que varre da direita para a esquerda).
function StrikeFx.bloodSlash(caster: Model, direction: Vector3, reach: number, palette: Lib.Palette)
	local root = Lib.rootPosition(caster)
	if not root then
		return
	end
	local center = root + UP * 0.6
	local base = math.atan2(direction.Z, direction.X)
	local segments = 11
	for i = 0, segments - 1 do
		task.delay(i * 0.012, function()
			local t = i / (segments - 1)
			local angle = base + math.rad(70) - t * math.rad(140)
			local a = center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * reach * 0.55
			local b = center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * reach
			local width = 0.25 + math.sin(t * math.pi) * 0.45
			local blade = beamPart(a, b, width, if i % 2 == 0 then palette.Halo else palette.Core)
			blade.CFrame *= CFrame.Angles(0, 0, math.rad(90))
			Lib.fade(blade, 0.22, { Transparency = 1, Size = Vector3.new(0.05, 0.05, blade.Size.Z) })
		end)
	end
	Lib.burst(center + direction * reach * 0.7, "Spark", palette, 14, { Speed = NumberRange.new(8, 16) })
	Lib.burst(center + direction * reach * 0.6, "Smoke", palette, 4, {
		Color = ColorSequence.new(palette.Halo, palette.Accent),
		Speed = NumberRange.new(2, 5),
	})
end

---------------------------------------------------------------------------------------------------
-- Necromancia

function StrikeFx.summon(position: Vector3, big: boolean, palette: Lib.Palette)
	local size = if big then 4.5 else 3
	Effects.runeCircle(position + UP * 0.15, palette, size, 0.9)
	Lib.burst(position + UP * 0.5, "Spark", palette, if big then 30 else 18, {
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(30, 30),
		Speed = NumberRange.new(10, 20),
	})
	Lib.burst(position + UP * 0.5, "Smoke", palette, 8, {
		Color = ColorSequence.new(palette.Halo, palette.Accent),
		Speed = NumberRange.new(2, 5),
		Size = Lib.seq(2, 4),
	})
	Effects.shockwave(position + UP * 0.1, palette, size * 1.4)
end

function StrikeFx.army(position: Vector3, palette: Lib.Palette)
	Effects.runeCircle(position + UP * 0.15, palette, 12, 2)
	Effects.shockwave(position + UP * 0.1, palette, 16)
	Lib.burst(position + UP, "Wisp", palette, 40, { Speed = NumberRange.new(6, 14) })
end

function StrikeFx.deathTouch(caster: Model, target: Model, palette: Lib.Palette)
	local from = Lib.muzzleOf(caster, Lib.rootPosition(caster) or Vector3.zero)
	local to = Lib.rootPosition(target)
	if not to then
		return
	end
	for _ = 1, 3 do
		Lightning.bolt(from, to + randomUnit(), palette, { Width = 0.12, Forks = 1, Flickers = 2, Duration = 0.15 })
	end
	Effects.flash(to, palette, 2.2, true)
	Lib.burst(to, "Smoke", palette, 14, {
		Color = ColorSequence.new(palette.Accent, Color3.fromRGB(10, 20, 14)),
		Speed = NumberRange.new(3, 7),
		Size = Lib.seq(2, 4),
	})
	Lib.burst(to, "Wisp", palette, 16, { Speed = NumberRange.new(3, 8) })
end

function StrikeFx.curse(p: any)
	local palette = Lib.palette(p.School)
	local cursed =
		{ Core = Color3.fromRGB(240, 220, 255), Halo = Color3.fromRGB(150, 60, 220), Accent = palette.Halo, Shape = "" }
	Effects.runeCircle(p.Position + UP * 0.2, cursed, p.Radius, 1.4)
	Effects.shockwave(p.Position + UP * 0.1, cursed, p.Radius * 1.2)
	Lib.burst(p.Position + UP, "Smoke", cursed, 14, {
		Color = ColorSequence.new(cursed.Halo, palette.Halo),
		Speed = NumberRange.new(2, 6),
		Size = Lib.seq(2, 5),
	})
end

-- Rosa dos Lamentos: rosa sombria que desabrocha aos pes e solta petalas e almas.
function StrikeFx.rose(position: Vector3, palette: Lib.Palette)
	local petalColor = Color3.fromRGB(70, 30, 90)
	local center = position + UP * 0.6
	local petals: { BasePart } = {}
	for layer = 0, 2 do
		for i = 1, 6 do
			local angle = i / 6 * math.pi * 2 + layer * 0.5
			local tilt = math.rad(70 - layer * 22)
			local size = Vector3.new(2.6 - layer * 0.6, 0.15, 1.6 - layer * 0.3)
			local final = CFrame.new(center + UP * layer * 0.35)
				* CFrame.Angles(0, -angle, 0)
				* CFrame.new(size.X * 0.45, 0, 0)
				* CFrame.Angles(0, 0, tilt * 0.6)
			local petal = Lib.part(size, petalColor:Lerp(palette.Halo, layer * 0.15), CFrame.new(center), {
				Material = Enum.Material.SmoothPlastic,
			})
			petal.Size = size * 0.1
			TweenService
				:Create(
					petal,
					TweenInfo.new(0.35 + layer * 0.1, Enum.EasingStyle.Back),
					{ CFrame = final, Size = size }
				)
				:Play()
			table.insert(petals, petal)
		end
	end
	local glow =
		Lib.part(Vector3.one * 1.4, palette.Halo, CFrame.new(center + UP * 0.6), { Shape = Enum.PartType.Ball })
	table.insert(petals, glow)
	Effects.runeCircle(position + UP * 0.15, palette, 5, 1.6)
	Lib.burst(center, "Wisp", palette, 30, { Speed = NumberRange.new(6, 14) })
	task.delay(1.4, function()
		for _, petal in petals do
			local out = (petal.CFrame.Position - center) * Vector3.new(1, 0, 1)
			Lib.fade(petal, 0.6, { Transparency = 1, CFrame = petal.CFrame + out * 2 + UP * 2 })
		end
		Lib.burst(center + UP, "Smoke", palette, 10, {
			Color = ColorSequence.new(petalColor, palette.Halo),
			Speed = NumberRange.new(4, 8),
		})
	end)
end

---------------------------------------------------------------------------------------------------
-- Controle

function StrikeFx.prison(position: Vector3, size: number, duration: number, palette: Lib.Palette)
	local half = size / 2
	local center = position + Vector3.new(0, half - 0.5, 0)
	local parts: { BasePart } = {}
	local corners = {}
	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			for _, z in { -1, 1 } do
				table.insert(corners, center + Vector3.new(x, y, z) * half)
			end
		end
	end
	for i = 1, #corners do
		for j = i + 1, #corners do
			local a, b = corners[i], corners[j]
			local diff = b - a
			local axes = (if math.abs(diff.X) > 0.1 then 1 else 0)
				+ (if math.abs(diff.Y) > 0.1 then 1 else 0)
				+ (if math.abs(diff.Z) > 0.1 then 1 else 0)
			if axes == 1 then
				table.insert(parts, beamPart(a, b, 0.3, palette.Core))
			end
		end
	end
	local walls = Lib.part(Vector3.one * size, palette.Halo, CFrame.new(center), {
		Material = Enum.Material.ForceField,
		Transparency = 0.1,
	})
	table.insert(parts, walls)
	for _, part in parts do
		local final = part.Size
		part.Size = final * 0.05
		TweenService:Create(part, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Size = final }):Play()
	end
	Effects.flash(center, palette, 2, true)
	task.delay(duration, function()
		Lib.burst(center, "Star", palette, 30, { Speed = NumberRange.new(8, 18) })
		for _, part in parts do
			Lib.fade(part, 0.3, { Transparency = 1, Size = part.Size * 1.3 })
		end
	end)
end

-- Anzol (Meat Hook): o gancho voa ate `to` em `travel` s; fisgou = volta arrastando o alvo;
-- errou = recolhe vazio.
function StrikeFx.hook(caster: Model, target: Model?, to: Vector3, palette: Lib.Palette, travelTime: number?)
	local from = Lib.muzzleOf(caster, Lib.rootPosition(caster) or Vector3.zero)
	local head = Lib.part(Vector3.new(0.6, 0.6, 1.2), palette.Halo, CFrame.lookAt(from, to))
	local line = beamPart(from, from + (to - from).Unit * 0.1, 0.18, palette.Accent)
	local travel = travelTime or 0.15
	if not target then
		-- Errou: chega ao fim e volta.
		TweenService:Create(head, TweenInfo.new(travel), { CFrame = CFrame.lookAt(to, to + (to - from).Unit) }):Play()
		task.delay(travel, function()
			Lib.burst(to, "Spark", palette, 4)
			TweenService:Create(head, TweenInfo.new(travel * 0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				CFrame = CFrame.new(Lib.muzzleOf(caster, from)),
			}):Play()
		end)
		task.spawn(function()
			local untilTime = os.clock() + travel * 1.8
			while os.clock() < untilTime and head.Parent do
				local a = Lib.muzzleOf(caster, Lib.rootPosition(caster) or from)
				local b = head.CFrame.Position
				line.Size = Vector3.new(0.18, 0.18, math.max((b - a).Magnitude, 0.1))
				line.CFrame = CFrame.lookAt((a + b) / 2, b)
				task.wait()
			end
			head:Destroy()
			line:Destroy()
		end)
		return
	end
	TweenService:Create(head, TweenInfo.new(travel), { CFrame = CFrame.lookAt(to, to + (to - from).Unit) }):Play()
	task.spawn(function()
		local started = os.clock()
		local pullUntil = started + travel + 0.8
		while os.clock() < pullUntil do
			local a = Lib.muzzleOf(caster, Lib.rootPosition(caster) or from)
			local b = head.CFrame.Position
			if target and target.Parent and os.clock() > started + travel then
				b = Lib.rootPosition(target) or b
				head.CFrame = CFrame.new(b)
			end
			local length = (b - a).Magnitude
			line.Size = Vector3.new(0.18, 0.18, math.max(length, 0.1))
			line.CFrame = CFrame.lookAt((a + b) / 2, b)
			task.wait()
		end
		Lib.fade(head, 0.15, { Transparency = 1 })
		Lib.fade(line, 0.15, { Transparency = 1 })
	end)
	task.delay(travel, function()
		Effects.flash(to, palette, 1.4, false)
		Lib.burst(to, "Spark", palette, 10)
	end)
end

function StrikeFx.hemorrhage(position: Vector3, radius: number, palette: Lib.Palette)
	Effects.flash(position, palette, 1.8, true)
	Effects.shockwave(position - UP * 2, palette, radius)
	Lib.burst(position, "Spark", palette, 24, { Acceleration = Vector3.new(0, -50, 0), Speed = NumberRange.new(8, 16) })
	Lib.burst(position, "Smoke", palette, 8, {
		Color = ColorSequence.new(palette.Halo, palette.Accent),
		Speed = NumberRange.new(2, 6),
	})
end

function StrikeFx.miss(position: Vector3, palette: Lib.Palette)
	Lib.burst(position, "Wisp", palette, 6, { Speed = NumberRange.new(1, 3) })
end

---------------------------------------------------------------------------------------------------
-- Sangue: ritual e pacto

function StrikeFx.ritual(caster: Model, position: Vector3, radius: number, palette: Lib.Palette)
	local ground = Lib.groundBelow(position, caster)
	Effects.runeCircle(ground + UP * 0.2, palette, radius, 1)
	Effects.runeCircle(ground + UP * 0.25, palette, radius * 0.5, 1)
	task.delay(0.35, function()
		Effects.flash(position, palette, 4, true)
		Effects.shockwave(ground + UP * 0.1, palette, radius * 1.3)
		for i = 1, 12 do
			local angle = i / 12 * math.pi * 2
			local at = ground + Vector3.new(math.cos(angle), 0, math.sin(angle)) * radius * 0.8
			local spike = Lib.part(Vector3.new(0.5, 3.5, 0.5), palette.Halo, CFrame.new(at - UP * 2))
			TweenService
				:Create(spike, TweenInfo.new(0.1, Enum.EasingStyle.Back), { CFrame = CFrame.new(at + UP * 1.5) })
				:Play()
			task.delay(0.6, function()
				Lib.fade(spike, 0.3, { Transparency = 1, CFrame = CFrame.new(at - UP * 1) })
			end)
		end
		Lib.burst(position, "Smoke", palette, 20, {
			Color = ColorSequence.new(palette.Halo, palette.Accent),
			Speed = NumberRange.new(6, 14),
			Size = Lib.seq(2, 5),
		})
	end)
end

function StrikeFx.pact(caster: Model, allies: { Model }, palette: Lib.Palette)
	local root = Lib.rootPosition(caster)
	if not root then
		return
	end
	Effects.runeCircle(Lib.groundBelow(root, caster) + UP * 0.2, palette, 3, 1.2)
	Effects.flash(root, palette, 2.4, true)
	for _, ally in allies do
		local other = Lib.rootPosition(ally)
		if other then
			Effects.runeCircle(Lib.groundBelow(other, ally) + UP * 0.2, palette, 3, 1.2)
			Lightning.braid(root, other, palette, 4, 0.5)
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Eletricidade

function StrikeFx.lightningStep(from: Vector3, to: Vector3, palette: Lib.Palette)
	Lightning.braid(from, to, palette, 6, 0.25)
	Effects.flash(from, palette, 2, false)
	Effects.flash(to, palette, 2.2, true)
	Lib.burst(from, "Spark", palette, 16)
	Lib.burst(to, "Spark", palette, 20)
	local dir = to - from
	for d = 0, dir.Magnitude, 3 do
		Lib.burst(from + dir.Unit * d - UP * 2.5, "Spark", palette, 3, { Speed = NumberRange.new(3, 8) })
	end
end

function StrikeFx.orbShock(from: Vector3, points: { Vector3 }, palette: Lib.Palette)
	for _, point in points do
		Lightning.bolt(from, point, palette, { Width = 0.14, Forks = 1, Flickers = 2, Duration = 0.12 })
		Lib.burst(point, "Spark", palette, 6)
	end
end

function StrikeFx.crownBolt(from: Vector3, to: Vector3, palette: Lib.Palette)
	Lightning.bolt(from, to, palette, { Width = 0.3, Forks = 3, Flickers = 2, Duration = 0.2 })
	Effects.flash(to, palette, 1.8, true)
	Lib.burst(to, "Spark", palette, 14)
end

return StrikeFx
