#pragma once

#include "CoreMinimal.h"
#include "Abilities/GameplayAbility.h"
#include "Data/ArcanumSpellModifiers.h"
#include "ArcanumGameplayAbility.generated.h"

class UArcanumSpellDefinition;
struct FArcanumSpellRow;

/** Custo efetivo de uma conjuracao, ja com modificadores. */
struct FArcanumSpellCost
{
	float Mana = 0.f;
	float Health = 0.f;
};

/**
 * Base de todas as magias.
 * - A magia concreta vem do SourceObject do spec (UArcanumSpellDefinition); numeros vem do CSV.
 * - Custo de mana/vida e recarga sao calculados em C++ (UArcanumCostEffect / UArcanumCooldownEffect
 *   com SetByCaller), ja aplicando runas/talentos/passivas (IArcanumSpellModifierSource).
 * - Recarga global (Cooldown.Global) entre magias nao canalizadas.
 * - Helpers de dano/estado/cura usados pelas subclasses e pelos projeteis.
 */
UCLASS(Abstract)
class ARCANUMCORE_API UArcanumGameplayAbility : public UGameplayAbility
{
	GENERATED_BODY()

public:
	UArcanumGameplayAbility();

	//~ UGameplayAbility
	virtual void OnGiveAbility(const FGameplayAbilityActorInfo* ActorInfo, const FGameplayAbilitySpec& Spec) override;
	virtual bool CheckCost(const FGameplayAbilitySpecHandle Handle, const FGameplayAbilityActorInfo* ActorInfo,
		FGameplayTagContainer* OptionalRelevantTags = nullptr) const override;
	virtual void ApplyCost(const FGameplayAbilitySpecHandle Handle, const FGameplayAbilityActorInfo* ActorInfo,
		const FGameplayAbilityActivationInfo ActivationInfo) const override;
	virtual const FGameplayTagContainer* GetCooldownTags() const override;
	virtual void ApplyCooldown(const FGameplayAbilitySpecHandle Handle, const FGameplayAbilityActorInfo* ActorInfo,
		const FGameplayAbilityActivationInfo ActivationInfo) const override;
	//~ End UGameplayAbility

	UFUNCTION(BlueprintPure, Category = "Arcanum|Spell")
	UArcanumSpellDefinition* GetSpellDefinition() const { return Definition; }

	/** Linha do CSV; uma linha vazia (tudo 0) se a definicao estiver incompleta. */
	const FArcanumSpellRow& GetBalance() const;

	/** Modificadores atuais do conjurador para esta magia. */
	FArcanumSpellModifiers GetSpellModifiers() const;

	/** Constroi o spec de dano desta magia (usado tambem por projeteis). */
	FGameplayEffectSpecHandle MakeDamageSpec(float BaseDamage, float ExtraMultiplier = 1.f) const;

	/** Spec do estado secundario (ProcState do Data Asset) ou invalido se a magia nao tiver. */
	FGameplayEffectSpecHandle MakeProcSpec() const;

protected:
	/** Aplica dano de magia no alvo (somente servidor). */
	void ApplySpellDamage(AActor* Target, float BaseDamage, float ExtraMultiplier = 1.f) const;

	/**
	 * Rola ProcChance e aplica o estado secundario (somente servidor).
	 * ExposureSeconds > 0 trata ProcChance como chance POR SEGUNDO (canalizadas/auras).
	 */
	void TryApplyProc(AActor* Target, float ExposureSeconds = 0.f) const;

	/** Cura o conjurador (Drenar Vida, Almas Errantes). Somente servidor. */
	void HealOwner(float Amount);

	/** Origem e direcao de mira do conjurador (olhos + rotacao de controle). */
	bool GetAimViewpoint(FVector& OutLocation, FVector& OutDirection) const;

	/** Ponto de saida das magias: socket "Muzzle" do mesh (gema do cajado) ou fallback. */
	FVector GetMuzzleLocation() const;

	/** Executa um GameplayCue (replicado) a partir do conjurador. */
	void ExecuteCueAt(const FGameplayTag& CueTag, const FVector& Location, AActor* Target = nullptr) const;

	FArcanumSpellCost ComputeCost(const FGameplayAbilityActorInfo* ActorInfo) const;

	/** Magias canalizadas desligam isso (sem recarga global). */
	UPROPERTY(EditDefaultsOnly, Category = "Arcanum|Spell")
	bool bApplyGlobalCooldown = true;

private:
	UPROPERTY(Transient)
	TObjectPtr<UArcanumSpellDefinition> Definition;

	UPROPERTY(Transient)
	FGameplayTagContainer TempCooldownTags;
};
