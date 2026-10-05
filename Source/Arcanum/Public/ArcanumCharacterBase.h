#pragma once

#include "CoreMinimal.h"
#include "AbilitySystemInterface.h"
#include "GameFramework/Character.h"
#include "GenericTeamAgentInterface.h"
#include "GameplayTagContainer.h"
#include "ArcanumCharacterBase.generated.h"

class UArcanumAbilitySystemComponent;
class UArcanumAttributeSet;

/** Times: hostilidade = times diferentes (servos do jogador usam Player). */
namespace ArcanumTeams
{
	inline constexpr uint8 Player = 1;
	inline constexpr uint8 Monsters = 2;
	inline constexpr uint8 Wildlife = 3;
}

/**
 * Base de jogador e criaturas: ponte com o GAS, time, morte e reacao a estados
 * (Paralisia zera a velocidade). O ASC pode viver no proprio ator (inimigos) ou no
 * PlayerState (jogador); as subclasses chamam InitAbilitySystem.
 */
UCLASS(Abstract)
class ARCANUM_API AArcanumCharacterBase : public ACharacter, public IAbilitySystemInterface, public IGenericTeamAgentInterface
{
	GENERATED_BODY()

public:
	AArcanumCharacterBase();

	//~ IAbilitySystemInterface
	virtual UAbilitySystemComponent* GetAbilitySystemComponent() const override;

	//~ IGenericTeamAgentInterface
	virtual FGenericTeamId GetGenericTeamId() const override { return FGenericTeamId(TeamId); }

	UFUNCTION(BlueprintPure, Category = "Arcanum")
	UArcanumAttributeSet* GetAttributeSet() const { return AttributeSet; }

	UFUNCTION(BlueprintPure, Category = "Arcanum")
	bool IsDead() const { return bIsDead; }

protected:
	/** Liga ASC/atributos a este avatar e assina eventos. Chamar no servidor e no cliente. */
	void InitAbilitySystem(UArcanumAbilitySystemComponent* InASC, UArcanumAttributeSet* InAttributes, AActor* OwnerActor);

	/** Servidor: vida chegou a 0. */
	virtual void HandleOutOfHealth(AActor* Killer, float DamageMagnitude);

	/** Cosmetico (todos): ragdoll, dissolver, som. Padrao: desliga colisao e movimento. */
	UFUNCTION(NetMulticast, Reliable)
	void MulticastOnDeath();

	virtual void OnParalyzedChanged(const FGameplayTag Tag, int32 NewCount);

	UPROPERTY(EditDefaultsOnly, Category = "Arcanum")
	uint8 TeamId = ArcanumTeams::Monsters;

	UPROPERTY(Transient)
	TObjectPtr<UArcanumAbilitySystemComponent> AbilitySystem;

	UPROPERTY(Transient)
	TObjectPtr<UArcanumAttributeSet> AttributeSet;

private:
	float DefaultMaxWalkSpeed = 0.f;
	bool bIsDead = false;
	FDelegateHandle OutOfHealthHandle;
};
