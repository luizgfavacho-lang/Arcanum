local TestKit = require("./TestKit")
local DamageMath = require("../src/shared/Math/DamageMath")
local Settings = require("../src/shared/Config/CombatSettings")

local test = TestKit.test

local function fireball(extra: { [string]: any }?)
	local input = { BaseDamage = 6, School = "Fire" }
	for k, v in extra or {} do
		input[k] = v
	end
	return DamageMath.computeSpellDamage(input :: any, Settings)
end

test("Dano.BaseEEscala", function(expect)
	expect.near(fireball(), 6, nil, "sem modificadores")
	expect.near(fireball({ SpellPower = 50 }), 9, nil, "Poder Magico 50 = +50%")
	expect.near(fireball({ Affinity = 10 }), 7.8, nil, "afinidade 10 = +30%")
	expect.near(fireball({ Affinity = 99 }), 7.8, nil, "afinidade limitada a 10")
	expect.near(fireball({ DamageMultiplier = 1.2 * 1.15 }), 6 * 1.38, nil, "runas multiplicam")
	expect.near(fireball({ BaseDamage = 0 }), 0, nil, "base 0")
end)

test("Dano.Armadura", function(expect)
	expect.near(fireball({ TargetArmor = 10 }), 3.6, nil, "armadura 10 = -40%")
	expect.near(fireball({ TargetArmor = 30 }), 1.2, nil, "teto de 80%")
	expect.near(DamageMath.armorReduction(-5, Settings), 0, nil, "armadura negativa")
end)

test("Dano.Estados", function(expect)
	expect.near(fireball({ TargetCursed = true }), 7.2, nil, "maldicao +20%")
	expect.near(fireball({ TargetArcaneCharged = true }), 7.5, nil, "carga arcana +25%")
	local spark = DamageMath.computeSpellDamage({ BaseDamage = 5, School = "Electricity", TargetWet = true }, Settings)
	expect.near(spark, 7.5, nil, "eletricidade em molhado x1,5")
	expect.near(fireball({ TargetWet = true }), 6, nil, "molhado nao afeta fogo")
end)

test("Dano.QuedaDaCadeia", function(expect)
	expect.near(DamageMath.chainDamageAtJump(10, 0, 0.15), 10, nil, "salto 0")
	expect.near(DamageMath.chainDamageAtJump(10, 1, 0.15), 8.5, nil, "salto 1")
	expect.near(DamageMath.chainDamageAtJump(10, 3, 0.15), 6.141, 0.01, "salto 3")
	expect.near(DamageMath.chainDamageAtJump(10, 2, 0.10), 8.1, nil, "talento -10%")
end)

test("Mana.Escudo", function(expect)
	local health, mana = DamageMath.resolveManaShield(10, 100, 2)
	expect.near(health, 0, nil, "mana cobre: vida")
	expect.near(mana, 20, nil, "mana cobre: mana")
	health, mana = DamageMath.resolveManaShield(10, 8, 2)
	expect.near(health, 6, nil, "mana insuficiente: vida")
	expect.near(mana, 8, nil, "mana insuficiente: mana")
	local _, efficient = DamageMath.resolveManaShield(8, 100, 1.25)
	expect.near(efficient, 10, nil, "escudo eficiente")
end)

test("Mana.PausaDaRegen", function(expect)
	expect.equal(DamageMath.canRegenerateMana(10, 8, 3), false, "pausada 2 s apos combate")
	expect.equal(DamageMath.canRegenerateMana(11, 8, 3), true, "volta apos 3 s")
end)

test("Chance.PorSegundo", function(expect)
	expect.near(DamageMath.chanceForExposure(0.15, 1), 0.15, nil, "1 s = chance cheia")
	-- 10 ticks de 0,1 s devem somar a mesma chance de 1 s.
	local miss = (1 - DamageMath.chanceForExposure(0.15, 0.1)) ^ 10
	expect.near(1 - miss, 0.15, 1e-6, "10 x 0,1 s")
end)
