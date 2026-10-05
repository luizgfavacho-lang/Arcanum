#pragma once

#include "CoreMinimal.h"
#include "Abilities/ArcanumGameplayAbility.h"
#include "ArcanumAbility_Projectile.generated.h"

class AArcanumProjectile;

/**
 * Base de magias de projetil: Bola de Fogo, Missil Arcano, Lanca de Magma, Bola de Relampago...
 * Numeros do CSV: Damage, SpeedMetersPerSecond, RangeMeters, Count, MaxTargets (perfuracao),
 * RadiusMeters (explosao), ProcChance/ProcDuration/ProcDamagePerSecond.
 * O BP filho (GA_<Magia>) so escolhe ProjectileClass e, se quiser, teleguiado/leque.
 */
UCLASS(Abstract)
class ARCANUMCORE_API UArcanumAbility_Projectile : public UArcanumGameplayAbility
{
	GENERATED_BODY()

public:
	virtual void ActivateAbility(const FGameplayAbilitySpecHandle Handle, const FGameplayAbilityActorInfo* ActorInfo,
		const FGameplayAbilityActivationInfo ActivationInfo, const FGameplayEventData* TriggerEventData) override;

protected:
	UPROPERTY(EditDefaultsOnly, Category = "Arcanum|Projectile")
	TSubclassOf<AArcanumProjectile> ProjectileClass;

	/** Projeteis buscam alvos (Missil Arcano). O primeiro vai no alvo da mira. */
	UPROPERTY(EditDefaultsOnly, Category = "Arcanum|Projectile")
	bool bHoming = false;

	/** Raio de busca de alvos extras para teleguiados. */
	UPROPERTY(EditDefaultsOnly, Category = "Arcanum|Projectile", meta = (EditCondition = "bHoming"))
	float HomingSearchRadiusMeters = 15.f;

	/** Abertura total do leque quando Count > 1. */
	UPROPERTY(EditDefaultsOnly, Category = "Arcanum|Projectile")
	float SpreadDegrees = 20.f;

private:
	void SpawnProjectiles();
};
