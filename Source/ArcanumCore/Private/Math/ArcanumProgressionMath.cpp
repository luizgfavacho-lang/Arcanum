#include "Math/ArcanumProgressionMath.h"

namespace ArcanumProgressionMath
{
	int32 XPToNextLevel(int32 Level)
	{
		if (Level < 1 || Level >= MaxLevel)
		{
			return 0;
		}
		return FMath::RoundToInt(50.f * FMath::Pow(static_cast<float>(Level), 1.5f));
	}

	int32 SkillPointsAtLevel(int32 Level)
	{
		return FMath::Clamp(Level, 0, MaxLevel) / LevelsPerSkillPoint;
	}

	int32 ApplyXP(int32 Level, int32& InOutXP)
	{
		Level = FMath::Clamp(Level, 1, MaxLevel);
		while (Level < MaxLevel)
		{
			const int32 Needed = XPToNextLevel(Level);
			if (InOutXP < Needed)
			{
				break;
			}
			InOutXP -= Needed;
			++Level;
		}
		if (Level >= MaxLevel)
		{
			InOutXP = 0;
		}
		return Level;
	}

	int32 AffinityUsesToNext(int32 Affinity)
	{
		if (Affinity < 0 || Affinity >= MaxAffinity)
		{
			return 0;
		}
		return 20 * (Affinity + 1) * (Affinity + 1);
	}
}
