local TestKit = require("./TestKit")
local CombatMath = require("../src/shared/Math/CombatMath")
local Settings = require("../src/shared/Config/CombatSettings")

local test = TestKit.test

test("Equilibrio.QuebraNoMaximo", function(expect)
	local p = CombatMath.newPoise(10)
	expect.equal(CombatMath.hitPoise(p, 4, 0, Settings), false, "4 de 10")
	expect.equal(CombatMath.hitPoise(p, 4, 0.2, Settings), false, "8 de 10")
	expect.equal(CombatMath.hitPoise(p, 4, 0.4, Settings), true, "12 de 10 atordoa")
	expect.near(p.Value, 0, nil, "zera ao atordoar")
end)

test("Equilibrio.ImunidadeDepoisDeAtordoar", function(expect)
	local p = CombatMath.newPoise(5)
	expect.equal(CombatMath.hitPoise(p, 6, 0, Settings), true, "atordoa")
	expect.equal(CombatMath.hitPoise(p, 50, 1, Settings), false, "imune logo depois")
	expect.near(p.Value, 0, nil, "golpe durante a imunidade nao acumula")
	expect.equal(CombatMath.hitPoise(p, 6, Settings.StaggerImmunity + 0.1, Settings), true, "volta a atordoar")
end)

test("Equilibrio.Recupera", function(expect)
	local p = CombatMath.newPoise(10)
	CombatMath.hitPoise(p, 6, 0, Settings)
	expect.near(CombatMath.poiseValue(p, Settings.PoiseRecoverDelay, Settings), 6, nil, "nao recupera antes do atraso")
	local later = Settings.PoiseRecoverDelay + 0.5
	expect.near(
		CombatMath.poiseValue(p, later, Settings),
		6 - 0.5 * Settings.PoiseRecoverPerSecond * 10,
		nil,
		"meio segundo"
	)
	expect.near(CombatMath.poiseValue(p, 100, Settings), 0, nil, "nunca negativo")
end)

test("Equilibrio.ChefeNaoAtordoa", function(expect)
	local p = CombatMath.newPoise(math.huge)
	expect.equal(CombatMath.hitPoise(p, 1e6, 0, Settings), false, "maximo infinito")
end)

test("Esquiva.JanelaERecarga", function(expect)
	local w = Settings.DodgeInvulnerability
	expect.truthy(CombatMath.isInvulnerable(10, 10, w), "no inicio")
	expect.truthy(CombatMath.isInvulnerable(10 + w, 10, w), "no fim da janela")
	expect.truthy(not CombatMath.isInvulnerable(10 + w + 0.01, 10, w), "depois da janela")
	expect.truthy(not CombatMath.isInvulnerable(9.9, 10, w), "antes de comecar")
	expect.truthy(not CombatMath.dodgeReady(10.5, 10, Settings.DodgeCooldown), "em recarga")
	expect.truthy(CombatMath.dodgeReady(10 + Settings.DodgeCooldown, 10, Settings.DodgeCooldown), "pronta")
end)

test("Empurrao.Proporcional", function(expect)
	local t = Settings
	expect.near(CombatMath.knockbackSpeed(1, 20, 1, t), 0, nil, "golpe pequeno nao empurra")
	expect.near(CombatMath.knockbackSpeed(20 / 3, 20, 1, t), t.KnockbackSpeed, 1e-3, "1/3 da vida, peso 1")
	expect.near(CombatMath.knockbackSpeed(20 / 3, 20, 2, t), t.KnockbackSpeed / 2, 1e-3, "peso 2 = metade")
	expect.near(CombatMath.knockbackSpeed(100, 20, 1, t), t.KnockbackSpeed * 1.5, 1e-3, "limite 1,5x")
	expect.near(CombatMath.knockbackSpeed(100, 20, 0, t), 0, nil, "peso 0 = imovel")
end)
