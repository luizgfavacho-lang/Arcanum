#include "Effects/ArcanumCostEffect.h"
#include "ArcanumGameplayTags.h"
#include "Attributes/ArcanumAttributeSet.h"

namespace
{
	FGameplayModifierInfo MakeSetByCallerAdd(const FGameplayAttribute& Attribute, const FGameplayTag& DataTag)
	{
		FSetByCallerFloat SetByCaller;
		SetByCaller.DataTag = DataTag;

		FGameplayModifierInfo Modifier;
		Modifier.Attribute = Attribute;
		Modifier.ModifierOp = EGameplayModOp::Additive;
		Modifier.ModifierMagnitude = FGameplayEffectModifierMagnitude(SetByCaller);
		return Modifier;
	}
}

UArcanumCostEffect::UArcanumCostEffect()
{
	DurationPolicy = EGameplayEffectDurationType::Instant;
	Modifiers.Add(MakeSetByCallerAdd(UArcanumAttributeSet::GetManaAttribute(), ArcanumTags::Data_ManaCost));
	Modifiers.Add(MakeSetByCallerAdd(UArcanumAttributeSet::GetHealthAttribute(), ArcanumTags::Data_HealthCost));
}
