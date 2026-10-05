#pragma once

#include "CoreMinimal.h"
#include "Engine/DataTable.h"
#include "Data/ArcanumSchool.h"
#include "ArcanumEnemyRow.generated.h"

/** Data/Enemies.csv -> DT_Enemies. Valores base antes de elite e escala de dificuldade. */
USTRUCT(BlueprintType)
struct ARCANUMCORE_API FArcanumEnemyRow : public FTableRowBase
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Enemy")
	float MaxHealth = 20.f;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Enemy")
	float Armor = 0.f;

	/** Dano dos ataques basicos (antes de Poder Magico). */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Enemy")
	float AttackDamage = 3.f;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Enemy")
	float MoveSpeedMetersPerSecond = 3.5f;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Enemy")
	int32 XPReward = 5;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Enemy")
	EArcanumSchool School = EArcanumSchool::None;

	/** Mob magico: elegivel a elite (10%: vida x2, dano x1,5, loot x2). */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Enemy")
	bool bMagical = false;

	/** Morto-vivo: ignorado pela passiva Coveiro ate ser atacado. */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Enemy")
	bool bUndead = false;

	/** Chefe/minichefe: Toque Mortal tem teto, imune a paralisia longa. */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Enemy")
	bool bBoss = false;
};
