--!strict
-- Poses do cajado no espaco do HumanoidRootPart (+X direita, +Y cima, -Z frente).
-- Fonte UNICA da origem das magias: o servidor (Targeting.muzzle) e o cliente (Vfx/Lib.muzzleOf)
-- usam a mesma conta, entao toda magia sai exatamente da gema que o jogador ve.
-- Em cada pose o cajado aponta para +Y local; a gema fica a GEM_DISTANCE do centro da haste.

local StaffPose = {}

StaffPose.SHAFT_LENGTH = 4.8
StaffPose.GEM_DISTANCE = StaffPose.SHAFT_LENGTH / 2 + 0.75
StaffPose.GRIP_DISTANCE = -0.45 -- onde a mao segura (abaixo do centro da haste)

-- O cajado e construido deitado no eixo X; AXIS o deixa em pe (X -> Y).
StaffPose.AXIS = CFrame.Angles(0, 0, math.rad(90))

StaffPose.Poses = table.freeze({
	-- Em pe ao lado direito, levemente inclinado a frente. A empunhadura fica ao alcance da mao
	-- com o braco relaxado (~1,8 stud abaixo do ombro).
	Idle = CFrame.new(1.25, 0.1, -0.5) * CFrame.Angles(math.rad(-8), 0, math.rad(-4)),
	-- Apontado a frente como uma varinha, gema na altura da cabeca; braco meio estendido.
	Cast = CFrame.new(1.1, 1.05, -1.85) * CFrame.Angles(math.rad(-55), 0, math.rad(-6)),
})

-- Posicao da gema (no mundo) dado o CFrame do HumanoidRootPart e a pose.
function StaffPose.gemWorld(rootCFrame: CFrame, poseName: string?): Vector3
	local pose = StaffPose.Poses[poseName or "Cast"] or StaffPose.Poses.Cast
	return (rootCFrame * pose * CFrame.new(0, StaffPose.GEM_DISTANCE, 0)).Position
end

return table.freeze(StaffPose)
