local TestKit = require("./TestKit")
local ComboMath = require("../src/shared/Math/ComboMath")
local States = require("../src/shared/States")

local test = TestKit.test

local function with(...: string): (string) -> boolean
	local set = {}
	for _, s in { ... } do
		set[s] = true
	end
	return function(state)
		return set[state] == true
	end
end

test("Combo.FogoNoEncharcadoVaporiza", function(expect)
	local r = ComboMath.find("Fire", with(States.Wet))
	expect.equal(r and r.Id, "Vaporize", "fogo + agua")
	expect.equal(r and r.Consumes, true, "consome a agua")
	expect.near(r and r.Multiplier or 0, 1.5, nil, "x1,5")
end)

test("Combo.Sobrecarga", function(expect)
	local a = ComboMath.find("Fire", with(States.Paralyzed))
	local b = ComboMath.find("Electricity", with(States.Burning))
	expect.equal(a and a.Id, "Overload", "fogo no paralisado")
	expect.equal(b and b.Id, "Overload", "raio no queimando")
	expect.equal(b and b.Consumes, true, "o raio apaga o fogo")
	expect.near(ComboMath.splashDamage(a :: any, 10), 6, nil, "respingo 60%")
end)

test("Combo.PrioridadeVaporizarAntesDeSobrecarga", function(expect)
	local r = ComboMath.find("Fire", with(States.Wet, States.Paralyzed))
	expect.equal(r and r.Id, "Vaporize", "primeiro da lista vence")
end)

test("Combo.ConducaoSoAtingeEncharcados", function(expect)
	local r = ComboMath.find("Electricity", with(States.Wet))
	expect.equal(r and r.Id, "Conduct", "raio na agua")
	expect.equal(r and r.SplashOnlyState, true, "so encharcados")
	expect.near(r and r.Multiplier or 0, 1, nil, "o x1,5 ja e do DamageMath (sem dobrar)")
end)

test("Combo.ColheitaECuraEContagio", function(expect)
	local h = ComboMath.find("Necromancy", with(States.Bleeding))
	expect.equal(h and h.Id, "Harvest", "necro no sangrando")
	expect.near(ComboMath.healAmount(h :: any, 10), 3, nil, "cura 30%")
	local c = ComboMath.find("Blood", with(States.Poisoned))
	expect.equal(c and c.Id, "Contagion", "sangue no envenenado")
	expect.equal(ComboMath.find("Energy", with(States.Paralyzed)) and "ok", "ok", "ruptura")
end)

test("Combo.SemEstadoOuEscolaNaoReage", function(expect)
	expect.equal(ComboMath.find("Fire", with()), nil, "alvo limpo")
	expect.equal(ComboMath.find(nil, with(States.Wet)), nil, "sem escola")
	expect.equal(ComboMath.find("Necromancy", with(States.Wet)), nil, "par sem reacao")
end)

test("Combo.Recarga", function(expect)
	expect.equal(ComboMath.ready(nil, 5), true, "nunca reagiu")
	expect.equal(ComboMath.ready(5, 5 + ComboMath.Cooldown * 0.5), false, "cedo demais")
	expect.equal(ComboMath.ready(5, 5 + ComboMath.Cooldown + 0.01), true, "passou a recarga")
end)

test("Combo.EstadosExistem", function(expect)
	for _, r in ComboMath.Reactions do
		expect.equal((States :: any)[r.State], r.State, r.Id .. " usa estado valido")
	end
end)
