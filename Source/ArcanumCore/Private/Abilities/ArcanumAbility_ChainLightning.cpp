#include "Abilities/ArcanumAbility_ChainLightning.h"

#include "Abilities/ArcanumTargeting.h"
#include "Math/ArcanumDamageMath.h"

void UArcanumAbility_ChainLightning::OnChannelTick(float DeltaSeconds)
{
	const FArcanumSpellRow& Row = GetBalance();
	const FArcanumSpellModifiers Mods = GetSpellModifiers();
	AActor* Avatar = GetAvatarActorFromActorInfo();

	FVector EyeLocation, AimDirection, ImpactPoint;
	if (!GetAimViewpoint(EyeLocation, AimDirection))
	{
		return;
	}

	AActor* First = ArcanumTargeting::TraceAimTarget(GetWorld(), Avatar, EyeLocation, AimDirection,
		Row.RangeMeters * 100.f, AimRadiusCm, ImpactPoint);
	if (!First)
	{
		return;
	}

	TArray<AActor*> Targets;
	ArcanumTargeting::FindChainTargets(GetWorld(), Avatar, First, Row.MaxTargets + Mods.ExtraTargets,
		Row.RadiusMeters * 100.f, Targets);

	const float DamageThisTick = Row.Damage * DeltaSeconds;
	for (int32 Jump = 0; Jump < Targets.Num(); ++Jump)
	{
		ApplySpellDamage(Targets[Jump], ArcanumDamageMath::ChainDamageAtJump(DamageThisTick, Jump, Row.FalloffPerJump));
		TryApplyProc(Targets[Jump], DeltaSeconds);
	}
}
