#include "Effects/ArcanumDotEffect.h"
#include "ArcanumGameplayTags.h"
#include "Effects/ArcanumDamageExecution.h"

UArcanumDotEffect::UArcanumDotEffect()
{
	DurationPolicy = EGameplayEffectDurationType::HasDuration;

	FSetByCallerFloat Duration;
	Duration.DataTag = ArcanumTags::Data_Duration;
	DurationMagnitude = FGameplayEffectModifierMagnitude(Duration);

	// Tick a cada 0,5 s; o primeiro tick ocorre apos 0,5 s (nao na aplicacao).
	Period = FScalableFloat(0.5f);
	bExecutePeriodicEffectOnApplication = false;

	FGameplayEffectExecutionDefinition Execution;
	Execution.CalculationClass = UArcanumDamageExecution::StaticClass();
	Executions.Add(Execution);
}
