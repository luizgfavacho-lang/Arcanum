#pragma once

#include "CoreMinimal.h"
#include "ArcanumCharacterBase.h"
#include "Engine/DataTable.h"
#include "ArcanumEnemyCharacter.generated.h"

/**
 * Criatura com ASC proprio (replicacao Minimal). Atributos iniciais vem de DT_Enemies
 * (Data/Enemies.csv). Mobs magicos tem 10% de chance de virar elite.
 * IA (StateTree/Behavior Tree) e ataques ficam nas subclasses/BP.
 */
UCLASS()
class ARCANUM_API AArcanumEnemyCharacter : public AArcanumCharacterBase
{
	GENERATED_BODY()

public:
	AArcanumEnemyCharacter();

	UFUNCTION(BlueprintPure, Category = "Arcanum|Enemy")
	bool IsElite() const { return bElite; }

	/** XP concedido ao matador (ja com bonus de elite). */
	UFUNCTION(BlueprintPure, Category = "Arcanum|Enemy")
	int32 GetXPReward() const;

	virtual void GetLifetimeReplicatedProps(TArray<FLifetimeProperty>& OutLifetimeProps) const override;

protected:
	virtual void BeginPlay() override;
	virtual void HandleOutOfHealth(AActor* Killer, float DamageMagnitude) override;

	/** Linha em DT_Enemies. */
	UPROPERTY(EditAnywhere, Category = "Arcanum|Enemy", meta = (RowType = "/Script/ArcanumCore.ArcanumEnemyRow"))
	FDataTableRowHandle EnemyRow;

	UPROPERTY(EditDefaultsOnly, Category = "Arcanum|Enemy")
	float EliteChance = 0.10f;

	/** Aura dourada no BP (OnRep -> liga o Niagara). */
	UPROPERTY(ReplicatedUsing = OnRep_Elite, BlueprintReadOnly, Category = "Arcanum|Enemy")
	bool bElite = false;

	UFUNCTION()
	void OnRep_Elite();

	UFUNCTION(BlueprintImplementableEvent, Category = "Arcanum|Enemy")
	void OnEliteChanged(bool bIsElite);

	UPROPERTY(VisibleAnywhere, Category = "Arcanum")
	TObjectPtr<UArcanumAbilitySystemComponent> OwnedAbilitySystem;

	UPROPERTY()
	TObjectPtr<UArcanumAttributeSet> OwnedAttributes;

private:
	void ApplyRowStats();
};
