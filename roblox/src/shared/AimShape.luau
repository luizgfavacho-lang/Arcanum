--!strict
-- Indicador de mira de cada magia (como os indicadores de habilidade de LoL/DotA): que forma
-- desenhar no chao antes de conjurar. Puro (testado em tests/Data.spec.luau); medidas em METROS.
--   Target  circulo no ponto mirado (Radius), que nao passa do alcance (Range)
--   Self    circulo em volta do mago (Radius)
--   Line    faixa a frente do mago (Range de comprimento, Width de largura)
--   Wall    faixa atravessada no ponto mirado (Range de comprimento)
--   nil     sem indicador (projeteis, raios, canalizadas, buffs...)

export type Shape = {
	Kind: "Target" | "Self" | "Line" | "Wall",
	Radius: number,
	Range: number,
	Width: number,
}

local AimShape = {}

local TARGET_ZONES = { Vortex = true, Singularity = true, Rain = true, Hourglass = true }
local TARGET_BARRAGES = { Storm = true, Stars = true, Meteor = true, Verdict = true }
local WALL_RANGE = 20 -- metros (Spells/Zone WALL_CAST_RANGE)

-- `def` = entrada do SpellCatalog (Kind, Mode); `row` = linha de Data/Spells.
function AimShape.of(def: any, row: any): Shape?
	local kind, mode = def.Kind, def.Mode
	local radius, range = row.RadiusMeters or 0, row.RangeMeters or 0
	if kind == "Strike" or (kind == "Zone" and TARGET_ZONES[mode or ""]) then
		return { Kind = "Target", Radius = radius, Range = range, Width = 0 }
	elseif kind == "Barrage" and TARGET_BARRAGES[mode or ""] then
		return { Kind = "Target", Radius = radius, Range = range, Width = 0 }
	elseif kind == "Control" and mode == "Curse" then
		return { Kind = "Target", Radius = radius, Range = range, Width = 0 }
	elseif kind == "Nova" or (kind == "Zone" and mode == "Static") then
		return { Kind = "Self", Radius = radius, Range = 0, Width = 0 }
	elseif kind == "Buff" and mode == "Sacrifice" then
		return { Kind = "Self", Radius = radius, Range = 0, Width = 0 }
	elseif kind == "Line" then
		return { Kind = "Line", Radius = 0, Range = range, Width = radius * 2 }
	elseif kind == "Zone" and mode == "Wall" then
		return { Kind = "Wall", Radius = 0, Range = WALL_RANGE, Width = range }
	end
	return nil
end

return table.freeze(AimShape)
