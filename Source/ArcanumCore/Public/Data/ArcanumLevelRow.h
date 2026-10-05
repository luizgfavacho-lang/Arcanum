#pragma once

#include "CoreMinimal.h"
#include "Engine/DataTable.h"
#include "ArcanumLevelRow.generated.h"

/** Data/Levels.csv -> DT_Levels. Nome da linha = nivel. Bonus sao acumulados ao subir. */
USTRUCT(BlueprintType)
struct ARCANUMCORE_API FArcanumLevelRow : public FTableRowBase
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Level")
	int32 XPToNext = 0;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Level")
	float MaxHealthBonus = 0.f;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Level")
	float MaxManaBonus = 0.f;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Level")
	float ManaRegenBonus = 0.f;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Level")
	float SpellPowerBonus = 0.f;

	/** 1 a cada 5 niveis. */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Level")
	int32 SkillPoints = 0;
};
