#include "Settings/ArcanumCombatSettings.h"

UArcanumCombatSettings::UArcanumCombatSettings()
{
	SectionName = TEXT("Combat");
}

FArcanumDamageTuning UArcanumCombatSettings::MakeDamageTuning() const
{
	FArcanumDamageTuning Tuning;
	Tuning.ArmorReductionPerPoint = ArmorReductionPerPoint;
	Tuning.MaxArmorReduction = MaxArmorReduction;
	Tuning.SpellPowerBonusPerPoint = SpellPowerBonusPerPoint;
	Tuning.AffinityBonusPerLevel = AffinityBonusPerLevel;
	Tuning.CursedDamageTakenBonus = CursedDamageTakenBonus;
	Tuning.ArcaneChargeBonus = ArcaneChargeBonus;
	Tuning.WetElectricityMultiplier = WetElectricityMultiplier;
	return Tuning;
}
