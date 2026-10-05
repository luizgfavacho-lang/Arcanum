#pragma once

#include "CoreMinimal.h"
#include "Engine/DataTable.h"
#include "Data/ArcanumSchool.h"
#include "ArcanumComboRow.generated.h"

/** Data/Combos.csv -> DT_Combos. Magia da escola TriggerSchool atingindo alvo com TargetState. */
USTRUCT(BlueprintType)
struct ARCANUMCORE_API FArcanumComboRow : public FTableRowBase
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Combo")
	EArcanumSchool TriggerSchool = EArcanumSchool::None;

	/** Nome da tag de estado do alvo (ex.: State.Wet). */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Combo")
	FName TargetState;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Combo")
	float DamageMultiplier = 1.f;

	/** Efeito extra identificado por nome (tratado em C++). Ex.: Spread, Extinguish, ForceParalyze. */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Combo")
	FName ExtraEffect;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Combo")
	float ExtraValue = 0.f;

	/** Se true, remove o estado do alvo ao disparar. */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Combo")
	bool bConsumesState = false;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Combo")
	FString Notes;
};
