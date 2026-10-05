#pragma once

#include "CoreMinimal.h"
#include "GameplayEffect.h"
#include "ArcanumCooldownEffect.generated.h"

/** Recarga. SetByCaller: Data.Cooldown. Tag de recarga via DynamicGrantedTags. */
UCLASS()
class ARCANUMCORE_API UArcanumCooldownEffect : public UGameplayEffect
{
	GENERATED_BODY()

public:
	UArcanumCooldownEffect();
};
