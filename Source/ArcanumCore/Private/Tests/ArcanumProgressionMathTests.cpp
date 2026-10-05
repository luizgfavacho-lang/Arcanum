// Testes de progressao. Rodar: Scripts/Test.ps1 (filtro "Arcanum.").
#include "Misc/AutomationTest.h"
#include "Math/ArcanumProgressionMath.h"

#if WITH_DEV_AUTOMATION_TESTS

// Macro (e nao constante) porque o tipo de EAutomationTestFlags mudou entre versoes da engine.
#define ARCANUM_TEST_FLAGS (EAutomationTestFlags::EditorContext | EAutomationTestFlags::ProductFilter)

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FArcanumXPCurveTest, "Arcanum.Progression.XPCurve", ARCANUM_TEST_FLAGS)
bool FArcanumXPCurveTest::RunTest(const FString& Parameters)
{
	TestEqual(TEXT("Nivel 1 -> 2"), ArcanumProgressionMath::XPToNextLevel(1), 50);
	TestEqual(TEXT("Nivel 4 -> 5"), ArcanumProgressionMath::XPToNextLevel(4), 400);
	TestEqual(TEXT("Nivel maximo"), ArcanumProgressionMath::XPToNextLevel(50), 0);
	TestEqual(TEXT("Nivel invalido"), ArcanumProgressionMath::XPToNextLevel(0), 0);
	return true;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FArcanumSkillPointsTest, "Arcanum.Progression.SkillPoints", ARCANUM_TEST_FLAGS)
bool FArcanumSkillPointsTest::RunTest(const FString& Parameters)
{
	TestEqual(TEXT("Nivel 4"), ArcanumProgressionMath::SkillPointsAtLevel(4), 0);
	TestEqual(TEXT("Nivel 5"), ArcanumProgressionMath::SkillPointsAtLevel(5), 1);
	TestEqual(TEXT("Nivel 50 = 10 pontos"), ArcanumProgressionMath::SkillPointsAtLevel(50), 10);
	TestEqual(TEXT("Acima do maximo"), ArcanumProgressionMath::SkillPointsAtLevel(80), 10);
	return true;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FArcanumApplyXPTest, "Arcanum.Progression.ApplyXP", ARCANUM_TEST_FLAGS)
bool FArcanumApplyXPTest::RunTest(const FString& Parameters)
{
	int32 XP = 60;
	TestEqual(TEXT("Sobe 1 nivel"), ArcanumProgressionMath::ApplyXP(1, XP), 2);
	TestEqual(TEXT("Sobra 10"), XP, 10);

	XP = 50 + 141 + 260; // 1->2, 2->3, 3->4
	TestEqual(TEXT("Varios niveis"), ArcanumProgressionMath::ApplyXP(1, XP), 4);
	TestEqual(TEXT("Sem sobra"), XP, 0);

	XP = 100000000;
	TestEqual(TEXT("Para no 50"), ArcanumProgressionMath::ApplyXP(1, XP), 50);
	TestEqual(TEXT("XP zerado no maximo"), XP, 0);
	return true;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FArcanumAffinityTest, "Arcanum.Progression.Affinity", ARCANUM_TEST_FLAGS)
bool FArcanumAffinityTest::RunTest(const FString& Parameters)
{
	TestEqual(TEXT("0 -> 1"), ArcanumProgressionMath::AffinityUsesToNext(0), 20);
	TestEqual(TEXT("9 -> 10"), ArcanumProgressionMath::AffinityUsesToNext(9), 2000);
	TestEqual(TEXT("Maximo"), ArcanumProgressionMath::AffinityUsesToNext(10), 0);
	return true;
}

#endif // WITH_DEV_AUTOMATION_TESTS
