--!strict
-- Comportamento de cada criatura (IA). O DANO vem de Data/Enemies.csv (coluna AttackDamage, vezes
-- DamageScale); aqui ficam alcances, recargas e telegrafias. Distancias em METROS.
--
-- Estilos:
--   Ranged   mantem distancia (KeepMin..KeepMax), ataca a distancia, pode teleportar se encurralado
--   Melee    persegue e ataca por contato (pode pular, pode se dividir ao morrer)
--   Kamikaze persegue, incha (telegrafia) e explode, morrendo junto
--   Boss     persegue devagar e alterna ataques
-- Ataques:
--   Projectile usa o visual/comportamento de uma magia (SpellId) com numeros proprios
--   Slam       area no chao em volta dele (aviso no chao durante Telegraph)
--   Explode    area em volta dele, depois morre
--   Touch      contato corpo a corpo

export type Attack = {
	Kind: string, -- "Projectile" | "Slam" | "Explode" | "Touch"
	SpellId: string?,
	Cooldown: number,
	RangeMeters: number,
	Telegraph: number, -- segundos de aviso antes do golpe
	RadiusMeters: number?,
	DamageScale: number?,
	Count: number?, -- projeteis
	SpeedMetersPerSecond: number?, -- projeteis (mais lentos que os do jogador: desviaveis)
	ProcChance: number?,
}

export type Behavior = {
	Style: string,
	AggroMeters: number, -- comeca a lutar
	LeashMeters: number, -- longe demais de casa: volta e se cura
	KeepMin: number?,
	KeepMax: number?,
	BlinkWhenCloserThan: number?, -- metros; teleporta para longe
	BlinkCooldown: number?,
	Hop: boolean?,
	SplitInto: string?,
	SplitCount: number?,
	Attacks: { Attack },
}

local Catalog: { [string]: Behavior } = {
	SkeletonMage = {
		Style = "Ranged",
		AggroMeters = 28,
		LeashMeters = 45,
		KeepMin = 8,
		KeepMax = 15,
		BlinkWhenCloserThan = 3.5,
		BlinkCooldown = 8,
		Attacks = {
			{
				Kind = "Projectile",
				SpellId = "Fireball",
				Cooldown = 2.8,
				RangeMeters = 22,
				Telegraph = 0.55,
				SpeedMetersPerSecond = 13,
				ProcChance = 0.5,
			},
		},
	},
	ArcaneSlime = {
		Style = "Melee",
		AggroMeters = 20,
		LeashMeters = 40,
		Hop = true,
		SplitInto = "ArcaneSlimeSmall",
		SplitCount = 2,
		Attacks = { { Kind = "Touch", Cooldown = 1.0, RangeMeters = 1.6, Telegraph = 0 } },
	},
	ArcaneSlimeSmall = {
		Style = "Melee",
		AggroMeters = 20,
		LeashMeters = 40,
		Hop = true,
		Attacks = { { Kind = "Touch", Cooldown = 0.9, RangeMeters = 1.3, Telegraph = 0 } },
	},
	StormBloater = {
		Style = "Kamikaze",
		AggroMeters = 25,
		LeashMeters = 45,
		Attacks = { { Kind = "Explode", Cooldown = 0, RangeMeters = 2.2, Telegraph = 1.1, RadiusMeters = 3.5 } },
	},
	CrystalGolem = {
		Style = "Boss",
		AggroMeters = 30,
		LeashMeters = 40,
		Attacks = {
			{ Kind = "Slam", Cooldown = 4.5, RangeMeters = 4.5, Telegraph = 1.0, RadiusMeters = 5 },
			{
				Kind = "Projectile",
				SpellId = "ArcaneMissile",
				Cooldown = 6,
				RangeMeters = 25,
				Telegraph = 0.8,
				Count = 3,
				SpeedMetersPerSecond = 11,
				DamageScale = 0.35,
			},
		},
	},
}

local Default: Behavior = {
	Style = "Melee",
	AggroMeters = 20,
	LeashMeters = 40,
	Attacks = { { Kind = "Touch", Cooldown = 1.2, RangeMeters = 1.6, Telegraph = 0 } },
}

return {
	get = function(rowName: string): Behavior
		return Catalog[rowName] or Default
	end,
	Defs = Catalog,
}
