--!strict
-- Comportamento de cada magia implementada (equivale ao DA_Spell_<Id> da Unreal).
-- Os NUMEROS ficam em Data/Spells.luau (gerado do CSV). Aqui so: tipo, estado aplicado e visual.
-- Modulo puro (sem servicos do Roblox) para rodar nos testes.

export type Kind = "Projectile" | "Hitscan" | "ChainLightning"

export type Def = {
	Kind: Kind,
	ProcState: string?, -- estado aplicado com ProcChance (ver Data/Spells)
	Homing: boolean?, -- projeteis teleguiados
	SpreadDegrees: number?, -- leque quando Count > 1
	Visual: string?, -- "Bolt", "LifeStream", "Orb"...
}

local Catalog: { [string]: Def } = {
	Spark = { Kind = "Hitscan", ProcState = "Paralyzed", Visual = "Bolt" },
	Fireball = { Kind = "Projectile", ProcState = "Burning", Visual = "Orb" },
	ArcaneMissile = {
		Kind = "Projectile",
		ProcState = "ArcaneCharge",
		Homing = true,
		SpreadDegrees = 25,
		Visual = "Orb",
	},
	ChainLightning = { Kind = "ChainLightning", ProcState = "Paralyzed" },
	LifeDrain = { Kind = "Hitscan", Visual = "LifeStream" },
}

-- Barra inicial do jogador (fatia vertical). Lamina de Sangue entra no M1 (T-06).
local StartingSlots = { "Spark", "Fireball", "ArcaneMissile", "ChainLightning", "LifeDrain" }

return table.freeze({
	Defs = table.freeze(Catalog),
	StartingSlots = table.freeze(StartingSlots),
	NumSlots = 5,
	isChanneled = function(spellId: string): boolean
		local def = Catalog[spellId]
		return def ~= nil and def.Kind == "ChainLightning"
	end,
})
