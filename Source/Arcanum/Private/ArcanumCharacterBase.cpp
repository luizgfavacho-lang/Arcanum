#include "ArcanumCharacterBase.h"

#include "ArcanumGameplayTags.h"
#include "Attributes/ArcanumAttributeSet.h"
#include "Components/ArcanumAbilitySystemComponent.h"
#include "Components/CapsuleComponent.h"
#include "GameFramework/CharacterMovementComponent.h"

AArcanumCharacterBase::AArcanumCharacterBase()
{
	PrimaryActorTick.bCanEverTick = false;
}

UAbilitySystemComponent* AArcanumCharacterBase::GetAbilitySystemComponent() const
{
	return AbilitySystem;
}

void AArcanumCharacterBase::InitAbilitySystem(UArcanumAbilitySystemComponent* InASC, UArcanumAttributeSet* InAttributes, AActor* OwnerActor)
{
	if (!InASC)
	{
		return;
	}

	AbilitySystem = InASC;
	AttributeSet = InAttributes;
	InASC->InitAbilityActorInfo(OwnerActor, this);

	DefaultMaxWalkSpeed = GetCharacterMovement()->MaxWalkSpeed;
	InASC->RegisterGameplayTagEvent(ArcanumTags::State_Paralyzed, EGameplayTagEventType::NewOrRemoved)
		.AddUObject(this, &AArcanumCharacterBase::OnParalyzedChanged);

	if (HasAuthority() && InAttributes && !OutOfHealthHandle.IsValid())
	{
		OutOfHealthHandle = InAttributes->OnOutOfHealth.AddUObject(this, &AArcanumCharacterBase::HandleOutOfHealth);
	}
}

void AArcanumCharacterBase::OnParalyzedChanged(const FGameplayTag Tag, int32 NewCount)
{
	// Paralisia = velocidade 0 (roda em todos, a tag replica pelo ASC).
	GetCharacterMovement()->MaxWalkSpeed = NewCount > 0 ? 0.f : DefaultMaxWalkSpeed;
}

void AArcanumCharacterBase::HandleOutOfHealth(AActor* Killer, float DamageMagnitude)
{
	if (bIsDead)
	{
		return;
	}
	bIsDead = true;

	if (AbilitySystem)
	{
		AbilitySystem->CancelAllAbilities();
		AbilitySystem->AddLooseGameplayTag(ArcanumTags::State_Dead);
		AbilitySystem->AddReplicatedLooseGameplayTag(ArcanumTags::State_Dead);
	}

	MulticastOnDeath();
}

void AArcanumCharacterBase::MulticastOnDeath_Implementation()
{
	bIsDead = true;
	GetCapsuleComponent()->SetCollisionEnabled(ECollisionEnabled::NoCollision);
	GetCharacterMovement()->DisableMovement();
	// TODO(Sonnet): GameplayCue.Character.Death (dissolver pintado) e ragdoll.
}
