#pragma once

#include "CoreMinimal.h"
#include "GameplayEffect.h"
#include "ArcanumDamageEffect.generated.h"

/** Dano instantaneo de magia. SetByCaller: Data.Damage, Data.DamageMultiplier. Escola via asset tag dinamica. */
UCLASS()
class ARCANUMCORE_API UArcanumDamageEffect : public UGameplayEffect
{
	GENERATED_BODY()

public:
	UArcanumDamageEffect();
};
