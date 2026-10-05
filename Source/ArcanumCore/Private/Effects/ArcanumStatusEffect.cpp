#include "Effects/ArcanumStatusEffect.h"
#include "ArcanumGameplayTags.h"

UArcanumStatusEffect::UArcanumStatusEffect()
{
	DurationPolicy = EGameplayEffectDurationType::HasDuration;

	FSetByCallerFloat Duration;
	Duration.DataTag = ArcanumTags::Data_Duration;
	DurationMagnitude = FGameplayEffectModifierMagnitude(Duration);
}
