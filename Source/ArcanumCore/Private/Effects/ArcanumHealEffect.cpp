#include "Effects/ArcanumHealEffect.h"
#include "ArcanumGameplayTags.h"
#include "Attributes/ArcanumAttributeSet.h"

UArcanumHealEffect::UArcanumHealEffect()
{
	DurationPolicy = EGameplayEffectDurationType::Instant;

	FSetByCallerFloat Heal;
	Heal.DataTag = ArcanumTags::Data_Heal;

	FGameplayModifierInfo Modifier;
	Modifier.Attribute = UArcanumAttributeSet::GetIncomingHealAttribute();
	Modifier.ModifierOp = EGameplayModOp::Additive;
	Modifier.ModifierMagnitude = FGameplayEffectModifierMagnitude(Heal);
	Modifiers.Add(Modifier);
}
