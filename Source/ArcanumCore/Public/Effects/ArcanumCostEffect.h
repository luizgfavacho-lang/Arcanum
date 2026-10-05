#pragma once

#include "CoreMinimal.h"
#include "GameplayEffect.h"
#include "ArcanumCostEffect.generated.h"

/** Custo de magia. SetByCaller: Data.ManaCost e Data.HealthCost (valores negativos). */
UCLASS()
class ARCANUMCORE_API UArcanumCostEffect : public UGameplayEffect
{
	GENERATED_BODY()

public:
	UArcanumCostEffect();
};
