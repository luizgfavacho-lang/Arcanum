#include "Effects/ArcanumDamageExecution.h"

#include "ArcanumGameplayTags.h"
#include "Attributes/ArcanumAttributeSet.h"
#include "Data/ArcanumSchool.h"
#include "Math/ArcanumDamageMath.h"
#include "Settings/ArcanumCombatSettings.h"

namespace
{
	/** Capturas pelos getters publicos do AttributeSet (os membros sao protected). */
	struct FDamageCaptures
	{
		FGameplayEffectAttributeCaptureDefinition SpellPowerDef;
		FGameplayEffectAttributeCaptureDefinition ArmorDef;
		FGameplayEffectAttributeCaptureDefinition AffinityElectricityDef;
		FGameplayEffectAttributeCaptureDefinition AffinityFireDef;
		FGameplayEffectAttributeCaptureDefinition AffinityEnergyDef;
		FGameplayEffectAttributeCaptureDefinition AffinityNecromancyDef;
		FGameplayEffectAttributeCaptureDefinition AffinityBloodDef;

		FDamageCaptures()
		{
			using ECapture = EGameplayEffectAttributeCaptureSource;
			// Snapshot = false: usa os valores no momento do acerto (buffs aplicados durante o voo contam).
			SpellPowerDef = FGameplayEffectAttributeCaptureDefinition(UArcanumAttributeSet::GetSpellPowerAttribute(), ECapture::Source, false);
			ArmorDef = FGameplayEffectAttributeCaptureDefinition(UArcanumAttributeSet::GetArmorAttribute(), ECapture::Target, false);
			AffinityElectricityDef = FGameplayEffectAttributeCaptureDefinition(UArcanumAttributeSet::GetAffinityElectricityAttribute(), ECapture::Source, false);
			AffinityFireDef = FGameplayEffectAttributeCaptureDefinition(UArcanumAttributeSet::GetAffinityFireAttribute(), ECapture::Source, false);
			AffinityEnergyDef = FGameplayEffectAttributeCaptureDefinition(UArcanumAttributeSet::GetAffinityEnergyAttribute(), ECapture::Source, false);
			AffinityNecromancyDef = FGameplayEffectAttributeCaptureDefinition(UArcanumAttributeSet::GetAffinityNecromancyAttribute(), ECapture::Source, false);
			AffinityBloodDef = FGameplayEffectAttributeCaptureDefinition(UArcanumAttributeSet::GetAffinityBloodAttribute(), ECapture::Source, false);
		}

		const FGameplayEffectAttributeCaptureDefinition* AffinityFor(EArcanumSchool School) const
		{
			switch (School)
			{
			case EArcanumSchool::Electricity: return &AffinityElectricityDef;
			case EArcanumSchool::Fire:        return &AffinityFireDef;
			case EArcanumSchool::Energy:      return &AffinityEnergyDef;
			case EArcanumSchool::Necromancy:  return &AffinityNecromancyDef;
			case EArcanumSchool::Blood:       return &AffinityBloodDef;
			default:                          return nullptr;
			}
		}
	};

	const FDamageCaptures& Captures()
	{
		static FDamageCaptures Instance;
		return Instance;
	}
}

UArcanumDamageExecution::UArcanumDamageExecution()
{
	const FDamageCaptures& C = Captures();
	RelevantAttributesToCapture.Add(C.SpellPowerDef);
	RelevantAttributesToCapture.Add(C.ArmorDef);
	RelevantAttributesToCapture.Add(C.AffinityElectricityDef);
	RelevantAttributesToCapture.Add(C.AffinityFireDef);
	RelevantAttributesToCapture.Add(C.AffinityEnergyDef);
	RelevantAttributesToCapture.Add(C.AffinityNecromancyDef);
	RelevantAttributesToCapture.Add(C.AffinityBloodDef);
}

void UArcanumDamageExecution::Execute_Implementation(const FGameplayEffectCustomExecutionParameters& ExecutionParams,
	FGameplayEffectCustomExecutionOutput& OutExecutionOutput) const
{
	const FGameplayEffectSpec& Spec = ExecutionParams.GetOwningSpec();
	const FDamageCaptures& C = Captures();

	FAggregatorEvaluateParameters EvalParams;
	EvalParams.SourceTags = Spec.CapturedSourceTags.GetAggregatedTags();
	EvalParams.TargetTags = Spec.CapturedTargetTags.GetAggregatedTags();

	FGameplayTagContainer AssetTags;
	Spec.GetAllAssetTags(AssetTags);

	FArcanumDamageInputs In;
	In.BaseDamage = Spec.GetSetByCallerMagnitude(ArcanumTags::Data_Damage, false, 0.f);
	In.DamageMultiplier = Spec.GetSetByCallerMagnitude(ArcanumTags::Data_DamageMultiplier, false, 1.f);
	In.School = ArcanumSchool::FromTags(AssetTags);

	ExecutionParams.AttemptCalculateCapturedAttributeMagnitude(C.SpellPowerDef, EvalParams, In.SpellPower);
	ExecutionParams.AttemptCalculateCapturedAttributeMagnitude(C.ArmorDef, EvalParams, In.TargetArmor);
	if (const FGameplayEffectAttributeCaptureDefinition* AffinityDef = C.AffinityFor(In.School))
	{
		ExecutionParams.AttemptCalculateCapturedAttributeMagnitude(*AffinityDef, EvalParams, In.Affinity);
	}

	if (const FGameplayTagContainer* TargetTags = EvalParams.TargetTags)
	{
		In.bTargetCursed = TargetTags->HasTag(ArcanumTags::State_Cursed);
		In.bTargetWet = TargetTags->HasTag(ArcanumTags::State_Wet);
		// DoTs nao consomem nem se beneficiam da Carga Arcana.
		In.bTargetArcaneCharged = Spec.GetPeriod() <= 0.f && TargetTags->HasTag(ArcanumTags::State_ArcaneCharge);
	}

	const float Damage = ArcanumDamageMath::ComputeSpellDamage(In, GetDefault<UArcanumCombatSettings>()->MakeDamageTuning());
	if (Damage > 0.f)
	{
		OutExecutionOutput.AddOutputModifier(FGameplayModifierEvaluatedData(
			UArcanumAttributeSet::GetIncomingDamageAttribute(), EGameplayModOp::Additive, Damage));
	}
}
