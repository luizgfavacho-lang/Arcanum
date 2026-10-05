#pragma once

#include "CoreMinimal.h"
#include "Engine/EngineTypes.h"
#include "GameplayEffectTypes.h"

/** Canal de colisao dos projeteis (Config/DefaultEngine.ini: GameTraceChannel1 = "Projectile"). */
#define ECC_ArcanumProjectile ECC_GameTraceChannel1

/**
 * Consultas de alvo compartilhadas por abilities, projeteis e cues cosmeticos.
 * As funcoes de busca sao deterministicas dado o mesmo estado de mundo, entao o cue de
 * Corrente em Cadeia pode recalcular os saltos localmente sem replicar a lista de alvos.
 */
namespace ArcanumTargeting
{
	/** Tem ASC, nao esta morto, nao e o proprio conjurador e e hostil (IGenericTeamAgentInterface). */
	ARCANUMCORE_API bool IsValidHostileTarget(const AActor* Source, const AActor* Target);

	/** Sphere trace ao longo da mira; devolve o primeiro alvo hostil (ou nullptr) e o ponto de impacto. */
	ARCANUMCORE_API AActor* TraceAimTarget(const UWorld* World, const AActor* Source, const FVector& Start,
		const FVector& Direction, float RangeCm, float RadiusCm, FVector& OutImpactPoint);

	/** Hostil mais proximo de Location dentro de RadiusCm, ignorando Exclude. */
	ARCANUMCORE_API AActor* FindNearestHostile(const UWorld* World, const AActor* Source, const FVector& Location,
		float RadiusCm, const TArray<AActor*>& Exclude);

	/** Cadeia a partir de First: cada salto vai ao hostil mais proximo do anterior (sem repetir). */
	ARCANUMCORE_API void FindChainTargets(const UWorld* World, const AActor* Source, AActor* First, int32 MaxTargets,
		float JumpRadiusCm, TArray<AActor*>& OutTargets);

	/** Aplica um spec no ASC do alvo. Se RefreshTag for valida, remove antes os efeitos que a concedem. */
	ARCANUMCORE_API void ApplySpecToActor(const FGameplayEffectSpecHandle& Spec, AActor* Target,
		const FGameplayTag& RefreshTag = FGameplayTag());
}
