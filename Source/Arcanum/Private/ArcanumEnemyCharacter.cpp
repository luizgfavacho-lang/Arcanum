#include "ArcanumEnemyCharacter.h"

#include "Attributes/ArcanumAttributeSet.h"
#include "Components/ArcanumAbilitySystemComponent.h"
#include "Data/ArcanumEnemyRow.h"
#include "GameFramework/CharacterMovementComponent.h"
#include "Net/UnrealNetwork.h"

AArcanumEnemyCharacter::AArcanumEnemyCharacter()
{
	TeamId = ArcanumTeams::Monsters;

	OwnedAbilitySystem = CreateDefaultSubobject<UArcanumAbilitySystemComponent>(TEXT("AbilitySystem"));
	OwnedAbilitySystem->SetReplicationMode(EGameplayEffectReplicationMode::Minimal);

	// Subobjeto do dono: o ASC registra o AttributeSet automaticamente.
	OwnedAttributes = CreateDefaultSubobject<UArcanumAttributeSet>(TEXT("Attributes"));
}

void AArcanumEnemyCharacter::GetLifetimeReplicatedProps(TArray<FLifetimeProperty>& OutLifetimeProps) const
{
	Super::GetLifetimeReplicatedProps(OutLifetimeProps);
	DOREPLIFETIME(AArcanumEnemyCharacter, bElite);
}

void AArcanumEnemyCharacter::BeginPlay()
{
	Super::BeginPlay();
	// Antes do InitAbilitySystem para que a velocidade base (restaurada apos Paralisia) ja seja a da tabela.
	ApplyRowStats();
	InitAbilitySystem(OwnedAbilitySystem, OwnedAttributes, this);
}

void AArcanumEnemyCharacter::ApplyRowStats()
{
	static const FString Context(TEXT("AArcanumEnemyCharacter::ApplyRowStats"));
	const FArcanumEnemyRow* Row = EnemyRow.GetRow<FArcanumEnemyRow>(Context);
	if (!Row)
	{
		return;
	}

	// Dados locais: cliente e servidor aplicam a mesma velocidade.
	GetCharacterMovement()->MaxWalkSpeed = Row->MoveSpeedMetersPerSecond * 100.f;
	if (!HasAuthority())
	{
		return;
	}

	bElite = Row->bMagical && !Row->bBoss && FMath::FRand() < EliteChance;
	const float HealthMult = bElite ? 2.f : 1.f;
	// Elite causa x1,5 de dano: +50 de Poder Magico (+1% por ponto).
	const float SpellPower = bElite ? 50.f : 0.f;

	// TODO(Sonnet): escala por distancia do ponto inicial e por dia (com teto) — Docs/01-GDD.md 8.3.
	UArcanumAbilitySystemComponent* ASC = OwnedAbilitySystem;
	ASC->SetNumericAttributeBase(UArcanumAttributeSet::GetMaxHealthAttribute(), Row->MaxHealth * HealthMult);
	ASC->SetNumericAttributeBase(UArcanumAttributeSet::GetHealthAttribute(), Row->MaxHealth * HealthMult);
	ASC->SetNumericAttributeBase(UArcanumAttributeSet::GetArmorAttribute(), Row->Armor);
	ASC->SetNumericAttributeBase(UArcanumAttributeSet::GetSpellPowerAttribute(), SpellPower);

	OnRep_Elite();
}

int32 AArcanumEnemyCharacter::GetXPReward() const
{
	static const FString Context(TEXT("AArcanumEnemyCharacter::GetXPReward"));
	const FArcanumEnemyRow* Row = EnemyRow.GetRow<FArcanumEnemyRow>(Context);
	return Row ? Row->XPReward * (bElite ? 2 : 1) : 0;
}

void AArcanumEnemyCharacter::OnRep_Elite()
{
	OnEliteChanged(bElite);
}

void AArcanumEnemyCharacter::HandleOutOfHealth(AActor* Killer, float DamageMagnitude)
{
	Super::HandleOutOfHealth(Killer, DamageMagnitude);
	// TODO(Sonnet): conceder GetXPReward() ao UArcanumProgressionComponent do matador e soltar loot.
	SetLifeSpan(5.f);
}
