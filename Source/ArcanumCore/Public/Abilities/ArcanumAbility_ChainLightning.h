#pragma once

#include "CoreMinimal.h"
#include "Abilities/ArcanumAbility_Channel.h"
#include "ArcanumAbility_ChainLightning.generated.h"

/**
 * Corrente em Cadeia (T2, canalizada): fluxo de raios na mira que salta para ate MaxTargets
 * alvos, perdendo FalloffPerJump por salto. Damage no CSV = dano POR SEGUNDO no primeiro alvo.
 * ProcChance = chance de paralisia POR SEGUNDO de exposicao.
 * O cue em loop recalcula os saltos localmente (ArcanumTargeting::FindChainTargets) para
 * desenhar os 6-8 fios trancados sem replicar a lista de alvos.
 */
UCLASS()
class ARCANUMCORE_API UArcanumAbility_ChainLightning : public UArcanumAbility_Channel
{
	GENERATED_BODY()

protected:
	virtual void OnChannelTick(float DeltaSeconds) override;

	/** Raio do "tubo" de mira para pegar o primeiro alvo. */
	UPROPERTY(EditDefaultsOnly, Category = "Arcanum|Chain")
	float AimRadiusCm = 40.f;
};
