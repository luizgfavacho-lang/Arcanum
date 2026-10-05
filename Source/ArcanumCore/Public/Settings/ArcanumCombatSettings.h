#pragma once

#include "CoreMinimal.h"
#include "Engine/DeveloperSettings.h"
#include "Math/ArcanumDamageMath.h"
#include "ArcanumCombatSettings.generated.h"

/**
 * Constantes globais de combate, editaveis em Project Settings > Arcanum > Combat
 * e versionadas em texto em Config/DefaultGame.ini.
 */
UCLASS(Config = Game, DefaultConfig, meta = (DisplayName = "Combat"))
class ARCANUMCORE_API UArcanumCombatSettings : public UDeveloperSettings
{
	GENERATED_BODY()

public:
	UArcanumCombatSettings();

	virtual FName GetCategoryName() const override { return TEXT("Arcanum"); }

	UPROPERTY(Config, EditAnywhere, Category = "Damage")
	float ArmorReductionPerPoint = 0.04f;

	UPROPERTY(Config, EditAnywhere, Category = "Damage")
	float MaxArmorReduction = 0.80f;

	UPROPERTY(Config, EditAnywhere, Category = "Damage")
	float SpellPowerBonusPerPoint = 0.01f;

	UPROPERTY(Config, EditAnywhere, Category = "Damage")
	float AffinityBonusPerLevel = 0.03f;

	UPROPERTY(Config, EditAnywhere, Category = "Status")
	float CursedDamageTakenBonus = 0.20f;

	UPROPERTY(Config, EditAnywhere, Category = "Status")
	float ArcaneChargeBonus = 0.25f;

	UPROPERTY(Config, EditAnywhere, Category = "Status")
	float WetElectricityMultiplier = 1.5f;

	/** Escudo de Mana: mana gasta por ponto de dano absorvido. */
	UPROPERTY(Config, EditAnywhere, Category = "Mana")
	float ManaShieldManaPerDamage = 2.f;

	/** Segundos sem regenerar mana apos causar/receber dano. */
	UPROPERTY(Config, EditAnywhere, Category = "Mana")
	float ManaRegenCombatDelay = 3.f;

	UPROPERTY(Config, EditAnywhere, Category = "Mana")
	float ManaRegenTickInterval = 0.25f;

	/** Recarga global entre magias nao canalizadas. */
	UPROPERTY(Config, EditAnywhere, Category = "Casting")
	float GlobalCooldown = 0.4f;

	FArcanumDamageTuning MakeDamageTuning() const;
};
