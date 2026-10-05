#include "Abilities/ArcanumAbility_Projectile.h"

#include "Abilities/ArcanumTargeting.h"
#include "Actors/ArcanumProjectile.h"
#include "Data/ArcanumSpellDefinition.h"
#include "Engine/World.h"
#include "GameFramework/Pawn.h"

void UArcanumAbility_Projectile::ActivateAbility(const FGameplayAbilitySpecHandle Handle,
	const FGameplayAbilityActorInfo* ActorInfo, const FGameplayAbilityActivationInfo ActivationInfo,
	const FGameplayEventData* TriggerEventData)
{
	if (!CommitAbility(Handle, ActorInfo, ActivationInfo))
	{
		EndAbility(Handle, ActorInfo, ActivationInfo, true, true);
		return;
	}

	// Cue de conjuracao (selo runico na gema, faiscas espiralando, pulso de luz).
	// TODO(Sonnet): tocar montage de conjuracao (PlayMontageAndWait) e disparar no AnimNotify.
	if (const UArcanumSpellDefinition* Def = GetSpellDefinition())
	{
		ExecuteCueAt(Def->GetCastCueTag(), GetMuzzleLocation());
	}

	if (K2_HasAuthority())
	{
		SpawnProjectiles();
	}

	EndAbility(Handle, ActorInfo, ActivationInfo, true, false);
}

void UArcanumAbility_Projectile::SpawnProjectiles()
{
	UWorld* World = GetWorld();
	APawn* InstigatorPawn = Cast<APawn>(GetAvatarActorFromActorInfo());
	const UArcanumSpellDefinition* Def = GetSpellDefinition();
	if (!World || !ProjectileClass || !Def)
	{
		return;
	}

	const FArcanumSpellRow& Row = GetBalance();
	const FArcanumSpellModifiers Mods = GetSpellModifiers();
	const int32 Count = FMath::Max(Row.Count + Mods.ExtraCount, 1);
	const float RangeCm = Row.RangeMeters * 100.f;

	FVector EyeLocation, AimDirection;
	GetAimViewpoint(EyeLocation, AimDirection);

	// Ponto mirado: o projetil sai do cajado mas converge para onde a camera aponta.
	FVector AimPoint;
	AActor* AimTarget = ArcanumTargeting::TraceAimTarget(World, InstigatorPawn, EyeLocation, AimDirection, RangeCm, 30.f, AimPoint);

	const FVector Muzzle = GetMuzzleLocation();
	const FVector BaseDirection = (AimPoint - Muzzle).GetSafeNormal();

	TArray<AActor*> HomingTargets;
	if (bHoming)
	{
		if (AimTarget)
		{
			HomingTargets.Add(AimTarget);
		}
		while (HomingTargets.Num() < Count)
		{
			AActor* Extra = ArcanumTargeting::FindNearestHostile(World, InstigatorPawn, AimPoint,
				HomingSearchRadiusMeters * 100.f, HomingTargets);
			if (!Extra)
			{
				break;
			}
			HomingTargets.Add(Extra);
		}
	}

	FArcanumProjectileParams Params;
	Params.SpeedCm = Row.SpeedMetersPerSecond * 100.f;
	Params.MaxRangeCm = RangeCm;
	Params.MaxHits = FMath::Max(Row.MaxTargets, 1);
	Params.ExplosionRadiusCm = Row.RadiusMeters * 100.f;
	Params.DamageSpec = MakeDamageSpec(Row.Damage);
	Params.ProcSpec = MakeProcSpec();
	Params.ProcStateTag = Def->ProcStateTag;
	Params.ProcChance = Row.ProcChance;
	Params.ImpactCueTag = Def->GetImpactCueTag();
	Params.SchoolTag = ArcanumSchool::ToTag(Row.School);

	for (int32 Index = 0; Index < Count; ++Index)
	{
		// Leque simetrico em torno da mira.
		const float Alpha = Count > 1 ? static_cast<float>(Index) / (Count - 1) - 0.5f : 0.f;
		const FVector Direction = BaseDirection.RotateAngleAxis(Alpha * SpreadDegrees, FVector::UpVector);
		const FTransform SpawnTransform(Direction.Rotation(), Muzzle);

		AArcanumProjectile* Projectile = World->SpawnActorDeferred<AArcanumProjectile>(ProjectileClass, SpawnTransform,
			GetOwningActorFromActorInfo(), InstigatorPawn, ESpawnActorCollisionHandlingMethod::AlwaysSpawn);
		if (!Projectile)
		{
			continue;
		}

		// Com menos alvos que projeteis, os extras repetem os alvos em rodizio.
		Params.HomingTarget = HomingTargets.Num() > 0 ? HomingTargets[Index % HomingTargets.Num()] : nullptr;
		Projectile->InitProjectile(Params);
		Projectile->FinishSpawning(SpawnTransform);
	}
}
