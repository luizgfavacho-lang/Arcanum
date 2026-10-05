--!strict
-- Regras de dano PURAS (sem servicos do Roblox), testadas em tests/DamageMath.spec.luau.
-- Porte direto de Source/ArcanumCore/Private/Math/ArcanumDamageMath.cpp.

export type Tuning = {
	ArmorReductionPerPoint: number,
	MaxArmorReduction: number,
	SpellPowerBonusPerPoint: number,
	AffinityBonusPerLevel: number,
	CursedDamageTakenBonus: number,
	ArcaneChargeBonus: number,
	WetElectricityMultiplier: number,
}

export type Inputs = {
	BaseDamage: number,
	DamageMultiplier: number?, -- runas/talentos/passivas (1 = neutro)
	SpellPower: number?,
	Affinity: number?, -- 0..10
	TargetArmor: number?,
	School: string?, -- "Electricity", "Fire", ...
	TargetCursed: boolean?,
	TargetArcaneCharged: boolean?,
	TargetWet: boolean?,
}

local DamageMath = {}

function DamageMath.armorReduction(armor: number, tuning: Tuning): number
	return math.clamp(armor * tuning.ArmorReductionPerPoint, 0, tuning.MaxArmorReduction)
end

-- Base * Mult * (1 + PM*k) * (1 + Afinidade*k) * [Maldicao] * [Carga] * [Combo] * (1 - Armadura)
function DamageMath.computeSpellDamage(input: Inputs, tuning: Tuning): number
	if input.BaseDamage <= 0 then
		return 0
	end

	local damage = input.BaseDamage * math.max(input.DamageMultiplier or 1, 0)
	damage *= 1 + math.max(input.SpellPower or 0, 0) * tuning.SpellPowerBonusPerPoint
	damage *= 1 + math.clamp(input.Affinity or 0, 0, 10) * tuning.AffinityBonusPerLevel

	if input.TargetCursed then
		damage *= 1 + tuning.CursedDamageTakenBonus
	end
	if input.TargetArcaneCharged then
		damage *= 1 + tuning.ArcaneChargeBonus
	end
	if input.TargetWet and input.School == "Electricity" then
		damage *= tuning.WetElectricityMultiplier
	end

	damage *= 1 - DamageMath.armorReduction(input.TargetArmor or 0, tuning)
	return math.max(damage, 0)
end

-- Dano no salto N (0 = primeiro alvo). Queda composta: Base * (1 - f)^N.
function DamageMath.chainDamageAtJump(baseDamage: number, jumpIndex: number, falloffPerJump: number): number
	local keep = math.clamp(1 - falloffPerJump, 0, 1)
	return baseDamage * keep ^ math.max(jumpIndex, 0)
end

-- Escudo de Mana: cada ponto de dano custa manaPerDamage; o resto vai para a vida.
function DamageMath.resolveManaShield(damage: number, currentMana: number, manaPerDamage: number): (number, number)
	if damage <= 0 then
		return 0, 0
	end
	if manaPerDamage <= 0 then
		return damage, 0
	end
	local absorbed = math.min(damage, math.max(currentMana, 0) / manaPerDamage)
	return damage - absorbed, absorbed * manaPerDamage -- (dano na vida, mana gasta)
end

function DamageMath.canRegenerateMana(now: number, lastCombatTime: number, delay: number): boolean
	return now - lastCombatTime >= delay
end

-- Chance por segundo -> chance neste tick (canalizadas e auras).
function DamageMath.chanceForExposure(chancePerSecond: number, seconds: number): number
	return 1 - (1 - math.clamp(chancePerSecond, 0, 1)) ^ seconds
end

return table.freeze(DamageMath)
