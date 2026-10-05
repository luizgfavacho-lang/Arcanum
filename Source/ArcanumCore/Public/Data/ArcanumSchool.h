#pragma once

#include "CoreMinimal.h"
#include "GameplayTagContainer.h"
#include "ArcanumSchool.generated.h"

/** As cinco escolas de magia. Os nomes sao usados como texto nos CSV (coluna School). */
UENUM(BlueprintType)
enum class EArcanumSchool : uint8
{
	None,
	Electricity,
	Fire,
	Energy,
	Necromancy,
	Blood
};

namespace ArcanumSchool
{
	/** Tag School.* correspondente (vazia para None). */
	ARCANUMCORE_API FGameplayTag ToTag(EArcanumSchool School);

	/** Primeira tag School.* encontrada no container; None se nao houver. */
	ARCANUMCORE_API EArcanumSchool FromTags(const FGameplayTagContainer& Tags);
}
