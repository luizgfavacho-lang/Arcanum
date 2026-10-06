--!strict
-- Essencias: a moeda do jogo (como os bolts de Ratchet & Clank). Regras PURAS, testadas em
-- tests/EssenceMath.spec.luau. Toda criatura derrotada derrama essencias amarelas no chao; passar
-- perto puxa todas para voce. Com elas se compram magias novas no Grimorio.

local EssenceMath = {}

EssenceMath.Config = table.freeze({
	PerXP = 1, -- essencias por ponto de XPReward da criatura (Data/Enemies.csv)
	EliteMultiplier = 2,
	MagnetStuds = 16, -- distancia em que as essencias voam ate o jogador
	ReadyDelay = 0.6, -- segundos espalhando no chao antes de poderem ser puxadas
	LifetimeSeconds = 90, -- somem se ninguem pegar
	ArenaRoundBonus = 25, -- essencias por round vencido (x round)
})

-- Preco de cada magia pelo circulo (Tier 1..4).
EssenceMath.Prices = table.freeze({ 100, 300, 900, 2000 })

-- Essencias derramadas por uma criatura (`scale` = bonus da Arena por round).
function EssenceMath.dropValue(xpReward: number, elite: boolean, scale: number?): number
	local value = math.max(xpReward, 0) * EssenceMath.Config.PerXP
	if elite then
		value *= EssenceMath.Config.EliteMultiplier
	end
	value *= math.max(scale or 1, 0)
	return math.max(math.floor(value + 0.5), 1)
end

-- Quantas pecas o cliente desenha (o valor e dividido entre elas): de 3 a 40.
function EssenceMath.pieces(value: number): number
	return math.clamp(math.ceil(math.max(value, 0) / 3), 3, 40)
end

function EssenceMath.price(tier: number): number
	return EssenceMath.Prices[math.clamp(math.floor(tier), 1, #EssenceMath.Prices)]
end

-- Pode comprar? (nao tem a magia e tem essencias suficientes)
function EssenceMath.canBuy(essence: number, tier: number, alreadyOwned: boolean): boolean
	return not alreadyOwned and essence >= EssenceMath.price(tier)
end

-- Arena: essencias das criaturas crescem 10% por round; bonus ao vencer o round.
function EssenceMath.arenaScale(round: number): number
	return 1 + 0.1 * (math.max(round, 1) - 1)
end

function EssenceMath.arenaRoundBonus(round: number): number
	return EssenceMath.Config.ArenaRoundBonus * math.max(round, 1)
end

-- Lista de magias liberadas <-> texto (atributo "Unlocked" do Player, separado por virgula).
function EssenceMath.encode(ids: { [string]: boolean }): string
	local list = {}
	for id, owned in ids do
		if owned then
			table.insert(list, id)
		end
	end
	table.sort(list)
	return table.concat(list, ",")
end

function EssenceMath.decode(text: string?): { [string]: boolean }
	local ids: { [string]: boolean } = {}
	if text then
		for id in string.gmatch(text, "[^,]+") do
			ids[id] = true
		end
	end
	return ids
end

return table.freeze(EssenceMath)
