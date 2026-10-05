--!strict
-- Paleta por escola (Docs/03-Renderizacao.md §7) e forma para o modo daltonico.

export type Palette = { Core: Color3, Halo: Color3, Accent: Color3, Shape: string }

local function hex(h: string): Color3
	return Color3.fromHex(h)
end

return table.freeze({
	Electricity = table.freeze({
		Core = hex("#FFFFFF"),
		Halo = hex("#3FA9FF"),
		Accent = hex("#FFE14D"),
		Shape = "zigue-zague",
	}),
	Fire = table.freeze({ Core = hex("#FFF4D6"), Halo = hex("#FF8A1F"), Accent = hex("#FFB000"), Shape = "gota" }),
	Energy = table.freeze({ Core = hex("#FFFFFF"), Halo = hex("#9B5CFF"), Accent = hex("#D9B8FF"), Shape = "losango" }),
	Necromancy = table.freeze({
		Core = hex("#EFFFF2"),
		Halo = hex("#3DFF8A"),
		Accent = hex("#1D7A4C"),
		Shape = "cranio",
	}),
	Blood = table.freeze({ Core = hex("#FFE6E6"), Halo = hex("#C8102E"), Accent = hex("#5A0010"), Shape = "lua" }),
}) :: { [string]: Palette }
