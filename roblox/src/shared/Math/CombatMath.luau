--!strict
-- Regras puras de combate fora da conta de dano: equilibrio (poise -> atordoamento), esquiva
-- (janela de invulnerabilidade) e empurrao. Sem servicos do Roblox: testado em tests/CombatMath.spec.

export type Poise = {
	Value: number, -- dano acumulado no equilibrio
	Max: number, -- passou disso: atordoa (math.huge = nunca)
	LastHit: number,
	ImmuneUntil: number, -- depois de atordoado, alguns segundos sem poder ser atordoado de novo
}

export type Tuning = {
	PoiseRecoverDelay: number, -- segundos sem apanhar ate comecar a recuperar
	PoiseRecoverPerSecond: number, -- fracao do maximo recuperada por segundo
	StaggerImmunity: number,
	KnockbackSpeed: number, -- studs/s de um golpe que tira 1/3 da vida de um alvo de peso 1
	KnockbackMinFraction: number, -- golpes menores que isso (fracao da vida) nao empurram
}

local CombatMath = {}

function CombatMath.newPoise(max: number): Poise
	return { Value = 0, Max = max, LastHit = -math.huge, ImmuneUntil = -math.huge }
end

-- Equilibrio acumulado agora (ja descontada a recuperacao).
function CombatMath.poiseValue(p: Poise, now: number, t: Tuning): number
	local idle = now - p.LastHit - t.PoiseRecoverDelay
	if idle <= 0 then
		return p.Value
	end
	return math.max(p.Value - idle * t.PoiseRecoverPerSecond * p.Max, 0)
end

-- Registra um golpe. Retorna true se quebrou o equilibrio (atordoa e zera).
function CombatMath.hitPoise(p: Poise, amount: number, now: number, t: Tuning): boolean
	p.Value = CombatMath.poiseValue(p, now, t)
	p.LastHit = now
	if now < p.ImmuneUntil or amount <= 0 then
		return false
	end
	p.Value += amount
	if p.Value >= p.Max then
		p.Value = 0
		p.ImmuneUntil = now + t.StaggerImmunity
		return true
	end
	return false
end

function CombatMath.dodgeReady(now: number, lastDodge: number, cooldown: number): boolean
	return now - lastDodge >= cooldown
end

function CombatMath.isInvulnerable(now: number, dodgeStart: number, window: number): boolean
	return now >= dodgeStart and now - dodgeStart <= window
end

-- Velocidade do empurrao (studs/s). Peso 0 ou golpe pequeno = sem empurrao.
function CombatMath.knockbackSpeed(damage: number, maxHealth: number, weight: number, t: Tuning): number
	if weight <= 0 or maxHealth <= 0 then
		return 0
	end
	local fraction = damage / maxHealth
	if fraction < t.KnockbackMinFraction then
		return 0
	end
	return t.KnockbackSpeed * math.min(fraction * 3, 1.5) / weight
end

return CombatMath
