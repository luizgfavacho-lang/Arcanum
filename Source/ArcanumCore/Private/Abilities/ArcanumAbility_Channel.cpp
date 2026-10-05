#include "Abilities/ArcanumAbility_Channel.h"

#include "AbilitySystemComponent.h"
#include "Abilities/Tasks/AbilityTask_WaitInputRelease.h"
#include "ArcanumGameplayTags.h"
#include "Attributes/ArcanumAttributeSet.h"
#include "Data/ArcanumSpellDefinition.h"
#include "Effects/ArcanumCostEffect.h"
#include "Engine/World.h"
#include "TimerManager.h"

UArcanumAbility_Channel::UArcanumAbility_Channel()
{
	bApplyGlobalCooldown = false;
	ActivationOwnedTags.AddTag(ArcanumTags::State_Channeling);
}

void UArcanumAbility_Channel::ActivateAbility(const FGameplayAbilitySpecHandle Handle,
	const FGameplayAbilityActorInfo* ActorInfo, const FGameplayAbilityActivationInfo ActivationInfo,
	const FGameplayEventData* TriggerEventData)
{
	// Commit paga o custo inicial (ManaCost) e nao aplica recarga (Cooldown = 0 no CSV).
	if (!CommitAbility(Handle, ActorInfo, ActivationInfo))
	{
		EndAbility(Handle, ActorInfo, ActivationInfo, true, true);
		return;
	}

	const FArcanumSpellRow& Row = GetBalance();
	TickInterval = Row.TickIntervalSeconds > 0.f ? Row.TickIntervalSeconds : 0.1f;

	// Cue em loop, previsto localmente e removido no EndAbility.
	if (const UArcanumSpellDefinition* Def = GetSpellDefinition(); Def && Def->GetCastCueTag().IsValid())
	{
		FGameplayCueParameters CueParams;
		CueParams.Instigator = GetAvatarActorFromActorInfo();
		CueParams.AggregatedSourceTags.AddTag(ArcanumSchool::ToTag(Row.School));
		K2_AddGameplayCueWithParams(Def->GetCastCueTag(), CueParams, true);
	}

	UAbilityTask_WaitInputRelease* WaitRelease = UAbilityTask_WaitInputRelease::WaitInputRelease(this, true);
	WaitRelease->OnRelease.AddDynamic(this, &UArcanumAbility_Channel::HandleInputReleased);
	WaitRelease->ReadyForActivation();

	if (UWorld* World = GetWorld())
	{
		World->GetTimerManager().SetTimer(TickTimer, this, &UArcanumAbility_Channel::TickChannel, TickInterval, true, 0.f);
	}
}

void UArcanumAbility_Channel::EndAbility(const FGameplayAbilitySpecHandle Handle, const FGameplayAbilityActorInfo* ActorInfo,
	const FGameplayAbilityActivationInfo ActivationInfo, bool bReplicateEndAbility, bool bWasCancelled)
{
	if (UWorld* World = GetWorld())
	{
		World->GetTimerManager().ClearTimer(TickTimer);
	}
	Super::EndAbility(Handle, ActorInfo, ActivationInfo, bReplicateEndAbility, bWasCancelled);
}

void UArcanumAbility_Channel::HandleInputReleased(float TimeHeld)
{
	K2_EndAbility();
}

void UArcanumAbility_Channel::TickChannel()
{
	const UAbilitySystemComponent* ASC = GetAbilitySystemComponentFromActorInfo();
	if (!ASC || ASC->HasMatchingGameplayTag(ArcanumTags::State_Paralyzed) || ASC->HasMatchingGameplayTag(ArcanumTags::State_Dead))
	{
		K2_EndAbility();
		return;
	}

	if (!K2_HasAuthority())
	{
		return;
	}

	if (!PayChannelCost(TickInterval))
	{
		K2_EndAbility();
		return;
	}

	OnChannelTick(TickInterval);
}

bool UArcanumAbility_Channel::PayChannelCost(float DeltaSeconds)
{
	const float Drain = GetBalance().ManaPerSecond * DeltaSeconds * FMath::Max(GetSpellModifiers().CostMultiplier, 0.f);
	if (Drain <= 0.f)
	{
		return true;
	}

	const UAbilitySystemComponent* ASC = GetAbilitySystemComponentFromActorInfo();
	bool bFound = false;
	const float Mana = ASC ? ASC->GetGameplayAttributeValue(UArcanumAttributeSet::GetManaAttribute(), bFound) : 0.f;
	if (Mana < Drain)
	{
		return false;
	}

	FGameplayEffectSpecHandle Spec = MakeOutgoingGameplayEffectSpec(UArcanumCostEffect::StaticClass(), GetAbilityLevel());
	if (Spec.IsValid())
	{
		Spec.Data->SetSetByCallerMagnitude(ArcanumTags::Data_ManaCost, -Drain);
		Spec.Data->SetSetByCallerMagnitude(ArcanumTags::Data_HealthCost, 0.f);
		K2_ApplyGameplayEffectSpecToOwner(Spec);
	}
	return true;
}
