#pragma once

#include "CoreMinimal.h"
#include "Components/ActorComponent.h"
#include "GameplayAbilitySpec.h"
#include "ArcanumSpellbookComponent.generated.h"

class UAbilitySystemComponent;
class UArcanumSpellDefinition;

DECLARE_DYNAMIC_MULTICAST_DELEGATE(FArcanumSpellbookChanged);

/**
 * Grimorio: magias aprendidas e as 5 equipadas (barra de atalhos).
 * Vive no PlayerState. No servidor, cada slot equipado vira um FGameplayAbilitySpec com
 * InputID = indice do slot e SourceObject = definicao da magia.
 */
UCLASS(ClassGroup = (Arcanum), meta = (BlueprintSpawnableComponent))
class ARCANUMCORE_API UArcanumSpellbookComponent : public UActorComponent
{
	GENERATED_BODY()

public:
	static constexpr int32 NumSlots = 5;

	UArcanumSpellbookComponent();

	/** Servidor: liga ao ASC e concede as magias iniciais. Chamar apos InitAbilityActorInfo. */
	void InitializeWithAbilitySystem(UAbilitySystemComponent* InASC);

	/** Servidor: aprende (tomo, Grimorio, Mago Errante). */
	UFUNCTION(BlueprintCallable, BlueprintAuthorityOnly, Category = "Arcanum|Spellbook")
	void LearnSpell(UArcanumSpellDefinition* Spell);

	/** Cliente ou servidor: equipa uma magia aprendida no slot (0..4). */
	UFUNCTION(BlueprintCallable, Category = "Arcanum|Spellbook")
	void EquipSpell(UArcanumSpellDefinition* Spell, int32 Slot);

	UFUNCTION(BlueprintPure, Category = "Arcanum|Spellbook")
	UArcanumSpellDefinition* GetEquippedSpell(int32 Slot) const;

	UFUNCTION(BlueprintPure, Category = "Arcanum|Spellbook")
	TArray<UArcanumSpellDefinition*> GetLearnedSpells() const { return ObjectPtrDecay(LearnedSpells); }

	UFUNCTION(BlueprintPure, Category = "Arcanum|Spellbook")
	bool HasLearned(const UArcanumSpellDefinition* Spell) const { return LearnedSpells.Contains(Spell); }

	/** UI (Grimorio/HUD) escuta para redesenhar. */
	UPROPERTY(BlueprintAssignable, Category = "Arcanum|Spellbook")
	FArcanumSpellbookChanged OnSpellbookChanged;

	virtual void GetLifetimeReplicatedProps(TArray<FLifetimeProperty>& OutLifetimeProps) const override;

protected:
	/** Aprendidas e equipadas em ordem no inicio (fatia vertical: as 6 magias). */
	UPROPERTY(EditDefaultsOnly, Category = "Arcanum|Spellbook")
	TArray<TObjectPtr<UArcanumSpellDefinition>> StartingSpells;

	UPROPERTY(ReplicatedUsing = OnRep_Spellbook)
	TArray<TObjectPtr<UArcanumSpellDefinition>> LearnedSpells;

	UPROPERTY(ReplicatedUsing = OnRep_Spellbook)
	TArray<TObjectPtr<UArcanumSpellDefinition>> EquippedSlots;

	UFUNCTION()
	void OnRep_Spellbook();

	UFUNCTION(Server, Reliable)
	void ServerEquipSpell(UArcanumSpellDefinition* Spell, int32 Slot);

private:
	void EquipInternal(UArcanumSpellDefinition* Spell, int32 Slot);

	TWeakObjectPtr<UAbilitySystemComponent> AbilitySystem;
	FGameplayAbilitySpecHandle SlotHandles[NumSlots];
};
