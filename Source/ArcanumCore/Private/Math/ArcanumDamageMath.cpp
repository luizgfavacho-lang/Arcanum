#include "Math/ArcanumDamageMath.h"

namespace ArcanumDamageMath
{
	float ArmorReduction(float Armor, const FArcanumDamageTuning& Tuning)
	{
		return FMath::Clamp(Armor * Tuning.ArmorReductionPerPoint, 0.f, Tuning.MaxArmorReduction);
	}

	float ComputeSpellDamage(const FArcanumDamageInputs& In, const FArcanumDamageTuning& Tuning)
	{
		if (In.BaseDamage <= 0.f)
		{
			return 0.f;
		}

		float Damage = In.BaseDamage * FMath::Max(In.DamageMultiplier, 0.f);
		Damage *= 1.f + FMath::Max(In.SpellPower, 0.f) * Tuning.SpellPowerBonusPerPoint;
		Damage *= 1.f + FMath::Clamp(In.Affinity, 0.f, 10.f) * Tuning.AffinityBonusPerLevel;

		if (In.bTargetCursed)
		{
			Damage *= 1.f + Tuning.CursedDamageTakenBonus;
		}
		if (In.bTargetArcaneCharged)
		{
			Damage *= 1.f + Tuning.ArcaneChargeBonus;
		}
		if (In.bTargetWet && In.School == EArcanumSchool::Electricity)
		{
			Damage *= Tuning.WetElectricityMultiplier;
		}

		Damage *= 1.f - ArmorReduction(In.TargetArmor, Tuning);
		return FMath::Max(Damage, 0.f);
	}

	float ChainDamageAtJump(float BaseDamage, int32 JumpIndex, float FalloffPerJump)
	{
		const float Keep = FMath::Clamp(1.f - FalloffPerJump, 0.f, 1.f);
		return BaseDamage * FMath::Pow(Keep, static_cast<float>(FMath::Max(JumpIndex, 0)));
	}

	FArcanumManaShieldResult ResolveManaShield(float Damage, float CurrentMana, float ManaPerDamage)
	{
		FArcanumManaShieldResult Result;
		if (Damage <= 0.f)
		{
			return Result;
		}
		if (ManaPerDamage <= 0.f)
		{
			Result.HealthDamage = Damage;
			return Result;
		}

		const float Absorbable = FMath::Max(CurrentMana, 0.f) / ManaPerDamage;
		const float Absorbed = FMath::Min(Damage, Absorbable);
		Result.ManaSpent = Absorbed * ManaPerDamage;
		Result.HealthDamage = Damage - Absorbed;
		return Result;
	}

	bool CanRegenerateMana(double Now, double LastCombatTime, float Delay)
	{
		return (Now - LastCombatTime) >= Delay;
	}
}
