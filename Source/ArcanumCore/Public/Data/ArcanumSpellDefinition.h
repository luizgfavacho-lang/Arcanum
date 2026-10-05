#pragma once

#include "CoreMinimal.h"
#include "Engine/DataAsset.h"
#include "Engine/DataTable.h"
#include "GameplayTagContainer.h"
#include "Data/ArcanumSpellRow.h"
#include "ArcanumSpellDefinition.generated.h"

class UArcanumGameplayAbility;
class UTexture2D;

/**
 * Identidade e apresentacao de uma magia (DA_Spell_<Id>).
 * Os NUMEROS nao ficam aqui: vem da linha Balance (DT_Spells, importada de Data/Spells.csv).
 * Uma mesma classe de ability pode servir varias magias (ex.: Bola de Fogo e Missil Arcano
 * usam UArcanumAbility_Projectile); a ability le esta definicao pelo SourceObject do spec.
 */
UCLASS(BlueprintType)
class ARCANUMCORE_API UArcanumSpellDefinition : public UPrimaryDataAsset
{
	GENERATED_BODY()

public:
	/** Id estavel (igual ao nome da linha no CSV e ao sufixo das tags). Ex.: "Fireball". */
	UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Spell")
	FName SpellId;

	UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Spell")
	TSubclassOf<UArcanumGameplayAbility> AbilityClass;

	/** Linha em DT_Spells. */
	UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Spell", meta = (RowType = "/Script/ArcanumCore.ArcanumSpellRow"))
	FDataTableRowHandle Balance;

	UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "UI")
	TSoftObjectPtr<UTexture2D> Icon;

	/** Opcional: vazio = Cooldown.Spell.<SpellId> (Config/Tags/ArcanumSpells.ini). */
	UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Tags")
	FGameplayTag CooldownTag;

	/** Opcional: vazio = GameplayCue.Spell.<SpellId>.Cast (conjuracao/canalizacao). */
	UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Tags")
	FGameplayTag CastCueTag;

	/** Opcional: vazio = GameplayCue.Spell.<SpellId>.Impact. */
	UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Tags")
	FGameplayTag ImpactCueTag;

	/**
	 * Estado aplicado no acerto com chance ProcChance (CSV). Ex.: State.Paralyzed (Faisca),
	 * State.Burning (Bola de Fogo), State.ArcaneCharge (Missil Arcano), State.Bleeding (Lamina).
	 * Burning/Bleeding usam dano periodico (ProcDamagePerSecond); os demais so concedem a tag.
	 */
	UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Tags", meta = (Categories = "State"))
	FGameplayTag ProcStateTag;

	/** Tags efetivas (campo preenchido ou derivada do SpellId). */
	FGameplayTag GetCooldownTag() const;
	FGameplayTag GetCastCueTag() const;
	FGameplayTag GetImpactCueTag() const;

	/** Nome exibido: String Table ST_Spells, chave "<SpellId>.Name" (Content/Text/ST_Spells.csv). */
	UFUNCTION(BlueprintPure, Category = "UI")
	FText GetDisplayName() const;

	/** Descricao: chave "<SpellId>.Desc". */
	UFUNCTION(BlueprintPure, Category = "UI")
	FText GetDescription() const;

	/** Linha de balanceamento ou nullptr (loga erro). */
	const FArcanumSpellRow* GetBalance() const;

	virtual FPrimaryAssetId GetPrimaryAssetId() const override;
};
