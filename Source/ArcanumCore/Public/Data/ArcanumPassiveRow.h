#pragma once

#include "CoreMinimal.h"
#include "Engine/DataTable.h"
#include "ArcanumPassiveRow.generated.h"

/**
 * Data/Passives.csv -> DT_Passives. Cada passiva tem bonus e desvantagem; o sentido de cada
 * valor por passiva esta em Notes e no GDD (Docs/01-GDD.md, secao Passivas).
 */
USTRUCT(BlueprintType)
struct ARCANUMCORE_API FArcanumPassiveRow : public FTableRowBase
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Passive")
	float BonusValue = 0.f;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Passive")
	float BonusValue2 = 0.f;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Passive")
	float PenaltyValue = 0.f;

	/** Limiar (fracao de vida, distancia etc.). */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Passive")
	float Threshold = 0.f;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Passive")
	float Chance = 0.f;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Passive")
	FString Notes;
};
