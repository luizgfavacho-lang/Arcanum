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
