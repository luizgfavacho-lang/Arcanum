#include "Abilities/ArcanumGameplayAbility.h"

#include "AbilitySystemComponent.h"
#include "AbilitySystemGlobals.h"
#include "Abilities/ArcanumTargeting.h"
#include "ArcanumGameplayTags.h"
#include "Attributes/ArcanumAttributeSet.h"
#include "Components/ArcanumAbilitySystemComponent.h"
#include "Components/SkeletalMeshComponent.h"
#include "Data/ArcanumSpellDefinition.h"
#include "Effects/ArcanumCooldownEffect.h"
#include "Effects/ArcanumCostEffect.h"
#include "Effects/ArcanumDamageEffect.h"
#include "Effects/ArcanumDotEffect.h"
#include "Effects/ArcanumHealEffect.h"
#include "Effects/ArcanumStatusEffect.h"
#include "GameFramework/Character.h"
#include "GameFramework/Pawn.h"
#include "Misc/EngineVersionComparison.h"
#include "Settings/ArcanumCombatSettings.h"

UArcanumGameplayAbility::UArcanumGameplayAbility()
{
	InstancingPolicy = EGameplayAbilityInstancingPolicy::InstancedPerActor;
	NetExecutionPolicy = EGameplayAbilityNetExecutionPolicy::LocalPredicted;

#if UE_VERSION_OLDER_THAN(5, 5, 0)
	AbilityTags.AddTag(ArcanumTags::Ability_Spell);
#else
	SetAssetTags(FGameplayTagContainer(ArcanumTags::Ability_Spell));
#endif

	ActivationBlockedTags.AddTag(ArcanumTags::State_Paralyzed);
	ActivationBlockedTags.AddTag(ArcanumTags::State_Dead);
	ActivationBlockedTags.AddTag(ArcanumTags::Cooldown_Global);
}

void UArcanumGameplayAbility::OnGiveAbility(const FGameplayAbilityActorInfo* ActorInfo, const FGameplayAbilitySpec& Spec)
{
	Super::OnGiveAbility(ActorInfo, Spec);
	Definition = Cast<UArcanumSpellDefinition>(Spec.SourceObject.Get());
	ensureMsgf(Definition, TEXT("%s concedida sem UArcanumSpellDefinition como SourceObject"), *GetName());
}

const FArcanumSpellRow& UArcanumGameplayAbility::GetBalance() const
{
	static const FArcanumSpellRow Empty;
	const FArcanumSpellRow* Row = Definition ? Definition->GetBalance() : nullptr;
	return Row ? *Row : Empty;
}

FArcanumSpellModifiers UArcanumGameplayAbility::GetSpellModifiers() const
{
	const UArcanumAbilitySystemComponent* ASC = Cast<UArcanumAbilitySystemComponent>(GetAbilitySystemComponentFromActorInfo());
	return (ASC && Definition) ? ASC->GatherSpellModifiers(*Definition) : FArcanumSpellModifiers();
}

FArcanumSpellCost UArcanumGameplayAbility::ComputeCost(const FGameplayAbilityActorInfo* ActorInfo) const
{
	FArcanumSpellCost Cost;
	const UAbilitySystemComponent* ASC = ActorInfo ? ActorInfo->AbilitySystemComponent.Get() : nullptr;
	if (!ASC || !Definition)
	{
		return Cost;
	}

	const FArcanumSpellRow& Row = GetBalance();
	const float CostMult = FMath::Max(GetSpellModifiers().CostMultiplier, 0.f);
	bool bFound = false;
	const float MaxHealth = ASC->GetGameplayAttributeValue(UArcanumAttributeSet::GetMaxHealthAttribute(), bFound);

	Cost.Mana = Row.ManaCost * CostMult;
	Cost.Health = Row.HealthCostPct * MaxHealth * CostMult;
	return Cost;
}

bool UArcanumGameplayAbility::CheckCost(const FGameplayAbilitySpecHandle Handle, const FGameplayAbilityActorInfo* ActorInfo,
	FGameplayTagContainer* OptionalRelevantTags) const
{
	if (!Super::CheckCost(Handle, ActorInfo, OptionalRelevantTags))
	{
		return false;
	}

	const UAbilitySystemComponent* ASC = ActorInfo ? ActorInfo->AbilitySystemComponent.Get() : nullptr;
	if (!ASC)
	{
		return false;
	}

	const FArcanumSpellCost Cost = ComputeCost(ActorInfo);
	bool bFound = false;
	const float Mana = ASC->GetGameplayAttributeValue(UArcanumAttributeSet::GetManaAttribute(), bFound);
	const float Health = ASC->GetGameplayAttributeValue(UArcanumAttributeSet::GetHealthAttribute(), bFound);

	// Custo de vida nunca mata: exige sobrar pelo menos 1 ponto.
	return Mana >= Cost.Mana && (Cost.Health <= 0.f || Health > Cost.Health + 1.f);
}

void UArcanumGameplayAbility::ApplyCost(const FGameplayAbilitySpecHandle Handle, const FGameplayAbilityActorInfo* ActorInfo,
	const FGameplayAbilityActivationInfo ActivationInfo) const
{
	const FArcanumSpellCost Cost = ComputeCost(ActorInfo);
	if (Cost.Mana <= 0.f && Cost.Health <= 0.f)
	{
		return;
	}

	FGameplayEffectSpecHandle Spec = MakeOutgoingGameplayEffectSpec(Handle, ActorInfo, ActivationInfo,
		UArcanumCostEffect::StaticClass(), GetAbilityLevel(Handle, ActorInfo));
	if (Spec.IsValid())
	{
		Spec.Data->SetSetByCallerMagnitude(ArcanumTags::Data_ManaCost, -Cost.Mana);
		Spec.Data->SetSetByCallerMagnitude(ArcanumTags::Data_HealthCost, -Cost.Health);
		ApplyGameplayEffectSpecToOwner(Handle, ActorInfo, ActivationInfo, Spec);
	}
}

const FGameplayTagContainer* UArcanumGameplayAbility::GetCooldownTags() const
{
	FGameplayTagContainer* MutableTags = const_cast<FGameplayTagContainer*>(&TempCooldownTags);
	MutableTags->Reset();
	if (const FGameplayTagContainer* ParentTags = Super::GetCooldownTags())
	{
		MutableTags->AppendTags(*ParentTags);
	}
	if (Definition && Definition->GetCooldownTag().IsValid())
	{
		MutableTags->AddTag(Definition->GetCooldownTag());
	}
	return MutableTags;
}

void UArcanumGameplayAbility::ApplyCooldown(const FGameplayAbilitySpecHandle Handle, const FGameplayAbilityActorInfo* ActorInfo,
	const FGameplayAbilityActivationInfo ActivationInfo) const
{
	const UAbilitySystemComponent* ASC = ActorInfo ? ActorInfo->AbilitySystemComponent.Get() : nullptr;
	if (!ASC || !Definition)
	{
		return;
	}

	bool bFound = false;
	const float CastSpeed = FMath::Max(ASC->GetGameplayAttributeValue(UArcanumAttributeSet::GetCastSpeedAttribute(), bFound), 0.1f);
	const float Level = GetAbilityLevel(Handle, ActorInfo);

	auto ApplyTaggedCooldown = [&](const FGameplayTag& Tag, float Duration)
	{
		if (!Tag.IsValid() || Duration <= 0.f)
		{
			return;
		}
		FGameplayEffectSpecHandle Spec = MakeOutgoingGameplayEffectSpec(Handle, ActorInfo, ActivationInfo,
			UArcanumCooldownEffect::StaticClass(), Level);
		if (Spec.IsValid())
		{
			Spec.Data->DynamicGrantedTags.AddTag(Tag);
			Spec.Data->SetSetByCallerMagnitude(ArcanumTags::Data_Cooldown, Duration);
			ApplyGameplayEffectSpecToOwner(Handle, ActorInfo, ActivationInfo, Spec);
		}
	};

	const float SpellCooldown = GetBalance().Cooldown * GetSpellModifiers().CooldownMultiplier / CastSpeed;
	ApplyTaggedCooldown(Definition->GetCooldownTag(), SpellCooldown);

	if (bApplyGlobalCooldown)
	{
		ApplyTaggedCooldown(ArcanumTags::Cooldown_Global, GetDefault<UArcanumCombatSettings>()->GlobalCooldown / CastSpeed);
	}
}

FGameplayEffectSpecHandle UArcanumGameplayAbility::MakeDamageSpec(float BaseDamage, float ExtraMultiplier) const
{
	FGameplayEffectSpecHandle Spec = MakeOutgoingGameplayEffectSpec(UArcanumDamageEffect::StaticClass(), GetAbilityLevel());
	if (Spec.IsValid())
	{
		Spec.Data->SetSetByCallerMagnitude(ArcanumTags::Data_Damage, BaseDamage);
		Spec.Data->SetSetByCallerMagnitude(ArcanumTags::Data_DamageMultiplier, GetSpellModifiers().DamageMultiplier * ExtraMultiplier);
		Spec.Data->AddDynamicAssetTag(ArcanumSchool::ToTag(GetBalance().School));
	}
	return Spec;
}

FGameplayEffectSpecHandle UArcanumGameplayAbility::MakeProcSpec() const
{
	if (!Definition || !Definition->ProcStateTag.IsValid())
	{
		return FGameplayEffectSpecHandle();
	}

	const FArcanumSpellRow& Row = GetBalance();
	const FGameplayTag& State = Definition->ProcStateTag;
	const bool bIsDot = State.MatchesTagExact(ArcanumTags::State_Burning) || State.MatchesTagExact(ArcanumTags::State_Bleeding);

	const TSubclassOf<UGameplayEffect> EffectClass = bIsDot
		? TSubclassOf<UGameplayEffect>(UArcanumDotEffect::StaticClass())
		: TSubclassOf<UGameplayEffect>(UArcanumStatusEffect::StaticClass());

	FGameplayEffectSpecHandle Spec = MakeOutgoingGameplayEffectSpec(EffectClass, GetAbilityLevel());
	if (Spec.IsValid())
	{
		Spec.Data->DynamicGrantedTags.AddTag(State);
		Spec.Data->SetSetByCallerMagnitude(ArcanumTags::Data_Duration, Row.ProcDurationSeconds);
		if (bIsDot)
		{
			// UArcanumDotEffect tem periodo de 0,5 s.
			Spec.Data->SetSetByCallerMagnitude(ArcanumTags::Data_Damage, Row.ProcDamagePerSecond * 0.5f);
			Spec.Data->SetSetByCallerMagnitude(ArcanumTags::Data_DamageMultiplier, GetSpellModifiers().DamageMultiplier);
			Spec.Data->AddDynamicAssetTag(ArcanumSchool::ToTag(Row.School));
		}
	}
	return Spec;
}

void UArcanumGameplayAbility::ApplySpellDamage(AActor* Target, float BaseDamage, float ExtraMultiplier) const
{
	if (!K2_HasAuthority())
	{
		return;
	}
	ArcanumTargeting::ApplySpecToActor(MakeDamageSpec(BaseDamage, ExtraMultiplier), Target);
}

void UArcanumGameplayAbility::TryApplyProc(AActor* Target, float ExposureSeconds) const
{
	if (!K2_HasAuthority() || !Definition)
	{
		return;
	}
	const float Chance = ExposureSeconds > 0.f
		? 1.f - FMath::Pow(1.f - FMath::Clamp(GetBalance().ProcChance, 0.f, 1.f), ExposureSeconds)
		: GetBalance().ProcChance;
	if (FMath::FRand() < Chance)
	{
		ArcanumTargeting::ApplySpecToActor(MakeProcSpec(), Target, Definition->ProcStateTag);
	}
}

void UArcanumGameplayAbility::HealOwner(float Amount)
{
	if (Amount <= 0.f || !K2_HasAuthority())
	{
		return;
	}
	FGameplayEffectSpecHandle Spec = MakeOutgoingGameplayEffectSpec(UArcanumHealEffect::StaticClass(), GetAbilityLevel());
	if (Spec.IsValid())
	{
		Spec.Data->SetSetByCallerMagnitude(ArcanumTags::Data_Heal, Amount);
		K2_ApplyGameplayEffectSpecToOwner(Spec);
	}
}

bool UArcanumGameplayAbility::GetAimViewpoint(FVector& OutLocation, FVector& OutDirection) const
{
	const AActor* Avatar = GetAvatarActorFromActorInfo();
	if (!Avatar)
	{
		return false;
	}

	if (const APawn* Pawn = Cast<APawn>(Avatar))
	{
		FRotator EyeRotation;
		Pawn->GetActorEyesViewPoint(OutLocation, EyeRotation);
		OutDirection = EyeRotation.Vector();
	}
	else
	{
		OutLocation = Avatar->GetActorLocation();
		OutDirection = Avatar->GetActorForwardVector();
	}
	return true;
}

FVector UArcanumGameplayAbility::GetMuzzleLocation() const
{
	static const FName MuzzleSocket(TEXT("Muzzle"));

	const AActor* Avatar = GetAvatarActorFromActorInfo();
	if (const ACharacter* Character = Cast<ACharacter>(Avatar))
	{
		const USkeletalMeshComponent* Mesh = Character->GetMesh();
		if (Mesh && Mesh->DoesSocketExist(MuzzleSocket))
		{
			return Mesh->GetSocketLocation(MuzzleSocket);
		}
	}
	return Avatar
		? Avatar->GetActorLocation() + Avatar->GetActorForwardVector() * 80.f + FVector(0.f, 0.f, 40.f)
		: FVector::ZeroVector;
}

void UArcanumGameplayAbility::ExecuteCueAt(const FGameplayTag& CueTag, const FVector& Location, AActor* Target) const
{
	UAbilitySystemComponent* ASC = GetAbilitySystemComponentFromActorInfo();
	if (!ASC || !CueTag.IsValid())
	{
		return;
	}

	FGameplayCueParameters Params;
	Params.Location = Location;
	Params.Instigator = GetAvatarActorFromActorInfo();
	Params.EffectCauser = Target;
	// Cues de escola leem a tag School.* para escolher cor/particula (assinatura automatica).
	Params.AggregatedSourceTags.AddTag(ArcanumSchool::ToTag(GetBalance().School));
	ASC->ExecuteGameplayCue(CueTag, Params);
}
