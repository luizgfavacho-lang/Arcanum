#pragma once

#include "CoreMinimal.h"
#include "Engine/DataTable.h"
#include "Data/ArcanumSchool.h"
#include "ArcanumRuneRow.generated.h"

/** Data/Runes.csv -> DT_Runes. School = None vale para todas as escolas. */
USTRUCT(BlueprintType)
struct ARCANUMCORE_API FArcanumRuneRow : public FTableRowBase
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Rune")
	EArcanumSchool School = EArcanumSchool::None;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Rune")
	float DamageMultiplier = 1.f;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Rune")
	float CostMultiplier = 1.f;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Rune")
	float CooldownMultiplier = 1.f;
};
