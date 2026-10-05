#pragma once

#include "CoreMinimal.h"

/**
 * Regras de progressao puras. A curva oficial vem de Data/Levels.csv; estas funcoes sao o
 * fallback e a referencia testada (o validador de dados compara o CSV com elas).
 */
namespace ArcanumProgressionMath
{
	inline constexpr int32 MaxLevel = 50;
	inline constexpr int32 LevelsPerSkillPoint = 5;
	inline constexpr int32 MaxAffinity = 10;

	/** XP para ir de Level a Level+1: round(50 * Level^1.5). 0 no nivel maximo. */
	ARCANUMCORE_API int32 XPToNextLevel(int32 Level);

	/** Pontos de habilidade acumulados ate o nivel (1 a cada 5 niveis; 10 no nivel 50). */
	ARCANUMCORE_API int32 SkillPointsAtLevel(int32 Level);

	/** Aplica XP e devolve o novo nivel; XP restante em InOutXP. */
	ARCANUMCORE_API int32 ApplyXP(int32 Level, int32& InOutXP);

	/** Usos de magia da escola necessarios para subir de afinidade A para A+1: 20 * (A+1)^2. */
	ARCANUMCORE_API int32 AffinityUsesToNext(int32 Affinity);
}
