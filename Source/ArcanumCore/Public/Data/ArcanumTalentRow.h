#pragma once

#include "CoreMinimal.h"
#include "Engine/DataTable.h"
#include "Data/ArcanumSchool.h"
#include "ArcanumTalentRow.generated.h"

/**
 * Data/Talents.csv -> DT_Talents. Cada talento concede a tag Talent.<Escola>.<Id> ao jogador;
 * as abilities consultam a tag e leem Value1..Value3 desta linha (sentido descrito em Notes).
 */
USTRUCT(BlueprintType)
struct ARCANUMCORE_API FArcanumTalentRow : public FTableRowBase
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Talent")
	EArcanumSchool School = EArcanumSchool::None;

	/** Posicao no ramo: 1-2 livres, 3-4 exigem 1 ponto no ramo, 5 exige 3. */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Talent")
	int32 Node = 1;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Talent")
	int32 RequiredPointsInBranch = 0;

	/** Nome da GameplayTag concedida (Config/Tags/ArcanumTalents.ini). */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Talent")
	FName GrantedTag;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Talent")
	float Value1 = 0.f;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Talent")
	float Value2 = 0.f;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Talent")
	float Value3 = 0.f;

	/** Referencia para designers; nao aparece no jogo (texto vem da String Table). */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Talent")
	FString Notes;
};
