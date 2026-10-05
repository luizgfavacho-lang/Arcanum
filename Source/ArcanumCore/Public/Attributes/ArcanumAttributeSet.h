#pragma once

#include "CoreMinimal.h"
#include "AttributeSet.h"
#include "AbilitySystemComponent.h"
#include "ArcanumAttributeSet.generated.h"

#define ARCANUM_ATTRIBUTE_ACCESSORS(ClassName, PropertyName) \
	GAMEPLAYATTRIBUTE_PROPERTY_GETTER(ClassName, PropertyName) \
	GAMEPLAYATTRIBUTE_VALUE_GETTER(PropertyName) \
	GAMEPLAYATTRIBUTE_VALUE_SETTER(PropertyName) \
	GAMEPLAYATTRIBUTE_VALUE_INITTER(PropertyName)

DECLARE_MULTICAST_DELEGATE_TwoParams(FArcanumOutOfHealthEvent, AActor* /*Instigator*/, float /*DamageMagnitude*/);

/**
 * Atributos de jogador e criaturas.
 * Escala de vida estilo do mod: jogador comeca com 20 de Vida (1 = meio coracao), por isso os
 * numeros de dano das magias (4-50) sao preservados sem conversao.
 * IncomingDamage/IncomingHeal sao meta-atributos (nao replicados): o dano passa por eles para
 * aplicar Escudo de Mana, morte e eventos num unico ponto.
 */
UCLASS()
class ARCANUMCORE_API UArcanumAttributeSet : public UAttributeSet
{
	GENERATED_BODY()

public:
	UArcanumAttributeSet();

	ARCANUM_ATTRIBUTE_ACCESSORS(UArcanumAttributeSet, Health);
	ARCANUM_ATTRIBUTE_ACCESSORS(UArcanumAttributeSet, MaxHealth);
	ARCANUM_ATTRIBUTE_ACCESSORS(UArcanumAttributeSet, Mana);
	ARCANUM_ATTRIBUTE_ACCESSORS(UArcanumAttributeSet, MaxMana);
	ARCANUM_ATTRIBUTE_ACCESSORS(UArcanumAttributeSet, ManaRegen);
	ARCANUM_ATTRIBUTE_ACCESSORS(UArcanumAttributeSet, SpellPower);
	ARCANUM_ATTRIBUTE_ACCESSORS(UArcanumAttributeSet, CastSpeed);
	ARCANUM_ATTRIBUTE_ACCESSORS(UArcanumAttributeSet, Armor);
	ARCANUM_ATTRIBUTE_ACCESSORS(UArcanumAttributeSet, AffinityElectricity);
	ARCANUM_ATTRIBUTE_ACCESSORS(UArcanumAttributeSet, AffinityFire);
	ARCANUM_ATTRIBUTE_ACCESSORS(UArcanumAttributeSet, AffinityEnergy);
	ARCANUM_ATTRIBUTE_ACCESSORS(UArcanumAttributeSet, AffinityNecromancy);
	ARCANUM_ATTRIBUTE_ACCESSORS(UArcanumAttributeSet, AffinityBlood);
	ARCANUM_ATTRIBUTE_ACCESSORS(UArcanumAttributeSet, IncomingDamage);
	ARCANUM_ATTRIBUTE_ACCESSORS(UArcanumAttributeSet, IncomingHeal);

	/** Disparado no servidor quando a vida chega a 0. */
	mutable FArcanumOutOfHealthEvent OnOutOfHealth;

	/** Chamado no respawn/renascimento (passiva Fenix) para reativar o evento de morte. */
	void ResetOutOfHealth() { bOutOfHealth = false; }

	virtual void GetLifetimeReplicatedProps(TArray<FLifetimeProperty>& OutLifetimeProps) const override;
	virtual void PreAttributeChange(const FGameplayAttribute& Attribute, float& NewValue) override;
	virtual void PostGameplayEffectExecute(const FGameplayEffectModCallbackData& Data) override;

protected:
	UPROPERTY(BlueprintReadOnly, ReplicatedUsing = OnRep_Health, Category = "Vital")
	FGameplayAttributeData Health;

	UPROPERTY(BlueprintReadOnly, ReplicatedUsing = OnRep_MaxHealth, Category = "Vital")
	FGameplayAttributeData MaxHealth;

	UPROPERTY(BlueprintReadOnly, ReplicatedUsing = OnRep_Mana, Category = "Vital")
	FGameplayAttributeData Mana;

	UPROPERTY(BlueprintReadOnly, ReplicatedUsing = OnRep_MaxMana, Category = "Vital")
	FGameplayAttributeData MaxMana;

	/** Mana por segundo. */
	UPROPERTY(BlueprintReadOnly, ReplicatedUsing = OnRep_ManaRegen, Category = "Vital")
	FGameplayAttributeData ManaRegen;

	/** +1% de dano magico por ponto (ver UArcanumCombatSettings). */
	UPROPERTY(BlueprintReadOnly, ReplicatedUsing = OnRep_SpellPower, Category = "Combat")
	FGameplayAttributeData SpellPower;

	/** Multiplicador de velocidade de conjuracao (1 = normal). Reduz recargas e tempos de cast. */
	UPROPERTY(BlueprintReadOnly, ReplicatedUsing = OnRep_CastSpeed, Category = "Combat")
	FGameplayAttributeData CastSpeed;

	UPROPERTY(BlueprintReadOnly, ReplicatedUsing = OnRep_Armor, Category = "Combat")
	FGameplayAttributeData Armor;

	UPROPERTY(BlueprintReadOnly, ReplicatedUsing = OnRep_AffinityElectricity, Category = "Affinity")
	FGameplayAttributeData AffinityElectricity;

	UPROPERTY(BlueprintReadOnly, ReplicatedUsing = OnRep_AffinityFire, Category = "Affinity")
	FGameplayAttributeData AffinityFire;

	UPROPERTY(BlueprintReadOnly, ReplicatedUsing = OnRep_AffinityEnergy, Category = "Affinity")
	FGameplayAttributeData AffinityEnergy;

	UPROPERTY(BlueprintReadOnly, ReplicatedUsing = OnRep_AffinityNecromancy, Category = "Affinity")
	FGameplayAttributeData AffinityNecromancy;

	UPROPERTY(BlueprintReadOnly, ReplicatedUsing = OnRep_AffinityBlood, Category = "Affinity")
	FGameplayAttributeData AffinityBlood;

	UPROPERTY(BlueprintReadOnly, Category = "Meta")
	FGameplayAttributeData IncomingDamage;

	UPROPERTY(BlueprintReadOnly, Category = "Meta")
	FGameplayAttributeData IncomingHeal;

	UFUNCTION() void OnRep_Health(const FGameplayAttributeData& Old);
	UFUNCTION() void OnRep_MaxHealth(const FGameplayAttributeData& Old);
	UFUNCTION() void OnRep_Mana(const FGameplayAttributeData& Old);
	UFUNCTION() void OnRep_MaxMana(const FGameplayAttributeData& Old);
	UFUNCTION() void OnRep_ManaRegen(const FGameplayAttributeData& Old);
	UFUNCTION() void OnRep_SpellPower(const FGameplayAttributeData& Old);
	UFUNCTION() void OnRep_CastSpeed(const FGameplayAttributeData& Old);
	UFUNCTION() void OnRep_Armor(const FGameplayAttributeData& Old);
	UFUNCTION() void OnRep_AffinityElectricity(const FGameplayAttributeData& Old);
	UFUNCTION() void OnRep_AffinityFire(const FGameplayAttributeData& Old);
	UFUNCTION() void OnRep_AffinityEnergy(const FGameplayAttributeData& Old);
	UFUNCTION() void OnRep_AffinityNecromancy(const FGameplayAttributeData& Old);
	UFUNCTION() void OnRep_AffinityBlood(const FGameplayAttributeData& Old);

private:
	void HandleIncomingDamage(const FGameplayEffectModCallbackData& Data);
	void HandleIncomingHeal();

	bool bOutOfHealth = false;
};
