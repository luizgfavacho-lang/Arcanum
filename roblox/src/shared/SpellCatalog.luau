--!strict
-- Comportamento de cada magia implementada (equivale ao DA_Spell_<Id> da Unreal).
-- Os NUMEROS ficam em Data/Spells.luau (gerado do CSV). Aqui so: tipo, estado aplicado e visual.
-- Modulo puro (sem servicos do Roblox) para rodar nos testes.

export type Kind =
	"Projectile"
	| "Hitscan"
	| "ChainLightning"
	| "Strike"
	| "Nova"
	| "Line"
	| "Zone" -- area com duracao (Spells/Zone): Mode Static | Wall | Vortex | Singularity | Rain | Hourglass
	| "Barrage" -- golpes do ceu (Spells/Barrage): Mode Storm | Stars | Meteor | Verdict | Crown
	| "Buff" -- em si mesmo (Spells/Buff): Mode ManaShield | EmberArmor | Sacrifice | Pact
	| "Blink" -- Passo Relampago (Spells/Movement)
	| "Portal" -- Portal Arcano (Spells/Movement)
	| "Control" -- alvo unico/area (Spells/Control): Mode Prison | Hook | Chain | DeathTouch | Curse | Hemorrhage
	| "Beam" -- canalizada em linha (Spells/Beam)
	| "Flamethrower" -- canalizada em cone (Spells/Flamethrower): Piromania
	| "Lance" -- laser carregado que atravessa (Spells/Beam)
	| "Slash" -- golpe corpo a corpo em arco (Spells/Melee)
	| "Summon" -- servos (Spells/Summon)

export type Def = {
	Kind: Kind,
	ProcState: string?, -- estado aplicado com ProcChance (ver Data/Spells)
	Homing: boolean?, -- projeteis teleguiados
	SpreadDegrees: number?, -- leque quando Count > 1
	Visual: string?, -- "Bolt", "LifeStream", "Orb"...
	DestroysProjectiles: boolean?, -- Nova que apaga projeteis hostis em volta
	LavaPool: boolean?, -- projetil que abre poca de lava onde termina (Spells/Hazard)
	Mode: string?, -- variante dentro do tipo (ver Kind)
	ShockOrb: boolean?, -- projetil que atravessa e da choques em volta (Bola de Relampago)
	Radial: boolean?, -- projeteis em todas as direcoes, na horizontal (Rosa dos Lamentos)
	Combustion: boolean?, -- Nova: quem ja queimava leva x1,5 (SpellMath.novaMultiplier)
	Slow: number?, -- fracao de lentidao aplicada a quem e atingido (0..0,9)
	SlowSeconds: number?,
	Stun: number?, -- segundos de atordoamento extra (Espinhos)
	Summon: string?, -- linha de Enemies.csv do servo
	Army: boolean?, -- Exercito dos Mortos: Count esqueletos + MaxTargets brutos
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
	-- Circulo II (Grimorio)
	SummonedBolt = { Kind = "Strike", ProcState = "Paralyzed" }, -- raio do ceu no ponto mirado
	MagmaLance = { Kind = "Projectile", Visual = "Lance", LavaPool = true }, -- perfura e abre poca de lava
	FlameNova = { Kind = "Nova", ProcState = "Burning", Combustion = true }, -- explosao, empurra, Combustao
	ArcanePulse = { Kind = "Nova", DestroysProjectiles = true, Slow = 0.4, SlowSeconds = 2.5 }, -- empurra, apaga projeteis, lentidao
	WanderingSouls = { Kind = "Projectile", Homing = true, SpreadDegrees = 40, Visual = "Soul" }, -- cura
	CrimsonSpikes = { Kind = "Line", ProcState = "Bleeding", Stun = 0.9 }, -- fileira de espinhos, arremessa e atordoa

	-- Eletricidade
	StaticField = { Kind = "Zone", Mode = "Static", ProcState = "Paralyzed" }, -- zona eletrica que segue
	LightningStep = { Kind = "Blink" }, -- teleporte que eletrocuta o caminho
	BallLightning = { Kind = "Projectile", ShockOrb = true, ProcState = "Paralyzed", Visual = "Orb" },
	Tempest = { Kind = "Barrage", Mode = "Storm", ProcState = "Paralyzed" }, -- raios em sequencia
	CrownOfThunder = { Kind = "Barrage", Mode = "Crown", ProcState = "Paralyzed" }, -- raio em todos em volta
	-- Fogo
	FlameWall = { Kind = "Zone", Mode = "Wall", ProcState = "Burning" }, -- parede que bloqueia criaturas
	EmberArmor = { Kind = "Buff", Mode = "EmberArmor" },
	InfernalVortex = { Kind = "Flamethrower", ProcState = "Burning" }, -- Piromania: lanca-chamas canalizado
	Meteor = { Kind = "Barrage", Mode = "Meteor", ProcState = "Burning" },
	DawnVerdict = { Kind = "Barrage", Mode = "Verdict" }, -- coluna solar, dano dividido
	-- Energia
	ManaShield = { Kind = "Buff", Mode = "ManaShield" },
	ArcaneBeam = { Kind = "Beam" },
	EnergyPrison = { Kind = "Control", Mode = "Prison" },
	ArcanePortal = { Kind = "Portal" },
	Singularity = { Kind = "Zone", Mode = "Singularity" }, -- puxa e implode
	StarShower = { Kind = "Barrage", Mode = "Stars" },
	ShatteredHourglass = { Kind = "Zone", Mode = "Hourglass" }, -- congela inimigos e projeteis
	FirmamentLance = { Kind = "Lance" },
	-- Necromancia
	RaiseSkeleton = { Kind = "Summon", Summon = "SkeletonServant" },
	RaiseBrute = { Kind = "Summon", Summon = "BruteServant" },
	DeathTouch = { Kind = "Control", Mode = "DeathTouch", ProcState = "Weakened" },
	Curse = { Kind = "Control", Mode = "Curse", ProcState = "Poisoned" }, -- + Maldicao
	ArmyOfTheDead = { Kind = "Summon", Army = true },
	RoseOfLaments = { Kind = "Projectile", Radial = true, ProcState = "Weakened", Visual = "Soul" },
	-- Sangue
	BloodBlade = { Kind = "Slash", ProcState = "Bleeding" },
	SacrificeRitual = { Kind = "Buff", Mode = "Sacrifice" },
	CrimsonChain = { Kind = "Control", Mode = "Chain", ProcState = "Paralyzed" },
	CrimsonRain = { Kind = "Zone", Mode = "Rain" }, -- fere inimigos e cura aliados
	Hemorrhage = { Kind = "Control", Mode = "Hemorrhage", ProcState = "Bleeding" },
	BloodPact = { Kind = "Buff", Mode = "Pact" },
	CrimsonHook = { Kind = "Control", Mode = "Hook" },
}

-- Magias iniciais: a mais basica (Circulo I) de cada escola. As outras se compram no Grimorio
-- com essencias (Math/EssenceMath).
local StartingSlots = { "Spark", "Fireball", "ArcaneMissile", "LifeDrain", "BloodBlade" }

return table.freeze({
	Defs = table.freeze(Catalog),
	StartingSlots = table.freeze(StartingSlots),
	NumSlots = 5,
	isChanneled = function(spellId: string): boolean
		local def = Catalog[spellId]
		return def ~= nil and (def.Kind == "ChainLightning" or def.Kind == "Beam" or def.Kind == "Flamethrower")
	end,
})
