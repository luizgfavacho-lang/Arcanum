#include "ArcanumGameplayTags.h"

namespace ArcanumTags
{
	UE_DEFINE_GAMEPLAY_TAG_COMMENT(School_Electricity, "School.Electricity", "Escola de Eletricidade");
	UE_DEFINE_GAMEPLAY_TAG_COMMENT(School_Fire, "School.Fire", "Escola de Fogo");
	UE_DEFINE_GAMEPLAY_TAG_COMMENT(School_Energy, "School.Energy", "Escola de Energia");
	UE_DEFINE_GAMEPLAY_TAG_COMMENT(School_Necromancy, "School.Necromancy", "Escola de Necromancia");
	UE_DEFINE_GAMEPLAY_TAG_COMMENT(School_Blood, "School.Blood", "Escola de Sangue");

	UE_DEFINE_GAMEPLAY_TAG_COMMENT(State_Paralyzed, "State.Paralyzed", "Velocidade 0, nao conjura");
	UE_DEFINE_GAMEPLAY_TAG_COMMENT(State_Burning, "State.Burning", "Dano continuo de fogo");
	UE_DEFINE_GAMEPLAY_TAG_COMMENT(State_Bleeding, "State.Bleeding", "Dano continuo; aumenta com movimento");
	UE_DEFINE_GAMEPLAY_TAG_COMMENT(State_Cursed, "State.Cursed", "Recebe mais dano");
	UE_DEFINE_GAMEPLAY_TAG_COMMENT(State_ArcaneCharge, "State.ArcaneCharge", "Proximo golpe amplificado");
	UE_DEFINE_GAMEPLAY_TAG_COMMENT(State_Wet, "State.Wet", "Molhado (chuva/agua); combos com eletricidade");
	UE_DEFINE_GAMEPLAY_TAG_COMMENT(State_ManaShield, "State.ManaShield", "Dano absorvido pela mana");
	UE_DEFINE_GAMEPLAY_TAG_COMMENT(State_Channeling, "State.Channeling", "Canalizando uma magia");
	UE_DEFINE_GAMEPLAY_TAG_COMMENT(State_Dead, "State.Dead", "Morto");

	UE_DEFINE_GAMEPLAY_TAG_COMMENT(Data_Damage, "Data.Damage", "SetByCaller: dano base");
	UE_DEFINE_GAMEPLAY_TAG_COMMENT(Data_DamageMultiplier, "Data.DamageMultiplier", "SetByCaller: multiplicador (runas/talentos)");
	UE_DEFINE_GAMEPLAY_TAG_COMMENT(Data_ManaCost, "Data.ManaCost", "SetByCaller: custo de mana (negativo)");
	UE_DEFINE_GAMEPLAY_TAG_COMMENT(Data_HealthCost, "Data.HealthCost", "SetByCaller: custo de vida (negativo)");
	UE_DEFINE_GAMEPLAY_TAG_COMMENT(Data_Cooldown, "Data.Cooldown", "SetByCaller: duracao da recarga");
	UE_DEFINE_GAMEPLAY_TAG_COMMENT(Data_Duration, "Data.Duration", "SetByCaller: duracao de estado");
	UE_DEFINE_GAMEPLAY_TAG_COMMENT(Data_Heal, "Data.Heal", "SetByCaller: cura");

	UE_DEFINE_GAMEPLAY_TAG_COMMENT(Ability_Spell, "Ability.Spell", "Toda magia conjuravel");
	UE_DEFINE_GAMEPLAY_TAG_COMMENT(Cooldown_Global, "Cooldown.Global", "Recarga global entre magias");

	UE_DEFINE_GAMEPLAY_TAG_COMMENT(GameplayCue_Cast_School, "GameplayCue.Cast.School", "Assinatura de conjuracao por escola");
}
