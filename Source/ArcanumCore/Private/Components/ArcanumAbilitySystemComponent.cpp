#include "Components/ArcanumAbilitySystemComponent.h"

#include "Attributes/ArcanumAttributeSet.h"
#include "Components/ArcanumSpellModifierSource.h"
#include "Engine/World.h"
#include "Math/ArcanumDamageMath.h"
#include "Settings/ArcanumCombatSettings.h"
#include "TimerManager.h"

UArcanumAbilitySystemComponent::UArcanumAbilitySystemComponent()
{
	SetIsReplicatedByDefault(true);
}

void UArcanumAbilitySystemComponent::InitAbilityActorInfo(AActor* InOwnerActor, AActor* InAvatarActor)
{
	Super::InitAbilityActorInfo(InOwnerActor, InAvatarActor);

	UWorld* World = GetWorld();
	if (World && IsOwnerActorAuthoritative() && !ManaRegenTimer.IsValid())
	{
		const float Interval = GetDefault<UArcanumCombatSettings>()->ManaRegenTickInterval;
		World->GetTimerManager().SetTimer(ManaRegenTimer, this, &UArcanumAbilitySystemComponent::TickManaRegen, Interval, true);
	}
}

void UArcanumAbilitySystemComponent::EndPlay(const EEndPlayReason::Type EndPlayReason)
{
	if (UWorld* World = GetWorld())
	{
		World->GetTimerManager().ClearTimer(ManaRegenTimer);
	}
	Super::EndPlay(EndPlayReason);
}

void UArcanumAbilitySystemComponent::NotifyCombatEvent()
{
	if (const UWorld* World = GetWorld())
	{
		LastCombatTime = World->GetTimeSeconds();
	}
}

bool UArcanumAbilitySystemComponent::IsManaRegenPaused() const
{
	const UWorld* World = GetWorld();
	if (!World)
	{
		return false;
	}
	const float Delay = GetDefault<UArcanumCombatSettings>()->ManaRegenCombatDelay;
	return !ArcanumDamageMath::CanRegenerateMana(World->GetTimeSeconds(), LastCombatTime, Delay);
}

void UArcanumAbilitySystemComponent::TickManaRegen()
{
	if (!GetSet<UArcanumAttributeSet>() || IsManaRegenPaused())
	{
		return;
	}

	bool bFound = false;
	const float Mana = GetGameplayAttributeValue(UArcanumAttributeSet::GetManaAttribute(), bFound);
	const float MaxMana = GetGameplayAttributeValue(UArcanumAttributeSet::GetMaxManaAttribute(), bFound);
	const float Regen = GetGameplayAttributeValue(UArcanumAttributeSet::GetManaRegenAttribute(), bFound);
	if (!bFound || Mana >= MaxMana || Regen <= 0.f)
	{
		return;
	}

	const float Interval = GetDefault<UArcanumCombatSettings>()->ManaRegenTickInterval;
	SetNumericAttributeBase(UArcanumAttributeSet::GetManaAttribute(), FMath::Min(Mana + Regen * Interval, MaxMana));
}

FArcanumSpellModifiers UArcanumAbilitySystemComponent::GatherSpellModifiers(const UArcanumSpellDefinition& Spell) const
{
	FArcanumSpellModifiers Result;

	auto Collect = [&Spell, &Result](const AActor* Actor)
	{
		if (!Actor)
		{
			return;
		}
		for (const UActorComponent* Component : Actor->GetComponents())
		{
			if (const IArcanumSpellModifierSource* Source = Cast<IArcanumSpellModifierSource>(Component))
			{
				Source->ModifySpell(Spell, Result);
			}
		}
	};

	const AActor* Owner = GetOwnerActor();
	const AActor* Avatar = GetAvatarActor_Direct();
	Collect(Owner);
	if (Avatar != Owner)
	{
		Collect(Avatar);
	}
	return Result;
}
