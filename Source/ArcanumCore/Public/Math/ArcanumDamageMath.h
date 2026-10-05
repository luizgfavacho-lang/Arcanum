#pragma once

#include "CoreMinimal.h"
#include "Data/ArcanumSchool.h"

/**
 * Constantes de combate. Defaults = valores de design; em jogo vem de UArcanumCombatSettings
 * (Config/DefaultGame.ini). Struct C++ puro para ser testavel sem mundo/engine.
 */
struct ARCANUMCORE_API FArcanumDamageTuning
{
	/** Reducao por ponto de armadura (estilo "4% por ponto, teto 80%"). */
	float ArmorReductionPerPoint = 0.04f;
	float MaxArmorReduction = 0.80f;

	/** +1% de dano por ponto de Poder Magico. */
	float SpellPowerBonusPerPoint = 0.01f;

	/** +3% de dano por nivel de afinidade (0..10 => ate +30%). */
	float AffinityBonusPerLevel = 0.03f;

	/** Maldicao: +20% de dano recebido (talento Necrose eleva para +30%). */
	float CursedDamageTakenBonus = 0.20f;

	/** Carga Arcana: proximo golpe +25%, consumida no acerto. */
	float ArcaneChargeBonus = 0.25f;

	/** Combo Conducao: eletricidade em alvo molhado. */
	float WetElectricityMultiplier = 1.5f;
};

struct ARCANUMCORE_API FArcanumDamageInputs
{
	float BaseDamage = 0.f;
	/** Produto de runas/talentos/passivas (1 = neutro). */
	float DamageMultiplier = 1.f;
	float SpellPower = 0.f;
	/** Afinidade do conjurador com a escola da magia (0..10). */
	float Affinity = 0.f;
	float TargetArmor = 0.f;
	EArcanumSchool School = EArcanumSchool::None;
	bool bTargetCursed = false;
	bool bTargetArcaneCharged = false;
	bool bTargetWet = false;
};

struct FArcanumManaShieldResult
{
	float HealthDamage = 0.f;
	float ManaSpent = 0.f;
};

/** Regras de dano puras. Toda mudanca aqui deve vir com teste em Private/Tests. */
namespace ArcanumDamageMath
{
	/** Fracao do dano bloqueada pela armadura (0..MaxArmorReduction). */
	ARCANUMCORE_API float ArmorReduction(float Armor, const FArcanumDamageTuning& Tuning);

	/**
	 * Dano final de uma magia:
	 * Base * Mult * (1 + SP*k) * (1 + Afinidade*k) * [Maldicao] * [Carga] * [Combo] * (1 - Armadura)
	 */
	ARCANUMCORE_API float ComputeSpellDamage(const FArcanumDamageInputs& In, const FArcanumDamageTuning& Tuning);

	/** Dano no salto N (0 = primeiro alvo). Queda multiplicativa: Base * (1 - Falloff)^N. */
	ARCANUMCORE_API float ChainDamageAtJump(float BaseDamage, int32 JumpIndex, float FalloffPerJump);

	/** Escudo de Mana: cada ponto de dano custa ManaPerDamage; o que a mana nao cobre vai para a vida. */
	ARCANUMCORE_API FArcanumManaShieldResult ResolveManaShield(float Damage, float CurrentMana, float ManaPerDamage);

	/** Regeneracao pausa por Delay segundos apos causar/receber dano. */
	ARCANUMCORE_API bool CanRegenerateMana(double Now, double LastCombatTime, float Delay);
}
