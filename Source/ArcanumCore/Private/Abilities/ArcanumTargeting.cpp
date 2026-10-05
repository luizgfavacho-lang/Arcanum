#include "Abilities/ArcanumTargeting.h"

#include "AbilitySystemComponent.h"
#include "AbilitySystemGlobals.h"
#include "ArcanumGameplayTags.h"
#include "CollisionQueryParams.h"
#include "Engine/OverlapResult.h"
#include "Engine/World.h"
#include "GenericTeamAgentInterface.h"

namespace ArcanumTargeting
{
	bool IsValidHostileTarget(const AActor* Source, const AActor* Target)
	{
		if (!Target || Target == Source || !IsValid(Target))
		{
			return false;
		}
		const UAbilitySystemComponent* ASC = UAbilitySystemGlobals::GetAbilitySystemComponentFromActor(Target);
		if (!ASC || ASC->HasMatchingGameplayTag(ArcanumTags::State_Dead))
		{
			return false;
		}
		return FGenericTeamId::GetAttitude(Source, Target) == ETeamAttitude::Hostile;
	}

	AActor* TraceAimTarget(const UWorld* World, const AActor* Source, const FVector& Start,
		const FVector& Direction, float RangeCm, float RadiusCm, FVector& OutImpactPoint)
	{
		const FVector End = Start + Direction.GetSafeNormal() * RangeCm;
		OutImpactPoint = End;
		if (!World)
		{
			return nullptr;
		}

		FCollisionQueryParams Params(SCENE_QUERY_STAT(ArcanumAimTrace), false, Source);
		TArray<FHitResult> Hits;
		World->SweepMultiByChannel(Hits, Start, End, FQuat::Identity, ECC_Visibility,
			FCollisionShape::MakeSphere(RadiusCm), Params);

		for (const FHitResult& Hit : Hits)
		{
			AActor* HitActor = Hit.GetActor();
			if (IsValidHostileTarget(Source, HitActor))
			{
				OutImpactPoint = Hit.ImpactPoint;
				return HitActor;
			}
			if (Hit.bBlockingHit)
			{
				OutImpactPoint = Hit.ImpactPoint;
				return nullptr;
			}
		}
		return nullptr;
	}

	AActor* FindNearestHostile(const UWorld* World, const AActor* Source, const FVector& Location,
		float RadiusCm, const TArray<AActor*>& Exclude)
	{
		if (!World || RadiusCm <= 0.f)
		{
			return nullptr;
		}

		FCollisionQueryParams Params(SCENE_QUERY_STAT(ArcanumNearestHostile), false, Source);
		TArray<FOverlapResult> Overlaps;
		World->OverlapMultiByObjectType(Overlaps, Location, FQuat::Identity,
			FCollisionObjectQueryParams(ECC_Pawn), FCollisionShape::MakeSphere(RadiusCm), Params);

		AActor* Best = nullptr;
		float BestDistSq = TNumericLimits<float>::Max();
		for (const FOverlapResult& Overlap : Overlaps)
		{
			AActor* Candidate = Overlap.GetActor();
			if (!Candidate || Exclude.Contains(Candidate) || !IsValidHostileTarget(Source, Candidate))
			{
				continue;
			}
			const float DistSq = FVector::DistSquared(Location, Candidate->GetActorLocation());
			if (DistSq < BestDistSq)
			{
				BestDistSq = DistSq;
				Best = Candidate;
			}
		}
		return Best;
	}

	void FindChainTargets(const UWorld* World, const AActor* Source, AActor* First, int32 MaxTargets,
		float JumpRadiusCm, TArray<AActor*>& OutTargets)
	{
		OutTargets.Reset();
		if (!First || MaxTargets <= 0)
		{
			return;
		}

		OutTargets.Add(First);
		while (OutTargets.Num() < MaxTargets)
		{
			AActor* Next = FindNearestHostile(World, Source, OutTargets.Last()->GetActorLocation(), JumpRadiusCm, OutTargets);
			if (!Next)
			{
				break;
			}
			OutTargets.Add(Next);
		}
	}

	void ApplySpecToActor(const FGameplayEffectSpecHandle& Spec, AActor* Target, const FGameplayTag& RefreshTag)
	{
		if (!Spec.IsValid() || !Target)
		{
			return;
		}
		UAbilitySystemComponent* TargetASC = UAbilitySystemGlobals::GetAbilitySystemComponentFromActor(Target);
		if (!TargetASC)
		{
			return;
		}
		if (RefreshTag.IsValid())
		{
			TargetASC->RemoveActiveEffectsWithGrantedTags(FGameplayTagContainer(RefreshTag));
		}
		TargetASC->ApplyGameplayEffectSpecToSelf(*Spec.Data.Get());
	}
}
