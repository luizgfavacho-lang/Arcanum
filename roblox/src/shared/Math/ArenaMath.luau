--!strict
-- Regras PURAS da Arena (testadas em tests/ArenaMath.spec.luau). Inspirada nas arenas de
-- Ratchet & Clank: Going Commando: rounds seguidos, cada um mais dificil (mais criaturas, mais
-- fortes, mais elites, mais ao mesmo tempo, chegando mais rapido) e chefes a cada BossEvery rounds.
-- `players` = quantos jogadores estao lutando na arena (a dificuldade cresce com o grupo).

local ArenaMath = {}

ArenaMath.Config = table.freeze({
	BossEvery = 5, -- round de chefe
	CountdownSeconds = 5, -- antes do round 1
	IntermissionSeconds = 8, -- entre rounds (coletaveis renascem)
	DefeatSeconds = 5, -- tela de derrota antes de reabrir
	PickupRespawnSeconds = 18,
	HealthPickupFraction = 0.35, -- da vida maxima
	ManaPickupFraction = 0.4, -- da mana maxima
	MaxAliveCap = 16,
})

-- Quantas criaturas o round manda (sem contar filhotes de divisao nem chefes).
function ArenaMath.enemyCount(round: number, players: number): number
	local base = 3 + 2 * math.max(round, 1)
	local group = 1 + 0.5 * math.max(players - 1, 0)
	return math.floor(base * group)
end

-- Quantas podem estar vivas ao mesmo tempo (o resto espera nos portoes).
function ArenaMath.maxAlive(round: number, players: number): number
	return math.min(4 + math.max(round, 1) + 2 * math.max(players - 1, 0), ArenaMath.Config.MaxAliveCap)
end

-- Segundos entre duas criaturas saindo dos portoes.
function ArenaMath.spawnInterval(round: number): number
	return math.max(2 - 0.12 * (math.max(round, 1) - 1), 0.6)
end

-- Vida das criaturas (multiplicador) e poder magico extra (mais dano) por round.
function ArenaMath.healthScale(round: number): number
	return 1 + 0.15 * (math.max(round, 1) - 1)
end

function ArenaMath.spellPower(round: number): number
	return 5 * (math.max(round, 1) - 1)
end

function ArenaMath.eliteChance(round: number): number
	return math.min(0.04 * math.max(round, 1), 0.35)
end

function ArenaMath.isBossRound(round: number): boolean
	return round > 0 and round % ArenaMath.Config.BossEvery == 0
end

-- Chefes do round: 1 no 5, 2 no 10, 3 do 15 em diante.
function ArenaMath.bossCount(round: number): number
	if not ArenaMath.isBossRound(round) then
		return 0
	end
	return math.min(math.floor(round / ArenaMath.Config.BossEvery), 3)
end

-- Pesos de cada criatura no round (as mais perigosas entram aos poucos).
function ArenaMath.roster(round: number): { [string]: number }
	local roster: { [string]: number } = { ArcaneSlime = 3, SkeletonMage = 1 }
	if round >= 2 then
		roster.StormBloater = 1
	end
	if round >= 3 then
		roster.SkeletonMage = 2
	end
	if round >= 6 then
		roster.StormBloater = 2
		roster.SkeletonMage = 3
	end
	return roster
end

-- Sorteio por peso: `roll` em [0, 1). Ordem alfabetica para ser deterministico.
function ArenaMath.pick(weights: { [string]: number }, roll: number): string?
	local names = {}
	local total = 0
	for name, weight in weights do
		if weight > 0 then
			table.insert(names, name)
			total += weight
		end
	end
	if total <= 0 then
		return nil
	end
	table.sort(names)
	local target = math.clamp(roll, 0, 0.999999) * total
	local acc = 0
	for _, name in names do
		acc += weights[name]
		if target < acc then
			return name
		end
	end
	return names[#names]
end

-- XP de cada jogador ao vencer o round.
function ArenaMath.roundXP(round: number): number
	return 15 * math.max(round, 1) + (if ArenaMath.isBossRound(round) then 50 else 0)
end

return table.freeze(ArenaMath)
