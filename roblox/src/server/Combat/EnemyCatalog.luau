--!strict
-- Comportamento de cada criatura (IA). O DANO vem de Data/Enemies.csv (coluna AttackDamage, vezes
-- DamageScale); aqui ficam percepcao, movimento, equilibrio, recargas e telegrafias.
-- Distancias em METROS (convertidas com Units.meters).
--
-- Estilos de movimento:
--   Ranged   mantem distancia (KeepMin..KeepMax), anda de lado, desvia de magias, teleporta se encurralado
--   Melee    flanqueia e cerca o alvo junto com o bando; salta (Hop)
--   Kamikaze flutua em zigue-zague ate o alvo, incha e explode
--   Boss     avanca devagar, alterna ataques e enfurece com pouca vida (Enrage)
-- Ataques:
--   Projectile  usa o visual/comportamento de uma magia (SpellId) com numeros proprios; Volley = rajada
--   Pounce      agacha (aviso) e da um bote em salto; acerta quem estiver no caminho
--   Touch       contato corpo a corpo
--   Slam        area no chao em volta dele (aviso no chao); EnrageRepeat = golpes extras enfurecido
--   SpikeLine   linha de cristais do chefe ate o alvo (aviso em faixa)
--   Explode     area em volta dele, depois morre
-- Equilibrio (Poise): dano acumulado que atordoa e INTERROMPE o golpe em preparacao (Math/CombatMath).
-- Weight: resistencia a empurrao (0 = imovel).

export type Attack = {
	Kind: string,
	SpellId: string?,
	Cooldown: number,
	RangeMeters: number,
	MinRangeMeters: number?, -- perto demais: prefere outro ataque
	Telegraph: number, -- segundos de aviso antes do golpe
	RadiusMeters: number?,
	WidthMeters: number?,
	LengthMeters: number?,
	DamageScale: number?,
	Count: number?, -- projeteis por disparo
	Volley: number?, -- disparos seguidos
	SpeedMetersPerSecond: number?, -- projeteis (mais lentos que os do jogador: desviaveis)
	ProcChance: number?,
	Recovery: number?, -- segundos parado depois do golpe (janela para punir)
	EnrageRepeat: number?,
}

export type Behavior = {
	Style: string,
	AggroMeters: number, -- alcance da visao (cone a frente)
	HearMeters: number, -- perto assim, percebe mesmo de costas
	LeashMeters: number, -- longe demais de casa: desiste e volta
	WanderMeters: number, -- passeio quando ocioso (0 = fica de guarda)
	PackMeters: number, -- chama aliados ociosos nesse raio ao avistar o alvo
	Weight: number,
	Poise: number,
	StaggerTime: number,
	Staff: boolean?,
	KeepMin: number?,
	KeepMax: number?,
	BlinkWhenCloserThan: number?,
	BlinkCooldown: number?,
	DodgeChance: number?, -- chance de desviar de projeteis (vezes a agilidade da criatura)
	FleeBelow: number?, -- fracao de vida em que pode fugir (uma vez; criaturas corajosas nao fogem)
	Hop: boolean?,
	SplitInto: string?,
	SplitCount: number?,
	DeathBurst: { DamageScale: number, Delay: number, RadiusMeters: number }?, -- estoura ao morrer (fere todos)
	Enrage: { Below: number, CooldownScale: number, SpeedScale: number }?,
	Attacks: { Attack },
}

local Catalog: { [string]: Behavior } = {
	SkeletonMage = {
		Style = "Ranged",
		AggroMeters = 26,
		HearMeters = 6,
		LeashMeters = 45,
		WanderMeters = 4,
		PackMeters = 16,
		Weight = 1,
		Poise = 7,
		StaggerTime = 0.9,
		Staff = true,
		KeepMin = 8,
		KeepMax = 15,
		BlinkWhenCloserThan = 3.5,
		BlinkCooldown = 8,
		DodgeChance = 0.55,
		FleeBelow = 0.3,
		Attacks = {
			{
				Kind = "Projectile",
				SpellId = "Fireball",
				Cooldown = 2.8,
				RangeMeters = 22,
				Telegraph = 0.6,
				SpeedMetersPerSecond = 13,
				ProcChance = 0.5,
				Recovery = 0.3,
			},
		},
	},
	ArcaneSlime = {
		Style = "Melee",
		AggroMeters = 18,
		HearMeters = 6,
		LeashMeters = 40,
		WanderMeters = 6,
		PackMeters = 12,
		Weight = 1.2,
		Poise = 6,
		StaggerTime = 0.7,
		Hop = true,
		SplitInto = "ArcaneSlimeSmall",
		SplitCount = 2,
		Attacks = {
			{
				Kind = "Pounce",
				Cooldown = 2.6,
				RangeMeters = 7,
				MinRangeMeters = 2.2,
				Telegraph = 0.5,
				DamageScale = 1.5,
				Recovery = 0.6,
			},
			{ Kind = "Touch", Cooldown = 1.3, RangeMeters = 1.4, Telegraph = 0 },
		},
	},
	ArcaneSlimeSmall = {
		Style = "Melee",
		AggroMeters = 18,
		HearMeters = 6,
		LeashMeters = 40,
		WanderMeters = 5,
		PackMeters = 10,
		Weight = 0.6,
		Poise = 2.5,
		StaggerTime = 0.6,
		Hop = true,
		Attacks = {
			{
				Kind = "Pounce",
				Cooldown = 1.8,
				RangeMeters = 5.5,
				MinRangeMeters = 1.5,
				Telegraph = 0.35,
				DamageScale = 1.5,
				Recovery = 0.45,
			},
			{ Kind = "Touch", Cooldown = 1.1, RangeMeters = 1.1, Telegraph = 0 },
		},
	},
	StormBloater = {
		Style = "Kamikaze",
		AggroMeters = 24,
		HearMeters = 8,
		LeashMeters = 45,
		WanderMeters = 6,
		PackMeters = 10,
		Weight = 0.8,
		Poise = math.huge, -- e uma bomba: nao para de inchar
		StaggerTime = 0,
		DeathBurst = { DamageScale = 0.6, Delay = 0.35, RadiusMeters = 3.5 },
		Attacks = { { Kind = "Explode", Cooldown = 0, RangeMeters = 2.2, Telegraph = 1.1, RadiusMeters = 3.5 } },
	},
	CrystalGolem = {
		Style = "Boss",
		AggroMeters = 26,
		HearMeters = 10,
		LeashMeters = 40,
		WanderMeters = 0,
		PackMeters = 0,
		Weight = 0,
		Poise = 45,
		StaggerTime = 1.4,
		Enrage = { Below = 0.5, CooldownScale = 0.7, SpeedScale = 1.3 },
		Attacks = {
			{
				Kind = "Slam",
				Cooldown = 4.5,
				RangeMeters = 4.5,
				Telegraph = 1.0,
				RadiusMeters = 5,
				Recovery = 0.6,
				EnrageRepeat = 1,
			},
			{
				Kind = "SpikeLine",
				Cooldown = 7,
				RangeMeters = 16,
				MinRangeMeters = 4,
				Telegraph = 0.9,
				WidthMeters = 2.2,
				LengthMeters = 17,
				DamageScale = 0.8,
				Recovery = 0.5,
			},
			{
				Kind = "Projectile",
				SpellId = "ArcaneMissile",
				Cooldown = 6,
				RangeMeters = 25,
				MinRangeMeters = 6,
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
	HearMeters = 6,
	LeashMeters = 40,
	WanderMeters = 4,
	PackMeters = 12,
	Weight = 1,
	Poise = 8,
	StaggerTime = 0.8,
	Attacks = { { Kind = "Touch", Cooldown = 1.2, RangeMeters = 1.6, Telegraph = 0 } },
}

return {
	get = function(rowName: string): Behavior
		return Catalog[rowName] or Default
	end,
	Defs = Catalog,
}
