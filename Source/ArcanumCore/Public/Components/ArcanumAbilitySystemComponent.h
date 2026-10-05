#pragma once

#include "CoreMinimal.h"
#include "AbilitySystemComponent.h"
#include "Data/ArcanumSpellModifiers.h"
#include "ArcanumAbilitySystemComponent.generated.h"

class UArcanumSpellDefinition;

/**
 * ASC do projeto. Acrescenta:
 * - regeneracao de mana no servidor, pausada apos eventos de combate;
 * - agregacao de modificadores de magia (runas, talentos, passivas).
 */
UCLASS(ClassGroup = (Arcanum), meta = (BlueprintSpawnableComponent))
class ARCANUMCORE_API UArcanumAbilitySystemComponent : public UAbilitySystemComponent
{
	GENERATED_BODY()

public:
	UArcanumAbilitySystemComponent();

	virtual void InitAbilityActorInfo(AActor* InOwnerActor, AActor* InAvatarActor) override;
	virtual void EndPlay(const EEndPlayReason::Type EndPlayReason) override;

	/** Causou ou recebeu dano: reinicia o atraso da regeneracao de mana. */
	void NotifyCombatEvent();

	UFUNCTION(BlueprintPure, Category = "Arcanum|Mana")
	bool IsManaRegenPaused() const;

	/** Soma todos os IArcanumSpellModifierSource do dono e do avatar. */
	FArcanumSpellModifiers GatherSpellModifiers(const UArcanumSpellDefinition& Spell) const;

private:
	void TickManaRegen();

	FTimerHandle ManaRegenTimer;
	double LastCombatTime = -1000.0;
};
