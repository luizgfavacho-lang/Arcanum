--!strict
-- Leva a mao (direita ou esquerda) de um personagem R15 a um ponto do mundo, sobrescrevendo
-- (ou misturando com) a animacao do braco. Deve ser chamado em RunService.Stepped (depois da animacao e antes da fisica),
-- a cada quadro: so altera Motor6D.Transform, que o Animator reescreve no quadro seguinte.
--
-- ArmIK assume ossos apontando para -Y; no rig real os ossos tem desvios (ex.: ombro deslocado em X).
-- Por isso cada osso ganha uma rotacao de correcao que alinha seu vetor real com -Y.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArmIK = require(ReplicatedStorage.Shared.Math.ArmIK)

export type Rig = {
	Torso: BasePart,
	Shoulder: Motor6D,
	Elbow: Motor6D,
	Wrist: Motor6D,
	Upper: number,
	Lower: number,
	AlignUpper: CFrame, -- leva o osso superior para -Y
	ElbowFix: CFrame, -- (AlignUpper * rotacao fixa entre as juntas)^-1
	AlignLower: CFrame, -- leva o osso inferior (cotovelo -> centro da mao) para -Y
}

local HandIK = {}

local DOWN = Vector3.new(0, -1, 0)

-- Rotacao que leva a direcao de `v` para -Y.
local function alignToDown(v: Vector3): CFrame
	local unit = v.Unit
	local axis = unit:Cross(DOWN)
	if axis.Magnitude < 1e-6 then
		return if unit:Dot(DOWN) > 0 then CFrame.identity else CFrame.Angles(math.pi, 0, 0)
	end
	return CFrame.fromAxisAngle(axis.Unit, math.acos(math.clamp(unit:Dot(DOWN), -1, 1)))
end

local function rotationOnly(cf: CFrame): CFrame
	return cf - cf.Position
end

-- Le as juntas e a geometria do braco (nil se nao for R15). side = "Right" ou "Left".
function HandIK.rig(character: Model, side: string?): Rig?
	local s = side or "Right"
	local torso = character:FindFirstChild("UpperTorso") :: BasePart?
	local upperArm = character:FindFirstChild(s .. "UpperArm")
	local lowerArm = character:FindFirstChild(s .. "LowerArm")
	local hand = character:FindFirstChild(s .. "Hand")
	local shoulder = upperArm and upperArm:FindFirstChild(s .. "Shoulder") :: Motor6D?
	local elbow = lowerArm and lowerArm:FindFirstChild(s .. "Elbow") :: Motor6D?
	local wrist = hand and hand:FindFirstChild(s .. "Wrist") :: Motor6D?
	if not torso or not shoulder or not elbow or not wrist then
		return nil
	end
	-- Ombro -> cotovelo (no quadro da junta do ombro) e cotovelo -> centro da mao (no quadro do cotovelo).
	local betweenJoints = shoulder.C1:Inverse() * elbow.C0
	local upperVector = betweenJoints.Position
	local lowerVector = (elbow.C1:Inverse() * wrist.C0 * wrist.C1:Inverse()).Position
	local alignUpper = alignToDown(upperVector)
	return {
		Torso = torso,
		Shoulder = shoulder,
		Elbow = elbow,
		Wrist = wrist,
		Upper = upperVector.Magnitude,
		Lower = lowerVector.Magnitude,
		AlignUpper = alignUpper,
		ElbowFix = (alignUpper * rotationOnly(betweenJoints)):Inverse(),
		AlignLower = alignToDown(lowerVector),
	}
end

function HandIK.shoulderPosition(rig: Rig): Vector3
	return (rig.Torso.CFrame * rig.Shoulder.C0).Position
end

function HandIK.reach(rig: Rig): number
	return rig.Upper + rig.Lower
end

-- Coloca o centro da mao no alvo (mundo). weight < 1 mistura com a animacao atual do braco.
function HandIK.apply(rig: Rig, target: Vector3, weight: number?)
	local w = math.clamp(weight or 1, 0, 1)
	local shoulderFrame = rig.Torso.CFrame * rig.Shoulder.C0
	local plane, shoulderAngle, elbowAngle = ArmIK.solve(shoulderFrame, target, rig.Upper, rig.Lower)
	local joint = plane * CFrame.Angles(shoulderAngle, 0, 0) * rig.AlignUpper
	local shoulderT = rig.Shoulder.C0:Inverse() * rig.Torso.CFrame:ToObjectSpace(joint)
	local elbowT = rig.ElbowFix * CFrame.Angles(elbowAngle, 0, 0) * rig.AlignLower
	if w >= 0.999 then
		rig.Shoulder.Transform = shoulderT
		rig.Elbow.Transform = elbowT
		rig.Wrist.Transform = CFrame.identity
	else
		rig.Shoulder.Transform = rig.Shoulder.Transform:Lerp(shoulderT, w)
		rig.Elbow.Transform = rig.Elbow.Transform:Lerp(elbowT, w)
		rig.Wrist.Transform = rig.Wrist.Transform:Lerp(CFrame.identity, w)
	end
end

return HandIK
