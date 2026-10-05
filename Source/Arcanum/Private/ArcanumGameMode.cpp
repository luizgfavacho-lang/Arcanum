#include "ArcanumGameMode.h"

#include "ArcanumPlayerCharacter.h"
#include "ArcanumPlayerState.h"

AArcanumGameMode::AArcanumGameMode()
{
	DefaultPawnClass = AArcanumPlayerCharacter::StaticClass();
	PlayerStateClass = AArcanumPlayerState::StaticClass();
}
