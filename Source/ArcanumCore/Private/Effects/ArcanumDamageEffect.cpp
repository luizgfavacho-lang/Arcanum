#include "Effects/ArcanumDamageEffect.h"
#include "Effects/ArcanumDamageExecution.h"

UArcanumDamageEffect::UArcanumDamageEffect()
{
	DurationPolicy = EGameplayEffectDurationType::Instant;

	FGameplayEffectExecutionDefinition Execution;
	Execution.CalculationClass = UArcanumDamageExecution::StaticClass();
	Executions.Add(Execution);
}
