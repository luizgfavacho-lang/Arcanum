#pragma once

#include "CoreMinimal.h"
#include "GameplayEffect.h"
#include "ArcanumStatusEffect.generated.h"

/** Estado temporario sem dano (Paralisia, Carga Arcana, Molhado...). SetByCaller: Data.Duration. Tag via DynamicGrantedTags. */
UCLASS()
class ARCANUMCORE_API UArcanumStatusEffect : public UGameplayEffect
{
	GENERATED_BODY()

public:
	UArcanumStatusEffect();
};
