--!strict
-- Regras de progressao PURAS, testadas em tests/ProgressionMath.spec.luau.
-- A curva oficial esta em Data/Levels.csv; validate_data.py garante que ela bate com esta formula.

local ProgressionMath = {}

ProgressionMath.MAX_LEVEL = 50
ProgressionMath.LEVELS_PER_SKILL_POINT = 5
ProgressionMath.MAX_AFFINITY = 10

-- XP para ir de level a level+1: round(50 * level^1.5). 0 no nivel maximo.
function ProgressionMath.xpToNextLevel(level: number): number
	if level < 1 or level >= ProgressionMath.MAX_LEVEL then
		return 0
	end
	return math.round(50 * level ^ 1.5)
end

function ProgressionMath.skillPointsAtLevel(level: number): number
	return math.clamp(level, 0, ProgressionMath.MAX_LEVEL) // ProgressionMath.LEVELS_PER_SKILL_POINT
end

-- Aplica XP: devolve (novo nivel, XP restante).
function ProgressionMath.applyXP(level: number, xp: number): (number, number)
	level = math.clamp(level, 1, ProgressionMath.MAX_LEVEL)
	while level < ProgressionMath.MAX_LEVEL do
		local needed = ProgressionMath.xpToNextLevel(level)
		if xp < needed then
			break
		end
		xp -= needed
		level += 1
	end
	if level >= ProgressionMath.MAX_LEVEL then
		xp = 0
	end
	return level, xp
end

-- Usos da escola para subir de afinidade A para A+1: 20 * (A+1)^2.
function ProgressionMath.affinityUsesToNext(affinity: number): number
	if affinity < 0 or affinity >= ProgressionMath.MAX_AFFINITY then
		return 0
	end
	return 20 * (affinity + 1) ^ 2
end

return table.freeze(ProgressionMath)
