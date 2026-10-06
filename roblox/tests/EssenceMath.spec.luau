local TestKit = require("./TestKit")
local EssenceMath = require("../src/shared/Math/EssenceMath")
local SpellCatalog = require("../src/shared/SpellCatalog")
local SpellData = require("../src/shared/Data/Spells")

local test = TestKit.test

test("Essencia.Drop", function(expect)
	expect.equal(EssenceMath.dropValue(6, false), 6, "gosma")
	expect.equal(EssenceMath.dropValue(12, true), 24, "elite em dobro")
	expect.equal(EssenceMath.dropValue(10, false, 1.5), 15, "arena")
	expect.equal(EssenceMath.dropValue(0, false), 1, "sempre pelo menos 1")
	expect.equal(EssenceMath.pieces(1), 3, "minimo de pecas")
	expect.equal(EssenceMath.pieces(400), 40, "maximo de pecas")
end)

test("Essencia.PrecosECompra", function(expect)
	for tier = 1, 3 do
		expect.truthy(EssenceMath.price(tier + 1) > EssenceMath.price(tier), "circulo mais alto custa mais")
	end
	expect.equal(EssenceMath.price(9), EssenceMath.price(4), "circulo fora da faixa")
	expect.equal(EssenceMath.canBuy(100, 1, false), true, "tem o bastante")
	expect.equal(EssenceMath.canBuy(99, 1, false), false, "falta 1")
	expect.equal(EssenceMath.canBuy(5000, 1, true), false, "ja tem")
end)

test("Essencia.Arena", function(expect)
	expect.near(EssenceMath.arenaScale(1), 1, nil, "round 1")
	expect.truthy(EssenceMath.arenaScale(5) > EssenceMath.arenaScale(4), "cresce")
	expect.equal(EssenceMath.arenaRoundBonus(3), 75, "bonus do round 3")
end)

test("Essencia.ListaDeMagias", function(expect)
	local text = EssenceMath.encode({ Spark = true, Fireball = true, Meteor = false })
	expect.equal(text, "Fireball,Spark", "ordenado e sem as falsas")
	local back = EssenceMath.decode(text)
	expect.equal(back.Spark, true, "volta Spark")
	expect.equal(back.Meteor, nil, "sem Meteoro")
	expect.equal(next(EssenceMath.decode(nil)), nil, "vazio")
end)

test("Essencia.InicioUmaBasicaPorEscola", function(expect)
	local schools = {}
	for _, id in SpellCatalog.StartingSlots do
		local row = SpellData[id]
		expect.equal(row.Tier, 1, id .. " deve ser do Circulo I")
		expect.equal(schools[row.School], nil, "uma por escola: " .. row.School)
		schools[row.School] = true
	end
	local count = 0
	for _ in schools do
		count += 1
	end
	expect.equal(count, 5, "as 5 escolas")
end)
