-- Consistencia entre catalogo (comportamento), dados gerados do CSV e textos.
local TestKit = require("./TestKit")
local SpellCatalog = require("../src/shared/SpellCatalog")
local SpellData = require("../src/shared/Data/Spells")
local SpellText = require("../src/shared/Data/SpellText")
local Levels = require("../src/shared/Data/Levels")
local Enemies = require("../src/shared/Data/Enemies")
local States = require("../src/shared/States")
local ProgressionMath = require("../src/shared/Math/ProgressionMath")

local test = TestKit.test

test("Dados.CatalogoTemLinhaETexto", function(expect)
	for spellId, def in SpellCatalog.Defs do
		expect.truthy(SpellData[spellId], spellId .. " sem linha em Spells.csv")
		expect.truthy(SpellText[spellId] and SpellText[spellId].Name, spellId .. " sem nome em ST_Spells.csv")
		if def.ProcState then
			expect.truthy(States[def.ProcState], spellId .. ": ProcState desconhecido " .. def.ProcState)
		end
	end
end)

test("Dados.SlotsIniciais", function(expect)
	expect.equal(#SpellCatalog.StartingSlots, SpellCatalog.NumSlots, "5 slots")
	for _, spellId in SpellCatalog.StartingSlots do
		expect.truthy(SpellCatalog.Defs[spellId], spellId .. " fora do catalogo")
	end
end)

test("Dados.CanalizadasBatemComCSV", function(expect)
	for spellId in SpellCatalog.Defs do
		expect.equal(SpellCatalog.isChanneled(spellId), SpellData[spellId].bChanneled, spellId)
	end
end)

test("Dados.CurvaDeNiveis", function(expect)
	for level = 1, 50 do
		expect.equal(Levels[level].XPToNext, ProgressionMath.xpToNextLevel(level), "nivel " .. level)
	end
end)

test("Dados.InimigosDoSandbox", function(expect)
	for _, rowName in { "SkeletonMage", "ArcaneSlime", "StormBloater", "CrystalGolem" } do
		expect.truthy(Enemies[rowName] and Enemies[rowName].MaxHealth > 0, rowName)
	end
end)

-- Todo tipo do catalogo precisa de executor no servidor (SpellService: CASTERS / CHANNELS).
local KNOWN_KINDS = {
	Projectile = true,
	Hitscan = true,
	ChainLightning = true,
	Strike = true,
	Nova = true,
	Line = true,
	Zone = true,
	Barrage = true,
	Buff = true,
	Blink = true,
	Portal = true,
	Control = true,
	Beam = true,
	Flamethrower = true,
	Lance = true,
	Slash = true,
	Summon = true,
}

test("Dados.Grimorio42Jogaveis", function(expect)
	local count = 0
	for spellId, def in SpellCatalog.Defs do
		count += 1
		expect.truthy(KNOWN_KINDS[def.Kind], spellId .. ": tipo sem executor " .. tostring(def.Kind))
		if def.Summon then
			expect.truthy(Enemies[def.Summon], spellId .. ": servo sem linha em Enemies.csv")
		end
	end
	expect.equal(count, 42, "as 42 magias do CSV estao no catalogo")
	expect.truthy(Enemies.SkeletonServant and Enemies.BruteServant, "servos do Exercito dos Mortos")
end)

test("Dados.IndicadorDeMira", function(expect)
	local AimShape = require("../src/shared/AimShape")
	local counts = {}
	for spellId, def in SpellCatalog.Defs do
		local shape = AimShape.of(def, SpellData[spellId])
		if shape then
			counts[shape.Kind] = (counts[shape.Kind] or 0) + 1
			if shape.Kind == "Target" or shape.Kind == "Self" then
				expect.truthy(shape.Radius > 0, spellId .. ": indicador sem raio")
			else
				expect.truthy(shape.Range > 0 and shape.Width > 0, spellId .. ": faixa sem medidas")
			end
		end
	end
	expect.truthy((counts.Target or 0) >= 8, "magias de area mirada")
	expect.truthy((counts.Self or 0) >= 3, "magias em volta do mago")
	expect.equal(counts.Line, 1, "Espinhos Carmesins")
	expect.equal(counts.Wall, 1, "Muralha de Chamas")
end)
