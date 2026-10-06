--!strict
-- Constantes globais de combate (mesmos valores do GDD; antes em Config/DefaultGame.ini da Unreal).
-- Mudou algo aqui? Rode os testes: `lune run tests`.

return table.freeze({
	-- TESTES: jogadores com mana e vida infinitas (custos, dano e custo de vida nao descontam;
	-- numeros de dano e tremor continuam aparecendo). DESLIGAR (false) antes de publicar.
	DevInfiniteResources = true,

	-- Dano (ver Math/DamageMath)
	ArmorReductionPerPoint = 0.04,
	MaxArmorReduction = 0.80,
	SpellPowerBonusPerPoint = 0.01,
	AffinityBonusPerLevel = 0.03,
	CursedDamageTakenBonus = 0.20,
	ArcaneChargeBonus = 0.25,
	WetElectricityMultiplier = 1.5,

	-- Mana
	ManaShieldManaPerDamage = 2.0,
	ManaRegenCombatDelay = 3.0,
	ManaRegenTickInterval = 0.25,

	-- Conjuracao
	GlobalCooldown = 0.4,
	DotTickInterval = 0.5,

	-- Jogador nivel 1 (escala do mod: 20 de vida)
	PlayerBaseHealth = 20,
	PlayerBaseMana = 100,
	PlayerBaseManaRegen = 3,
	PlayerWalkSpeed = 16,

	-- Rede: tolerancia da mira enviada pelo cliente
	MaxAimOriginOffset = 12, -- studs entre a origem enviada e a cabeca do personagem

	-- Esquiva do jogador (Q / Shift esquerdo / B no controle)
	DodgeCooldown = 0.9,
	DodgeInvulnerability = 0.35, -- segundos sem tomar dano direto (DoT continua)
	DodgeSpeed = 62, -- studs/s do impulso (aplicado pelo cliente, dono da fisica do personagem)
	DodgeDuration = 0.2,
	PerfectDodgeMana = 12, -- desviou de um golpe de verdade durante a janela: recupera mana

	-- Equilibrio e empurrao dos inimigos (Math/CombatMath)
	PoiseRecoverDelay = 1.5,
	PoiseRecoverPerSecond = 0.6,
	StaggerImmunity = 2.5,
	KnockbackSpeed = 36,
	KnockbackMinFraction = 0.12,
	KnockbackDuration = 0.16,

	-- Inimigos
	EliteChance = 0.10,
	EnemyRespawnSeconds = 8,
})
