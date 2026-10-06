--!strict
-- Animacao procedural da esquiva (passo arcano), por cima da animacao normal do personagem R15:
-- antecipacao rapida (agacha), impulso inclinado na direcao do movimento com as pernas recolhidas e
-- o braco livre jogado para tras, e recuperacao suave. O cajado segue na mao (IK do Vfx/Staff).
-- Direcao em espaco de mundo; a inclinacao e calculada no espaco do personagem a cada quadro.

local RunService = game:GetService("RunService")

local MotorOverlay = require(script.Parent.MotorOverlay)

local DodgeAnim = {}

local DURATION = 0.42
local ATTACK = 0.07 -- tempo ate a pose cheia
local LEAN = 0.5 -- radianos de inclinacao do corpo
local CROUCH = 0.9 -- studs que o quadril desce

type Active = {
	Model: Model,
	Started: number,
	Direction: Vector3,
	Motors: { [string]: Motor6D },
}

local active: { [Model]: Active } = {}

local MOTORS: { [string]: string } = {
	Root = "LowerTorso",
	Waist = "UpperTorso",
	LeftHip = "LeftUpperLeg",
	RightHip = "RightUpperLeg",
	LeftKnee = "LeftLowerLeg",
	RightKnee = "RightLowerLeg",
	LeftShoulder = "LeftUpperArm",
}

-- 0 -> 1 rapido (ease-out) e 1 -> 0 suave (smoothstep).
local function envelope(t: number): number
	if t < ATTACK then
		local x = t / ATTACK
		return 1 - (1 - x) * (1 - x)
	end
	local x = math.clamp((t - ATTACK) / (DURATION - ATTACK), 0, 1)
	return 1 - x * x * (3 - 2 * x)
end

function DodgeAnim.play(character: Model, direction: Vector3)
	local motors: { [string]: Motor6D } = {}
	for motorName, partName in MOTORS do
		local part = character:FindFirstChild(partName)
		local motor = part and part:FindFirstChild(motorName)
		if motor and motor:IsA("Motor6D") then
			motors[motorName] = motor
		end
	end
	local flat = Vector3.new(direction.X, 0, direction.Z)
	active[character] = {
		Model = character,
		Started = os.clock(),
		Direction = if flat.Magnitude > 0.01 then flat.Unit else Vector3.zAxis,
		Motors = motors,
	}
end

local function step()
	local now = os.clock()
	for model, entry in active do
		local t = now - entry.Started
		local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
		if t > DURATION or not model.Parent or not root then
			active[model] = nil
			continue
		end
		local e = envelope(t)
		-- Direcao no espaco do personagem: frente = -Z, direita = +X.
		local d = root.CFrame:VectorToObjectSpace(entry.Direction)
		local leanX = d.Z * LEAN * e -- para frente: tronco tomba para frente
		local leanZ = -d.X * LEAN * e -- para o lado: tronco tomba para o lado
		local m = entry.Motors
		if m.Root then
			MotorOverlay.apply(
				m.Root,
				CFrame.new(d.X * 0.3 * e, -CROUCH * e, d.Z * 0.3 * e) * CFrame.Angles(leanX, 0, leanZ)
			)
		end
		if m.Waist then
			MotorOverlay.apply(m.Waist, CFrame.Angles(leanX * 0.4, 0, leanZ * 0.4))
		end
		-- Pernas recolhidas (coxa para a frente, canela para tras), assimetricas como um passo.
		if m.LeftHip then
			MotorOverlay.apply(m.LeftHip, CFrame.Angles(1.1 * e, 0, 0))
		end
		if m.RightHip then
			MotorOverlay.apply(m.RightHip, CFrame.Angles(0.6 * e, 0, 0))
		end
		if m.LeftKnee then
			MotorOverlay.apply(m.LeftKnee, CFrame.Angles(-1.4 * e, 0, 0))
		end
		if m.RightKnee then
			MotorOverlay.apply(m.RightKnee, CFrame.Angles(-0.9 * e, 0, 0))
		end
		-- Braco livre (esquerdo) jogado para tras e para fora.
		if m.LeftShoulder then
			MotorOverlay.apply(m.LeftShoulder, CFrame.Angles(-0.9 * e, 0, -0.5 * e))
		end
	end
end

function DodgeAnim.start()
	RunService.Stepped:Connect(step)
end

-- Para o teste de fumaca: um quadro.
function DodgeAnim.debugStep()
	step()
end

return DodgeAnim
