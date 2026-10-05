--!strict
-- Modificadores de UMA conjuracao (runas, talentos, passiva, artefatos), equivalente ao
-- IArcanumSpellModifierSource da Unreal. Hoje neutro; T-04 (passiva) e M5 (runas/talentos)
-- registram fontes aqui. Multiplicadores combinam por produto; extras por soma.

export type Modifiers = {
	DamageMultiplier: number,
	CostMultiplier: number,
	CooldownMultiplier: number,
	ExtraTargets: number,
	ExtraCount: number,
}

export type Source = (player: Player, spellId: string, school: string, mods: Modifiers) -> ()

local Modifiers = {}

local sources: { Source } = {}

function Modifiers.addSource(source: Source)
	table.insert(sources, source)
end

function Modifiers.gather(player: Player?, spellId: string, school: string): Modifiers
	local mods: Modifiers = {
		DamageMultiplier = 1,
		CostMultiplier = 1,
		CooldownMultiplier = 1,
		ExtraTargets = 0,
		ExtraCount = 0,
	}
	if player then
		for _, source in sources do
			source(player, spellId, school, mods)
		end
	end
	return mods
end

return Modifiers
