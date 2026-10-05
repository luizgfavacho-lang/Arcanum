#pragma once

#include "CoreMinimal.h"
#include "GameplayEffect.h"
#include "ArcanumDotEffect.generated.h"

/** Dano periodico (Queimadura, Sangramento). SetByCaller: Data.Duration, Data.Damage (por tick). Tag de estado via DynamicGrantedTags. */
UCLASS()
class ARCANUMCORE_API UArcanumDotEffect : public UGameplayEffect
{
	GENERATED_BODY()

public:
	UArcanumDotEffect();
};
