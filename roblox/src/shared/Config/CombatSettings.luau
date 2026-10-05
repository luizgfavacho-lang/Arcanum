--!strict
-- Constantes globais de combate (mesmos valores do GDD; antes em Config/DefaultGame.ini da Unreal).
-- Mudou algo aqui? Rode os testes: `lune run tests`.

return table.freeze({
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

	-- Inimigos
	EliteChance = 0.10,
	EnemyRespawnSeconds = 8,
})
