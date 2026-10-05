#pragma once

#include "CoreMinimal.h"
#include "AbilitySystemInterface.h"
#include "GameFramework/PlayerState.h"
#include "ArcanumPlayerState.generated.h"

class UArcanumAbilitySystemComponent;
class UArcanumAttributeSet;
class UArcanumSpellbookComponent;

/**
 * Dono do ASC do jogador (sobrevive a morte/respawn do pawn) e do Grimorio.
 * Proximos componentes aqui: progressao (nivel/XP/afinidade), talentos, runas, passiva.
 */
UCLASS()
class ARCANUM_API AArcanumPlayerState : public APlayerState, public IAbilitySystemInterface
{
	GENERATED_BODY()

public:
	AArcanumPlayerState();

	virtual UAbilitySystemComponent* GetAbilitySystemComponent() const override;

	UArcanumAbilitySystemComponent* GetArcanumAbilitySystem() const { return AbilitySystem; }
	UArcanumAttributeSet* GetAttributeSet() const { return Attributes; }
	UArcanumSpellbookComponent* GetSpellbook() const { return Spellbook; }

protected:
	UPROPERTY(VisibleAnywhere, Category = "Arcanum")
	TObjectPtr<UArcanumAbilitySystemComponent> AbilitySystem;

	UPROPERTY()
	TObjectPtr<UArcanumAttributeSet> Attributes;

	UPROPERTY(VisibleAnywhere, Category = "Arcanum")
	TObjectPtr<UArcanumSpellbookComponent> Spellbook;
};
