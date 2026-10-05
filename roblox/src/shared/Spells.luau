--!strict
-- Ponto unico de consulta de magia: junta catalogo (comportamento), Data.Spells (numeros) e textos.

local Shared = script.Parent
local SpellCatalog = require(Shared.SpellCatalog)
local SpellData = require(Shared.Data.Spells) :: any
local SpellText = require(Shared.Data.SpellText) :: any

export type Spell = {
	Id: string,
	Def: SpellCatalog.Def,
	Row: any, -- linha de Data/Spells.csv (ManaCost, Damage, RangeMeters, ...)
	Name: string,
	Desc: string,
}

local cache: { [string]: Spell } = {}

local Spells = {}

function Spells.get(spellId: string): Spell?
	local cached = cache[spellId]
	if cached then
		return cached
	end
	local def = SpellCatalog.Defs[spellId]
	local row = SpellData[spellId]
	if not def or not row then
		return nil
	end
	local text = SpellText[spellId] or {}
	local spell: Spell = { Id = spellId, Def = def, Row = row, Name = text.Name or spellId, Desc = text.Desc or "" }
	cache[spellId] = spell
	return spell
end

return Spells
