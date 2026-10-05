#pragma once

#include "CoreMinimal.h"
#include "GameFramework/GameModeBase.h"
#include "ArcanumGameMode.generated.h"

/** Modo de jogo base. Os BPs filhos escolhem o pawn (BP_PlayerCharacter) e o HUD. */
UCLASS()
class ARCANUM_API AArcanumGameMode : public AGameModeBase
{
	GENERATED_BODY()

public:
	AArcanumGameMode();
};
