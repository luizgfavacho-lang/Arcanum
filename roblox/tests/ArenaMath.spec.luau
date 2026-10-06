local TestKit = require("./TestKit")
local ArenaMath = require("../src/shared/Math/ArenaMath")
local Enemies = require("../src/shared/Data/Enemies")

local test = TestKit.test

test("Arena.CadaRoundMaisDificil", function(expect)
	for round = 1, 20 do
		expect.truthy(ArenaMath.enemyCount(round + 1, 1) > ArenaMath.enemyCount(round, 1), "mais criaturas " .. round)
		expect.truthy(ArenaMath.healthScale(round + 1) > ArenaMath.healthScale(round), "mais vida " .. round)
		expect.truthy(ArenaMath.spellPower(round + 1) > ArenaMath.spellPower(round), "mais dano " .. round)
		expect.truthy(ArenaMath.spawnInterval(round + 1) <= ArenaMath.spawnInterval(round), "mais rapido " .. round)
		expect.truthy(ArenaMath.maxAlive(round + 1, 1) >= ArenaMath.maxAlive(round, 1), "mais ao mesmo tempo")
	end
	expect.equal(ArenaMath.enemyCount(1, 1), 5, "round 1 sozinho")
	expect.near(ArenaMath.healthScale(1), 1, nil, "round 1 sem bonus")
	expect.near(ArenaMath.spellPower(1), 0, nil, "round 1 sem poder extra")
end)

test("Arena.GrupoMaiorMaisCriaturas", function(expect)
	expect.truthy(ArenaMath.enemyCount(3, 2) > ArenaMath.enemyCount(3, 1), "dupla")
	expect.truthy(ArenaMath.enemyCount(3, 4) > ArenaMath.enemyCount(3, 2), "quarteto")
	expect.truthy(ArenaMath.maxAlive(30, 6) <= ArenaMath.Config.MaxAliveCap, "teto de vivas")
end)

test("Arena.Limites", function(expect)
	expect.near(ArenaMath.spawnInterval(100), 0.6, nil, "intervalo minimo")
	expect.near(ArenaMath.eliteChance(100), 0.35, nil, "elite no maximo 35%")
end)

test("Arena.Chefes", function(expect)
	expect.equal(ArenaMath.bossCount(4), 0, "round 4 sem chefe")
	expect.equal(ArenaMath.bossCount(5), 1, "round 5: um chefe")
	expect.equal(ArenaMath.bossCount(10), 2, "round 10: dois")
	expect.equal(ArenaMath.bossCount(25), 3, "no maximo tres")
	expect.equal(ArenaMath.isBossRound(0), false, "round 0 nao existe")
	expect.truthy(ArenaMath.roundXP(5) > ArenaMath.roundXP(4) + 15, "bonus de XP no chefe")
end)

test("Arena.ElencoExisteESorteio", function(expect)
	for round = 1, 12 do
		for name in ArenaMath.roster(round) do
			expect.truthy(Enemies[name], "criatura sem linha em Enemies.csv: " .. name)
		end
	end
	expect.equal(ArenaMath.roster(1).StormBloater, nil, "bulbo so do round 2")
	local weights = { A = 1, B = 3 }
	expect.equal(ArenaMath.pick(weights, 0), "A", "inicio")
	expect.equal(ArenaMath.pick(weights, 0.3), "B", "depois do peso de A")
	expect.equal(ArenaMath.pick(weights, 1), "B", "fim")
	expect.equal(ArenaMath.pick({}, 0.5), nil, "vazio")
end)
