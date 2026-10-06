--!strict
-- Piromania (lanca-chamas canalizado), so visual. O servidor manda a direcao a cada tique; aqui o jato
-- vive por quadro, preso a gema e apontado para a mira (local, para o proprio jogador):
--   * labaredas em flipbook (branco-amarelo na boca -> laranja -> vermelho escuro) que abrem em cone,
--     desaceleram no fim do alcance e sobem um pouco;
--   * fogo pintado colorido por dentro, nucleo quente na boca, brasas e fumaca escura no fim;
--   * luz laranja tremendo ao longo do jato, chamas lambendo o chao onde o jato bate;
--   * labareda extra e brasas em cada inimigo atingido; som de fogo em laco.
-- Apaga em ChannelEnd ou sem tique do servidor.

local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Lib = require(script.Parent.Lib)
local Audio = require(script.Parent.Audio)

local FlameFx = {}

local TIMEOUT = 0.4 -- sem tique do servidor por este tempo: apaga
local REFERENCE_RANGE = 21.4 -- studs (6 m); as velocidades abaixo foram ajustadas para ele
local GROUND_LICK_INTERVAL = 0.3

-- Cores do fogo (fixas: e fogo de verdade, nao a cor da escola).
local HOT = Color3.fromRGB(255, 244, 200)
local YELLOW = Color3.fromRGB(255, 196, 70)
local ORANGE = Color3.fromRGB(255, 110, 25)
local RED = Color3.fromRGB(170, 30, 10)
local SOOT = Color3.fromRGB(40, 22, 18)

type State = {
	Caster: Model,
	Palette: Lib.Palette,
	Direction: Vector3,
	From: Vector3, -- ultima posicao da boca (gema)
	Range: number,
	Aim: (() -> Vector3)?,
	LastUpdate: number,
	Started: number,
	Nozzle: Attachment,
	Mid: Attachment,
	Emitters: { ParticleEmitter },
	Light: PointLight,
	NozzleLight: PointLight,
	Sound: Sound?,
	NextLick: number,
	Connection: RBXScriptConnection?,
}

local states: { [Model]: State } = {}

local function fireColors(): ColorSequence
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, HOT),
		ColorSequenceKeypoint.new(0.15, YELLOW),
		ColorSequenceKeypoint.new(0.45, ORANGE),
		ColorSequenceKeypoint.new(0.8, RED),
		ColorSequenceKeypoint.new(1, SOOT),
	})
end

local function build(caster: Model, palette: Lib.Palette, range: number): State
	local from = Lib.muzzleOf(caster, Lib.rootPosition(caster) or Vector3.zero)
	local nozzle = Lib.anchor(from)
	local mid = Lib.anchor(from)
	local k = range / REFERENCE_RANGE -- escala de velocidade para outros alcances
	local front = Enum.NormalId.Front

	local emitters = {
		-- Corpo do jato: labaredas animadas que abrem em cone.
		Lib.emitter(nozzle, "Flame", palette, {
			EmissionDirection = front,
			Color = fireColors(),
			Brightness = 1.8,
			Rate = 110,
			Speed = NumberRange.new(42 * k, 48 * k),
			Drag = 1.2,
			Lifetime = NumberRange.new(0.55, 0.7),
			SpreadAngle = Vector2.new(7, 7),
			Size = Lib.seq(0.5, 1.8, 3.6, 4.6),
			Transparency = Lib.seq(0.35, 0.05, 0.25, 1),
			Acceleration = Vector3.new(0, 7, 0),
			RotSpeed = NumberRange.new(-120, 120),
			Rotation = NumberRange.new(0, 360),
		}),
		-- Fogo pintado por dentro (textura colorida, da "corpo" as chamas).
		Lib.emitter(nozzle, "Blaze", palette, {
			EmissionDirection = front,
			Brightness = 1.3,
			Rate = 40,
			Speed = NumberRange.new(38 * k, 44 * k),
			Drag = 1.2,
			Lifetime = NumberRange.new(0.5, 0.65),
			SpreadAngle = Vector2.new(9, 9),
			Size = Lib.seq(0.8, 2.6, 4.2),
			Transparency = Lib.seq(0.3, 0.1, 1),
			Acceleration = Vector3.new(0, 9, 0),
			Rotation = NumberRange.new(-25, 25),
		}),
		-- Nucleo quente logo na boca (azulado no centro, como gas queimando).
		Lib.emitter(nozzle, "Glow", palette, {
			EmissionDirection = front,
			Color = ColorSequence.new(Color3.fromRGB(190, 215, 255), YELLOW),
			Brightness = 1.6,
			Rate = 50,
			Speed = NumberRange.new(14, 18),
			Lifetime = NumberRange.new(0.1, 0.14),
			SpreadAngle = Vector2.new(4, 4),
			Size = Lib.seq(0.5, 1.1, 0),
			Transparency = Lib.seq(0.2, 1),
		}),
		-- Brasas voando alem do fogo.
		Lib.emitter(nozzle, "Ember", palette, {
			EmissionDirection = front,
			Color = ColorSequence.new(YELLOW, RED),
			Brightness = 2,
			Rate = 35,
			Speed = NumberRange.new(30 * k, 46 * k),
			Drag = 0.9,
			Lifetime = NumberRange.new(0.6, 1.1),
			SpreadAngle = Vector2.new(14, 14),
			Size = Lib.seq(0.22, 0.15, 0),
		}),
		-- Fumaca escura saindo do fim do jato.
		Lib.emitter(nozzle, "Smoke", palette, {
			EmissionDirection = front,
			Color = ColorSequence.new(Color3.fromRGB(70, 58, 54), Color3.fromRGB(30, 26, 26)),
			Rate = 16,
			Speed = NumberRange.new(36 * k, 42 * k),
			Drag = 1.3,
			Lifetime = NumberRange.new(1, 1.4),
			SpreadAngle = Vector2.new(10, 10),
			Size = Lib.seq(1, 3, 6),
			Transparency = Lib.seq(1, 0.6, 1),
			Acceleration = Vector3.new(0, 10, 0),
		}),
	}

	local light = Instance.new("PointLight")
	light.Color = ORANGE
	light.Range = 18
	light.Brightness = 2.5
	light.Parent = mid
	local nozzleLight = Instance.new("PointLight")
	nozzleLight.Color = YELLOW
	nozzleLight.Range = 8
	nozzleLight.Brightness = 2
	nozzleLight.Parent = nozzle

	-- Ignicao: baforada curta.
	Lib.burst(from, "Blaze", palette, 3, { Size = Lib.seq(1, 2.5), Speed = NumberRange.new(2, 5), Brightness = 1.3 })

	return {
		Caster = caster,
		Palette = palette,
		Direction = Vector3.zAxis,
		From = from,
		Range = range,
		Aim = nil,
		LastUpdate = os.clock(),
		Started = os.clock(),
		Nozzle = nozzle,
		Mid = mid,
		Emitters = emitters,
		Light = light,
		NozzleLight = nozzleLight,
		Sound = Audio.loop("Flamethrower", nozzle),
		NextLick = 0,
		Connection = nil,
	}
end

local function stop(state: State)
	if states[state.Caster] == state then
		states[state.Caster] = nil
	end
	if state.Connection then
		state.Connection:Disconnect()
	end
	for _, e in state.Emitters do
		e.Enabled = false
	end
	Lib.fade(state.Light, 0.25, { Brightness = 0 })
	Lib.fade(state.NozzleLight, 0.15, { Brightness = 0 })
	Audio.stopLoop(state.Sound)
	-- Particulas ja lancadas terminam o voo antes de apagar o anexo.
	Debris:AddItem(state.Nozzle, 1.6)
	Debris:AddItem(state.Mid, 0.3)
	Lib.burst(Lib.muzzleOf(state.Caster, state.From), "Smoke", state.Palette, 4, {
		Size = Lib.seq(0.5, 2),
		Speed = NumberRange.new(1, 3),
	})
end

-- Chamas lambendo o chao onde o jato bate (leve: um emissor curto).
local function groundLick(from: Vector3, direction: Vector3, range: number, caster: Model)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { caster, Lib.folder() }
	local hit = Workspace:Raycast(from, direction * range, params)
	if not hit or hit.Instance:FindFirstAncestorOfClass("Model") then
		return
	end
	local anchor = Lib.anchor(hit.Position + Vector3.new(0, 0.4, 0), 1.6)
	local lick = Lib.emitter(anchor, "Flame", Lib.palette("Fire"), {
		Color = fireColors(),
		Brightness = 1.6,
		Rate = 18,
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(25, 25),
		Speed = NumberRange.new(2, 5),
		Size = Lib.seq(1.4, 2, 0.5),
	})
	task.delay(0.7, function()
		lick.Enabled = false
	end)
end

local function step(state: State, dt: number)
	local now = os.clock()
	local caster = state.Caster
	if not caster.Parent or now - state.LastUpdate > TIMEOUT then
		stop(state)
		return
	end
	local from = Lib.muzzleOf(caster, state.From)
	state.From = from
	local goal = state.Direction
	if state.Aim then
		local offset = state.Aim() - from
		if offset.Magnitude > 1e-3 then
			goal = offset.Unit
		end
	end
	-- Mira suave (o jato acompanha a mira com um leve atraso de mangueira).
	local direction = state.Direction:Lerp(goal, 1 - math.exp(-dt * 18))
	direction = if direction.Magnitude > 1e-3 then direction.Unit else goal
	state.Direction = direction
	-- Anexos no Terrain (na origem): CFrame/Position ja sao coordenadas de mundo (como Lib.anchor).
	state.Nozzle.CFrame = CFrame.lookAt(from, from + direction)
	state.Mid.Position = from + direction * state.Range * 0.55

	local t = now - state.Started
	local flicker = 0.8 + 0.2 * math.sin(t * 31) + 0.15 * math.sin(t * 13.7)
	state.Light.Brightness = 2.4 * flicker
	state.NozzleLight.Brightness = 1.8 * flicker

	if now >= state.NextLick then
		state.NextLick = now + GROUND_LICK_INTERVAL
		groundLick(from, direction, state.Range, caster)
	end
end

-- Tique do servidor: cria o jato na primeira vez e atualiza direcao/alcance/acertos.
function FlameFx.update(p: any, aim: (() -> Vector3)?)
	local caster: Model? = p.Caster
	if not caster or not caster.Parent then
		return
	end
	local palette = Lib.palette(p.School)
	local state = states[caster]
	if not state then
		local created = build(caster, palette, p.Range or REFERENCE_RANGE)
		created.Direction = p.Direction or Vector3.zAxis
		states[caster] = created
		created.Connection = RunService.RenderStepped:Connect(function(dt)
			step(created, dt)
		end)
		state = created
	end
	local s = state :: State
	if not s.Aim then
		s.Direction = p.Direction or s.Direction -- outros jogadores: direcao do servidor
	end
	s.Aim = aim
	s.Range = p.Range or s.Range
	s.LastUpdate = os.clock()
	-- Inimigos atingidos: labareda envolvendo e brasas.
	for _, position in p.Hits or {} do
		if math.random() < 0.6 then
			Lib.burst(position, "Blaze", palette, 1, { Size = Lib.seq(2, 3.5), Brightness = 1.3 })
		end
		Lib.burst(position, "Ember", palette, 3, { Speed = NumberRange.new(4, 9), Brightness = 2 })
	end
end

function FlameFx.stop(caster: Model)
	local state = states[caster]
	if state then
		stop(state)
	end
end

-- Para o teste de fumaca: anima um quadro de todos os jatos ativos.
function FlameFx.debugStep(dt: number)
	for _, state in states do
		step(state, dt)
	end
end

return FlameFx
