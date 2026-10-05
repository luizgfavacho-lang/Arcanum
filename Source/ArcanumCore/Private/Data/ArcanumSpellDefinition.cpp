#include "Data/ArcanumSpellDefinition.h"
#include "GameplayTagsManager.h"

namespace
{
	FGameplayTag TagOrDerived(const FGameplayTag& Explicit, const FString& DerivedName)
	{
		return Explicit.IsValid() ? Explicit : FGameplayTag::RequestGameplayTag(FName(*DerivedName), false);
	}
}

const FArcanumSpellRow* UArcanumSpellDefinition::GetBalance() const
{
	static const FString Context(TEXT("UArcanumSpellDefinition::GetBalance"));
	return Balance.GetRow<FArcanumSpellRow>(Context);
}

FPrimaryAssetId UArcanumSpellDefinition::GetPrimaryAssetId() const
{
	return FPrimaryAssetId(TEXT("Spell"), SpellId.IsNone() ? GetFName() : SpellId);
}

FText UArcanumSpellDefinition::GetDisplayName() const
{
	return FText::FromStringTable(TEXT("ST_Spells"), SpellId.ToString() + TEXT(".Name"));
}

FText UArcanumSpellDefinition::GetDescription() const
{
	return FText::FromStringTable(TEXT("ST_Spells"), SpellId.ToString() + TEXT(".Desc"));
}

FGameplayTag UArcanumSpellDefinition::GetCooldownTag() const
{
	return TagOrDerived(CooldownTag, FString::Printf(TEXT("Cooldown.Spell.%s"), *SpellId.ToString()));
}

FGameplayTag UArcanumSpellDefinition::GetCastCueTag() const
{
	return TagOrDerived(CastCueTag, FString::Printf(TEXT("GameplayCue.Spell.%s.Cast"), *SpellId.ToString()));
}

FGameplayTag UArcanumSpellDefinition::GetImpactCueTag() const
{
	return TagOrDerived(ImpactCueTag, FString::Printf(TEXT("GameplayCue.Spell.%s.Impact"), *SpellId.ToString()));
}
