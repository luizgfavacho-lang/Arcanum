#pragma once

#include "CoreMinimal.h"
#include "GameplayEffect.h"
#include "ArcanumHealEffect.generated.h"

/** Cura instantanea via meta-atributo IncomingHeal. SetByCaller: Data.Heal. */
UCLASS()
class ARCANUMCORE_API UArcanumHealEffect : public UGameplayEffect
{
	GENERATED_BODY()

public:
	UArcanumHealEffect();
};
