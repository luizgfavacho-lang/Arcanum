// Testes de regras de dano. Rodar: Scripts/Test.ps1 (filtro "Arcanum.").
#include "Misc/AutomationTest.h"
#include "Math/ArcanumDamageMath.h"

#if WITH_DEV_AUTOMATION_TESTS

// Macro (e nao constante) porque o tipo de EAutomationTestFlags mudou entre versoes da engine.
#define ARCANUM_TEST_FLAGS (EAutomationTestFlags::EditorContext | EAutomationTestFlags::ProductFilter)

namespace
{

	FArcanumDamageInputs Fireball()
	{
		FArcanumDamageInputs In;
		In.BaseDamage = 6.f; // Bola de Fogo (T1)
		In.School = EArcanumSchool::Fire;
		return In;
	}
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FArcanumDamageBaseTest, "Arcanum.Damage.BaseAndScaling", ARCANUM_TEST_FLAGS)
bool FArcanumDamageBaseTest::RunTest(const FString& Parameters)
{
	const FArcanumDamageTuning Tuning;

	TestEqual(TEXT("Sem modificadores = dano base"), ArcanumDamageMath::ComputeSpellDamage(Fireball(), Tuning), 6.f, 0.001f);

	FArcanumDamageInputs In = Fireball();
	In.SpellPower = 50.f;
	TestEqual(TEXT("Poder Magico 50 = +50%"), ArcanumDamageMath::ComputeSpellDamage(In, Tuning), 9.f, 0.001f);

	In = Fireball();
	In.Affinity = 10.f;
	TestEqual(TEXT("Afinidade 10 = +30%"), ArcanumDamageMath::ComputeSpellDamage(In, Tuning), 7.8f, 0.001f);

	In = Fireball();
	In.Affinity = 99.f;
	TestEqual(TEXT("Afinidade limitada a 10"), ArcanumDamageMath::ComputeSpellDamage(In, Tuning), 7.8f, 0.001f);

	In = Fireball();
	In.DamageMultiplier = 1.2f * 1.15f; // Runa do Poder + Runa do Fogo
	TestEqual(TEXT("Runas multiplicam"), ArcanumDamageMath::ComputeSpellDamage(In, Tuning), 6.f * 1.38f, 0.001f);

	In = Fireball();
	In.BaseDamage = 0.f;
	TestEqual(TEXT("Dano base 0 = 0"), ArcanumDamageMath::ComputeSpellDamage(In, Tuning), 0.f, 0.001f);
	return true;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FArcanumDamageArmorTest, "Arcanum.Damage.Armor", ARCANUM_TEST_FLAGS)
bool FArcanumDamageArmorTest::RunTest(const FString& Parameters)
{
	const FArcanumDamageTuning Tuning;

	FArcanumDamageInputs In = Fireball();
	In.TargetArmor = 10.f;
	TestEqual(TEXT("Armadura 10 = -40%"), ArcanumDamageMath::ComputeSpellDamage(In, Tuning), 3.6f, 0.001f);

	In.TargetArmor = 30.f;
	TestEqual(TEXT("Armadura com teto de 80%"), ArcanumDamageMath::ComputeSpellDamage(In, Tuning), 1.2f, 0.001f);

	TestEqual(TEXT("Armadura negativa nao amplifica"), ArcanumDamageMath::ArmorReduction(-5.f, Tuning), 0.f, 0.001f);
	return true;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FArcanumDamageStatusTest, "Arcanum.Damage.StatusSynergies", ARCANUM_TEST_FLAGS)
bool FArcanumDamageStatusTest::RunTest(const FString& Parameters)
{
	const FArcanumDamageTuning Tuning;

	FArcanumDamageInputs In = Fireball();
	In.bTargetCursed = true;
	TestEqual(TEXT("Maldicao +20%"), ArcanumDamageMath::ComputeSpellDamage(In, Tuning), 7.2f, 0.001f);

	In = Fireball();
	In.bTargetArcaneCharged = true;
	TestEqual(TEXT("Carga Arcana +25%"), ArcanumDamageMath::ComputeSpellDamage(In, Tuning), 7.5f, 0.001f);

	FArcanumDamageInputs Spark;
	Spark.BaseDamage = 5.f; // Faisca
	Spark.School = EArcanumSchool::Electricity;
	Spark.bTargetWet = true;
	TestEqual(TEXT("Eletricidade em alvo molhado x1,5"), ArcanumDamageMath::ComputeSpellDamage(Spark, Tuning), 7.5f, 0.001f);

	In = Fireball();
	In.bTargetWet = true;
	TestEqual(TEXT("Molhado nao afeta fogo"), ArcanumDamageMath::ComputeSpellDamage(In, Tuning), 6.f, 0.001f);
	return true;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FArcanumChainFalloffTest, "Arcanum.Damage.ChainFalloff", ARCANUM_TEST_FLAGS)
bool FArcanumChainFalloffTest::RunTest(const FString& Parameters)
{
	// Corrente em Cadeia: -15% por salto (multiplicativo).
	TestEqual(TEXT("Salto 0"), ArcanumDamageMath::ChainDamageAtJump(10.f, 0, 0.15f), 10.f, 0.001f);
	TestEqual(TEXT("Salto 1"), ArcanumDamageMath::ChainDamageAtJump(10.f, 1, 0.15f), 8.5f, 0.001f);
	TestEqual(TEXT("Salto 3"), ArcanumDamageMath::ChainDamageAtJump(10.f, 3, 0.15f), 6.141f, 0.01f);
	// Talento Cadeia Bifurcada: -10% por salto.
	TestEqual(TEXT("Talento -10%"), ArcanumDamageMath::ChainDamageAtJump(10.f, 2, 0.10f), 8.1f, 0.001f);
	return true;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FArcanumManaShieldTest, "Arcanum.Mana.Shield", ARCANUM_TEST_FLAGS)
bool FArcanumManaShieldTest::RunTest(const FString& Parameters)
{
	// Escudo de Mana: 2 de mana por ponto de dano.
	FArcanumManaShieldResult R = ArcanumDamageMath::ResolveManaShield(10.f, 100.f, 2.f);
	TestEqual(TEXT("Mana cobre tudo: vida"), R.HealthDamage, 0.f, 0.001f);
	TestEqual(TEXT("Mana cobre tudo: mana"), R.ManaSpent, 20.f, 0.001f);

	R = ArcanumDamageMath::ResolveManaShield(10.f, 8.f, 2.f);
	TestEqual(TEXT("Mana insuficiente: vida"), R.HealthDamage, 6.f, 0.001f);
	TestEqual(TEXT("Mana insuficiente: mana"), R.ManaSpent, 8.f, 0.001f);

	// Talento Escudo Eficiente: 1,25 por dano.
	R = ArcanumDamageMath::ResolveManaShield(8.f, 100.f, 1.25f);
	TestEqual(TEXT("Escudo Eficiente"), R.ManaSpent, 10.f, 0.001f);
	return true;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FArcanumManaRegenTest, "Arcanum.Mana.RegenPause", ARCANUM_TEST_FLAGS)
bool FArcanumManaRegenTest::RunTest(const FString& Parameters)
{
	TestFalse(TEXT("Pausada 2 s apos combate"), ArcanumDamageMath::CanRegenerateMana(10.0, 8.0, 3.f));
	TestTrue(TEXT("Volta apos 3 s"), ArcanumDamageMath::CanRegenerateMana(11.0, 8.0, 3.f));
	return true;
}

#endif // WITH_DEV_AUTOMATION_TESTS
