#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "GameplayEffectTypes.h"
#include "ArcanumProjectile.generated.h"

class USphereComponent;
class UProjectileMovementComponent;
class UPrimitiveComponent;

/** Parametros preenchidos pela ability no servidor antes do FinishSpawning. */
struct FArcanumProjectileParams
{
	float SpeedCm = 3000.f;
	float MaxRangeCm = 3000.f;
	/** Alvos atingidos antes de sumir (perfuracao). */
	int32 MaxHits = 1;
	/** Raio de explosao no fim/impacto (0 = sem area). */
	float ExplosionRadiusCm = 0.f;
	/** Teleguiado: alvo e "ima" de acerto. */
	TWeakObjectPtr<AActor> HomingTarget;
	float HomingAccelerationCm = 6000.f;
	float MagnetRadiusCm = 60.f;

	FGameplayEffectSpecHandle DamageSpec;
	FGameplayEffectSpecHandle ProcSpec;
	FGameplayTag ProcStateTag;
	float ProcChance = 0.f;

	FGameplayTag ImpactCueTag;
	FGameplayTag SchoolTag;
};

/**
 * Projetil autoritativo do servidor (fase 1). Replica movimento; visual (nucleo branco, halo,
 * rastro, cintilacoes) fica no Blueprint filho com Niagara. Predicao no cliente: ver Docs/02.
 */
UCLASS()
class ARCANUMCORE_API AArcanumProjectile : public AActor
{
	GENERATED_BODY()

public:
	AArcanumProjectile();

	void InitProjectile(const FArcanumProjectileParams& InParams);

	virtual void Tick(float DeltaSeconds) override;

	UFUNCTION(BlueprintPure, Category = "Arcanum|Projectile")
	FGameplayTag GetSchoolTag() const { return SchoolTag; }

protected:
	virtual void BeginPlay() override;

	UFUNCTION()
	void OnSphereOverlap(UPrimitiveComponent* OverlappedComponent, AActor* OtherActor, UPrimitiveComponent* OtherComp,
		int32 OtherBodyIndex, bool bFromSweep, const FHitResult& SweepResult);

	UFUNCTION()
	void OnSphereHit(UPrimitiveComponent* HitComponent, AActor* OtherActor, UPrimitiveComponent* OtherComp,
		FVector NormalImpulse, const FHitResult& Hit);

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Arcanum|Projectile")
	TObjectPtr<USphereComponent> Collision;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Arcanum|Projectile")
	TObjectPtr<UProjectileMovementComponent> Movement;

	/** Replicado para o BP escolher a cor/assinatura da escola nos clientes. */
	UPROPERTY(Replicated)
	FGameplayTag SchoolTag;

	virtual void GetLifetimeReplicatedProps(TArray<FLifetimeProperty>& OutLifetimeProps) const override;

private:
	void HitActor(AActor* Target, const FVector& ImpactPoint);
	void Explode(const FVector& Location);
	void FinishAt(const FVector& Location);
	void ApplyEffectsTo(AActor* Target);

	FArcanumProjectileParams Params;
	TArray<TWeakObjectPtr<AActor>> AlreadyHit;
	FVector SpawnLocation = FVector::ZeroVector;
	bool bFinished = false;
};
