--!strict
-- IK de dois ossos (ombro -> cotovelo -> mao), puro e testado em tests/ArmIK.spec.luau.
-- Convencao (rig R15): no repouso o braco aponta para -Y a partir da junta do ombro.
-- Dado o CFrame da junta do ombro e o alvo da mao, devolve:
--   plane: CFrame do ombro virado para o alvo (-Z aponta para o alvo)
--   shoulderAngle: rotacao em X a aplicar depois de `plane`
--   elbowAngle: rotacao em X do cotovelo
-- A mao fica em: plane * Angles(shoulderAngle,0,0) * (0,-upper,0) -> * Angles(elbowAngle,0,0) * (0,-lower,0)

local ArmIK = {}

function ArmIK.solve(shoulder: CFrame, target: Vector3, upper: number, lower: number): (CFrame, number, number)
	local localTarget = shoulder:PointToObjectSpace(target)
	local distance = localTarget.Magnitude
	if distance < 1e-4 then
		return shoulder, 0, 0
	end
	local unit = localTarget.Unit
	local forward = Vector3.new(0, 0, -1)
	local axis = forward:Cross(unit)
	local angle = math.acos(math.clamp(-unit.Z, -1, 1))
	local plane = if axis.Magnitude > 1e-6 then shoulder * CFrame.fromAxisAngle(axis.Unit, angle) else shoulder

	local longest, shortest = math.max(upper, lower), math.min(upper, lower)
	if distance < longest - shortest then
		-- Alvo perto demais: dobra ao maximo.
		return plane * CFrame.new(0, 0, longest - shortest - distance), -math.pi / 2, math.pi
	elseif distance > upper + lower then
		-- Alvo longe demais: braco esticado na direcao do alvo.
		return plane, math.pi / 2, 0
	end
	local a1 =
		-math.acos(math.clamp((-(lower * lower) + upper * upper + distance * distance) / (2 * upper * distance), -1, 1))
	local a2 =
		math.acos(math.clamp((lower * lower - upper * upper + distance * distance) / (2 * lower * distance), -1, 1))
	return plane, a1 + math.pi / 2, a2 - a1
end

-- Ponta da mao resultante (usada nos testes).
function ArmIK.handPosition(
	plane: CFrame,
	shoulderAngle: number,
	elbowAngle: number,
	upper: number,
	lower: number
): Vector3
	local elbow = plane * CFrame.Angles(shoulderAngle, 0, 0) * CFrame.new(0, -upper, 0)
	return (elbow * CFrame.Angles(elbowAngle, 0, 0) * CFrame.new(0, -lower, 0)).Position
end

return ArmIK
