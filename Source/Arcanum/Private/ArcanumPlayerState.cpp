#include "ArcanumPlayerState.h"

#include "Attributes/ArcanumAttributeSet.h"
#include "Components/ArcanumAbilitySystemComponent.h"
#include "Components/ArcanumSpellbookComponent.h"
#include "Misc/EngineVersionComparison.h"

AArcanumPlayerState::AArcanumPlayerState()
{
	AbilitySystem = CreateDefaultSubobject<UArcanumAbilitySystemComponent>(TEXT("AbilitySystem"));
	// Mixed: o dono recebe GEs completos (HUD de recargas), os outros so tags/cues.
	AbilitySystem->SetReplicationMode(EGameplayEffectReplicationMode::Mixed);

	Attributes = CreateDefaultSubobject<UArcanumAttributeSet>(TEXT("Attributes"));
	Spellbook = CreateDefaultSubobject<UArcanumSpellbookComponent>(TEXT("Spellbook"));

	// PlayerState replica devagar por padrao; o GAS precisa de mais.
#if UE_VERSION_OLDER_THAN(5, 5, 0)
	NetUpdateFrequency = 100.f;
#else
	SetNetUpdateFrequency(100.f);
#endif
}

UAbilitySystemComponent* AArcanumPlayerState::GetAbilitySystemComponent() const
{
	return AbilitySystem;
}
