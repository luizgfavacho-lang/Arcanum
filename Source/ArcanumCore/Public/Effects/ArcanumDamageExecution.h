#pragma once

#include "CoreMinimal.h"
#include "GameplayEffectExecutionCalculation.h"
#include "ArcanumDamageExecution.generated.h"

/**
 * Calculo de dano por escola. Captura Poder Magico e Afinidade do conjurador e Armadura do alvo,
 * le estados do alvo (Maldicao, Carga Arcana, Molhado) e delega a formula a ArcanumDamageMath.
 * Saida: meta-atributo IncomingDamage (o AttributeSet aplica Escudo de Mana e morte).
 */
UCLASS()
class ARCANUMCORE_API UArcanumDamageExecution : public UGameplayEffectExecutionCalculation
{
	GENERATED_BODY()

public:
	UArcanumDamageExecution();

	virtual void Execute_Implementation(const FGameplayEffectCustomExecutionParameters& ExecutionParams,
		FGameplayEffectCustomExecutionOutput& OutExecutionOutput) const override;
};
