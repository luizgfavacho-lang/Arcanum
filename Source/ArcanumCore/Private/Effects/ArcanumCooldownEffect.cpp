#include "Effects/ArcanumCooldownEffect.h"
#include "ArcanumGameplayTags.h"

UArcanumCooldownEffect::UArcanumCooldownEffect()
{
	DurationPolicy = EGameplayEffectDurationType::HasDuration;

	FSetByCallerFloat Duration;
	Duration.DataTag = ArcanumTags::Data_Cooldown;
	DurationMagnitude = FGameplayEffectModifierMagnitude(Duration);
}
