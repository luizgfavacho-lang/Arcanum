#pragma once

#include "CoreMinimal.h"
#include "ArcanumSpellModifiers.generated.h"

/**
 * Modificadores agregados de runas, talentos, passivas e artefatos para UMA conjuracao.
 * Multiplicadores combinam por produto; bonus inteiros por soma.
 */
USTRUCT(BlueprintType)
struct ARCANUMCORE_API FArcanumSpellModifiers
{
	GENERATED_BODY()

	UPROPERTY(BlueprintReadWrite, Category = "Spell")
	float DamageMultiplier = 1.f;

	UPROPERTY(BlueprintReadWrite, Category = "Spell")
	float CostMultiplier = 1.f;

	UPROPERTY(BlueprintReadWrite, Category = "Spell")
	float CooldownMultiplier = 1.f;

	/** Saltos/alvos extras (Condutor, Cadeia Bifurcada). */
	UPROPERTY(BlueprintReadWrite, Category = "Spell")
	int32 ExtraTargets = 0;

	/** Projeteis/servos extras (Barragem de Misseis, Legiao de Ossos). */
	UPROPERTY(BlueprintReadWrite, Category = "Spell")
	int32 ExtraCount = 0;
};
