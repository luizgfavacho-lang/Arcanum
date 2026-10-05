#pragma once

#include "CoreMinimal.h"
#include "Engine/DataTable.h"
#include "Data/ArcanumSchool.h"
#include "ArcanumSpellRow.generated.h"

/**
 * Linha de balanceamento de uma magia (Data/Spells.csv -> DT_Spells).
 * Unidades de design: metros e segundos. O codigo converte para cm (x100).
 * Campos que uma magia nao usa ficam 0.
 */
USTRUCT(BlueprintType)
struct ARCANUMCORE_API FArcanumSpellRow : public FTableRowBase
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Spell")
	EArcanumSchool School = EArcanumSchool::None;

	/** 1, 2 ou 3 (4 = suprema). */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Spell")
	int32 Tier = 1;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Spell")
	bool bChanneled = false;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Cost")
	float ManaCost = 0.f;

	/** Fracao da vida maxima paga como custo (magias de Sangue). 0.3 = 30%. */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Cost")
	float HealthCostPct = 0.f;

	/** Mana drenada por segundo enquanto canaliza. */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Cost")
	float ManaPerSecond = 0.f;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Cost")
	float Cooldown = 0.f;

	/** Dano base por acerto (ou por segundo, em canalizadas). */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Effect")
	float Damage = 0.f;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Effect")
	float RangeMeters = 0.f;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Effect")
	float RadiusMeters = 0.f;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Effect")
	float DurationSeconds = 0.f;

	/** Velocidade de projetil. */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Effect")
	float SpeedMetersPerSecond = 0.f;

	/** Numero de projeteis/servos/raios. */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Effect")
	int32 Count = 0;

	/** Alvos maximos (saltos de cadeia, perfuracao). */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Effect")
	int32 MaxTargets = 0;

	/** Reducao de dano por salto/perfuracao. 0.15 = -15%. */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Effect")
	float FalloffPerJump = 0.f;

	/** Intervalo de tick (canalizadas, auras). */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Effect")
	float TickIntervalSeconds = 0.f;

	/** Fracao do dano convertida em cura (Drenar Vida = 0.5). */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Effect")
	float HealFraction = 0.f;

	/** Dano secundario (explosao final, teto em chefes...). Sentido em Notes. */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Effect")
	float SecondaryDamage = 0.f;

	/** Raio secundario (choques da Bola de Relampago, raio de cada estrela...). */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Effect")
	float SecondaryRadiusMeters = 0.f;

	/** Valor especifico da magia (fracao desviada, % da vida, impulso...). Sentido em Notes. */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Effect")
	float EffectValue = 0.f;

	/** Chance de aplicar o estado secundario (0..1). Em canalizadas: chance por segundo. */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Status")
	float ProcChance = 0.f;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Status")
	float ProcDurationSeconds = 0.f;

	/** Dano por segundo do estado (queimadura/sangramento). */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Status")
	float ProcDamagePerSecond = 0.f;

	/** Documentacao para designers (nao aparece no jogo). */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Spell")
	FString Notes;
};
