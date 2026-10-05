#include "Attributes/ArcanumAttributeSet.h"

#include "ArcanumGameplayTags.h"
#include "Components/ArcanumAbilitySystemComponent.h"
#include "GameplayEffectExtension.h"
#include "Math/ArcanumDamageMath.h"
#include "Net/UnrealNetwork.h"
#include "Settings/ArcanumCombatSettings.h"

UArcanumAttributeSet::UArcanumAttributeSet()
{
	// Valores iniciais do jogador nivel 1. Inimigos sobrescrevem via Data/Enemies.csv.
	InitHealth(20.f);
	InitMaxHealth(20.f);
	InitMana(100.f);
	InitMaxMana(100.f);
	InitManaRegen(3.f);
	InitSpellPower(0.f);
	InitCastSpeed(1.f);
	InitArmor(0.f);
}

void UArcanumAttributeSet::GetLifetimeReplicatedProps(TArray<FLifetimeProperty>& OutLifetimeProps) const
{
	Super::GetLifetimeReplicatedProps(OutLifetimeProps);

	DOREPLIFETIME_CONDITION_NOTIFY(UArcanumAttributeSet, Health, COND_None, REPNOTIFY_Always);
	DOREPLIFETIME_CONDITION_NOTIFY(UArcanumAttributeSet, MaxHealth, COND_None, REPNOTIFY_Always);
	DOREPLIFETIME_CONDITION_NOTIFY(UArcanumAttributeSet, Mana, COND_None, REPNOTIFY_Always);
	DOREPLIFETIME_CONDITION_NOTIFY(UArcanumAttributeSet, MaxMana, COND_None, REPNOTIFY_Always);
	DOREPLIFETIME_CONDITION_NOTIFY(UArcanumAttributeSet, ManaRegen, COND_None, REPNOTIFY_Always);
	DOREPLIFETIME_CONDITION_NOTIFY(UArcanumAttributeSet, SpellPower, COND_None, REPNOTIFY_Always);
	DOREPLIFETIME_CONDITION_NOTIFY(UArcanumAttributeSet, CastSpeed, COND_None, REPNOTIFY_Always);
	DOREPLIFETIME_CONDITION_NOTIFY(UArcanumAttributeSet, Armor, COND_None, REPNOTIFY_Always);
	DOREPLIFETIME_CONDITION_NOTIFY(UArcanumAttributeSet, AffinityElectricity, COND_None, REPNOTIFY_Always);
	DOREPLIFETIME_CONDITION_NOTIFY(UArcanumAttributeSet, AffinityFire, COND_None, REPNOTIFY_Always);
	DOREPLIFETIME_CONDITION_NOTIFY(UArcanumAttributeSet, AffinityEnergy, COND_None, REPNOTIFY_Always);
	DOREPLIFETIME_CONDITION_NOTIFY(UArcanumAttributeSet, AffinityNecromancy, COND_None, REPNOTIFY_Always);
	DOREPLIFETIME_CONDITION_NOTIFY(UArcanumAttributeSet, AffinityBlood, COND_None, REPNOTIFY_Always);
}

void UArcanumAttributeSet::PreAttributeChange(const FGameplayAttribute& Attribute, float& NewValue)
{
	Super::PreAttributeChange(Attribute, NewValue);

	if (Attribute == GetHealthAttribute())
	{
		NewValue = FMath::Clamp(NewValue, 0.f, GetMaxHealth());
	}
	else if (Attribute == GetManaAttribute())
	{
		NewValue = FMath::Clamp(NewValue, 0.f, GetMaxMana());
	}
	else if (Attribute == GetMaxHealthAttribute() || Attribute == GetMaxManaAttribute())
	{
		NewValue = FMath::Max(NewValue, 1.f);
	}
	else if (Attribute == GetCastSpeedAttribute())
	{
		NewValue = FMath::Max(NewValue, 0.1f);
	}
	else if (Attribute == GetAffinityElectricityAttribute() || Attribute == GetAffinityFireAttribute()
		|| Attribute == GetAffinityEnergyAttribute() || Attribute == GetAffinityNecromancyAttribute()
		|| Attribute == GetAffinityBloodAttribute())
	{
		NewValue = FMath::Clamp(NewValue, 0.f, 10.f);
	}
}

void UArcanumAttributeSet::PostGameplayEffectExecute(const FGameplayEffectModCallbackData& Data)
{
	Super::PostGameplayEffectExecute(Data);

	if (Data.EvaluatedData.Attribute == GetIncomingDamageAttribute())
	{
		HandleIncomingDamage(Data);
	}
	else if (Data.EvaluatedData.Attribute == GetIncomingHealAttribute())
	{
		HandleIncomingHeal();
	}
	else if (Data.EvaluatedData.Attribute == GetHealthAttribute())
	{
		SetHealth(FMath::Clamp(GetHealth(), 0.f, GetMaxHealth()));
	}
	else if (Data.EvaluatedData.Attribute == GetManaAttribute())
	{
		SetMana(FMath::Clamp(GetMana(), 0.f, GetMaxMana()));
	}
}

void UArcanumAttributeSet::HandleIncomingDamage(const FGameplayEffectModCallbackData& Data)
{
	const float Damage = GetIncomingDamage();
	SetIncomingDamage(0.f);

	UAbilitySystemComponent& TargetASC = Data.Target;
	if (Damage <= 0.f || bOutOfHealth || TargetASC.HasMatchingGameplayTag(ArcanumTags::State_Dead))
	{
		return;
	}

	const UArcanumCombatSettings* Settings = GetDefault<UArcanumCombatSettings>();

	float HealthDamage = Damage;
	if (TargetASC.HasMatchingGameplayTag(ArcanumTags::State_ManaShield))
	{
		const FArcanumManaShieldResult Shield =
			ArcanumDamageMath::ResolveManaShield(Damage, GetMana(), Settings->ManaShieldManaPerDamage);
		SetMana(FMath::Max(GetMana() - Shield.ManaSpent, 0.f));
		HealthDamage = Shield.HealthDamage;
	}

	SetHealth(FMath::Clamp(GetHealth() - HealthDamage, 0.f, GetMaxHealth()));

	// Carga Arcana e consumida por golpes diretos (DoTs periodicos nao a consomem).
	const bool bPeriodic = Data.EffectSpec.GetPeriod() > 0.f;
	if (!bPeriodic && TargetASC.HasMatchingGameplayTag(ArcanumTags::State_ArcaneCharge))
	{
		TargetASC.RemoveActiveEffectsWithGrantedTags(FGameplayTagContainer(ArcanumTags::State_ArcaneCharge));
	}

	// Pausa a regeneracao de mana de quem recebeu e de quem causou o dano.
	UAbilitySystemComponent* SourceASC = Data.EffectSpec.GetContext().GetOriginalInstigatorAbilitySystemComponent();
	if (UArcanumAbilitySystemComponent* ArcanumTarget = Cast<UArcanumAbilitySystemComponent>(&TargetASC))
	{
		ArcanumTarget->NotifyCombatEvent();
	}
	if (UArcanumAbilitySystemComponent* ArcanumSource = Cast<UArcanumAbilitySystemComponent>(SourceASC))
	{
		ArcanumSource->NotifyCombatEvent();
	}

	if (GetHealth() <= 0.f && !bOutOfHealth)
	{
		bOutOfHealth = true;
		OnOutOfHealth.Broadcast(SourceASC ? SourceASC->GetAvatarActor() : nullptr, Damage);
	}
}

void UArcanumAttributeSet::HandleIncomingHeal()
{
	const float Heal = GetIncomingHeal();
	SetIncomingHeal(0.f);
	if (Heal > 0.f && !bOutOfHealth)
	{
		SetHealth(FMath::Clamp(GetHealth() + Heal, 0.f, GetMaxHealth()));
	}
}

void UArcanumAttributeSet::OnRep_Health(const FGameplayAttributeData& Old) { GAMEPLAYATTRIBUTE_REPNOTIFY(UArcanumAttributeSet, Health, Old); }
void UArcanumAttributeSet::OnRep_MaxHealth(const FGameplayAttributeData& Old) { GAMEPLAYATTRIBUTE_REPNOTIFY(UArcanumAttributeSet, MaxHealth, Old); }
void UArcanumAttributeSet::OnRep_Mana(const FGameplayAttributeData& Old) { GAMEPLAYATTRIBUTE_REPNOTIFY(UArcanumAttributeSet, Mana, Old); }
void UArcanumAttributeSet::OnRep_MaxMana(const FGameplayAttributeData& Old) { GAMEPLAYATTRIBUTE_REPNOTIFY(UArcanumAttributeSet, MaxMana, Old); }
void UArcanumAttributeSet::OnRep_ManaRegen(const FGameplayAttributeData& Old) { GAMEPLAYATTRIBUTE_REPNOTIFY(UArcanumAttributeSet, ManaRegen, Old); }
void UArcanumAttributeSet::OnRep_SpellPower(const FGameplayAttributeData& Old) { GAMEPLAYATTRIBUTE_REPNOTIFY(UArcanumAttributeSet, SpellPower, Old); }
void UArcanumAttributeSet::OnRep_CastSpeed(const FGameplayAttributeData& Old) { GAMEPLAYATTRIBUTE_REPNOTIFY(UArcanumAttributeSet, CastSpeed, Old); }
void UArcanumAttributeSet::OnRep_Armor(const FGameplayAttributeData& Old) { GAMEPLAYATTRIBUTE_REPNOTIFY(UArcanumAttributeSet, Armor, Old); }
void UArcanumAttributeSet::OnRep_AffinityElectricity(const FGameplayAttributeData& Old) { GAMEPLAYATTRIBUTE_REPNOTIFY(UArcanumAttributeSet, AffinityElectricity, Old); }
void UArcanumAttributeSet::OnRep_AffinityFire(const FGameplayAttributeData& Old) { GAMEPLAYATTRIBUTE_REPNOTIFY(UArcanumAttributeSet, AffinityFire, Old); }
void UArcanumAttributeSet::OnRep_AffinityEnergy(const FGameplayAttributeData& Old) { GAMEPLAYATTRIBUTE_REPNOTIFY(UArcanumAttributeSet, AffinityEnergy, Old); }
void UArcanumAttributeSet::OnRep_AffinityNecromancy(const FGameplayAttributeData& Old) { GAMEPLAYATTRIBUTE_REPNOTIFY(UArcanumAttributeSet, AffinityNecromancy, Old); }
void UArcanumAttributeSet::OnRep_AffinityBlood(const FGameplayAttributeData& Old) { GAMEPLAYATTRIBUTE_REPNOTIFY(UArcanumAttributeSet, AffinityBlood, Old); }
