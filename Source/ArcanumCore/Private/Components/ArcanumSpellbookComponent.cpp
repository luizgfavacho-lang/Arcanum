#include "Components/ArcanumSpellbookComponent.h"

#include "AbilitySystemComponent.h"
#include "Abilities/ArcanumGameplayAbility.h"
#include "Data/ArcanumSpellDefinition.h"
#include "GameFramework/Actor.h"
#include "Net/UnrealNetwork.h"

UArcanumSpellbookComponent::UArcanumSpellbookComponent()
{
	SetIsReplicatedByDefault(true);
	EquippedSlots.SetNum(NumSlots);
}

void UArcanumSpellbookComponent::GetLifetimeReplicatedProps(TArray<FLifetimeProperty>& OutLifetimeProps) const
{
	Super::GetLifetimeReplicatedProps(OutLifetimeProps);
	DOREPLIFETIME_CONDITION(UArcanumSpellbookComponent, LearnedSpells, COND_OwnerOnly);
	DOREPLIFETIME_CONDITION(UArcanumSpellbookComponent, EquippedSlots, COND_OwnerOnly);
}

void UArcanumSpellbookComponent::InitializeWithAbilitySystem(UAbilitySystemComponent* InASC)
{
	if (!InASC || !GetOwner() || !GetOwner()->HasAuthority() || AbilitySystem.Get() == InASC)
	{
		return;
	}
	AbilitySystem = InASC;

	for (int32 Index = 0; Index < StartingSpells.Num(); ++Index)
	{
		LearnSpell(StartingSpells[Index]);
		if (Index < NumSlots && !EquippedSlots[Index])
		{
			EquipInternal(StartingSpells[Index], Index);
		}
	}

	// Reconcede slots ja equipados (ex.: carregados do save antes do ASC existir).
	for (int32 Slot = 0; Slot < NumSlots; ++Slot)
	{
		if (EquippedSlots[Slot] && !SlotHandles[Slot].IsValid())
		{
			EquipInternal(EquippedSlots[Slot], Slot);
		}
	}
}

void UArcanumSpellbookComponent::LearnSpell(UArcanumSpellDefinition* Spell)
{
	if (Spell && GetOwner() && GetOwner()->HasAuthority() && !LearnedSpells.Contains(Spell))
	{
		LearnedSpells.Add(Spell);
		OnSpellbookChanged.Broadcast();
	}
}

void UArcanumSpellbookComponent::EquipSpell(UArcanumSpellDefinition* Spell, int32 Slot)
{
	if (!GetOwner())
	{
		return;
	}
	if (GetOwner()->HasAuthority())
	{
		EquipInternal(Spell, Slot);
	}
	else
	{
		ServerEquipSpell(Spell, Slot);
	}
}

void UArcanumSpellbookComponent::ServerEquipSpell_Implementation(UArcanumSpellDefinition* Spell, int32 Slot)
{
	EquipInternal(Spell, Slot);
}

void UArcanumSpellbookComponent::EquipInternal(UArcanumSpellDefinition* Spell, int32 Slot)
{
	if (Slot < 0 || Slot >= NumSlots || (Spell && !LearnedSpells.Contains(Spell)))
	{
		return;
	}

	// A mesma magia em dois slots: libera o slot antigo.
	if (Spell)
	{
		const int32 OldSlot = EquippedSlots.IndexOfByKey(Spell);
		if (OldSlot != INDEX_NONE && OldSlot != Slot)
		{
			EquipInternal(nullptr, OldSlot);
		}
	}

	UAbilitySystemComponent* ASC = AbilitySystem.Get();
	if (ASC && SlotHandles[Slot].IsValid())
	{
		ASC->ClearAbility(SlotHandles[Slot]);
		SlotHandles[Slot] = FGameplayAbilitySpecHandle();
	}

	EquippedSlots[Slot] = Spell;

	if (ASC && Spell && Spell->AbilityClass)
	{
		FGameplayAbilitySpec Spec(Spell->AbilityClass, 1, Slot, Spell);
		SlotHandles[Slot] = ASC->GiveAbility(Spec);
	}

	OnSpellbookChanged.Broadcast();
}

UArcanumSpellDefinition* UArcanumSpellbookComponent::GetEquippedSpell(int32 Slot) const
{
	return EquippedSlots.IsValidIndex(Slot) ? EquippedSlots[Slot].Get() : nullptr;
}

void UArcanumSpellbookComponent::OnRep_Spellbook()
{
	OnSpellbookChanged.Broadcast();
}
