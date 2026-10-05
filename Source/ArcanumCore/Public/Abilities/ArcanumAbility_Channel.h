#pragma once

#include "CoreMinimal.h"
#include "Abilities/ArcanumGameplayAbility.h"
#include "ArcanumAbility_Channel.generated.h"

/**
 * Base de magias canalizadas (Corrente em Cadeia, Raio Arcano): ativa enquanto o botao estiver
 * segurado, drena ManaPerSecond a cada TickIntervalSeconds e chama OnChannelTick no servidor.
 * Sem recarga propria e sem recarga global. Termina ao soltar, sem mana, paralisado ou morto.
 * O visual e um GameplayCue em loop (CastCueTag) removido automaticamente ao terminar.
 */
UCLASS(Abstract)
class ARCANUMCORE_API UArcanumAbility_Channel : public UArcanumGameplayAbility
{
	GENERATED_BODY()

public:
	UArcanumAbility_Channel();

	virtual void ActivateAbility(const FGameplayAbilitySpecHandle Handle, const FGameplayAbilityActorInfo* ActorInfo,
		const FGameplayAbilityActivationInfo ActivationInfo, const FGameplayEventData* TriggerEventData) override;

	virtual void EndAbility(const FGameplayAbilitySpecHandle Handle, const FGameplayAbilityActorInfo* ActorInfo,
		const FGameplayAbilityActivationInfo ActivationInfo, bool bReplicateEndAbility, bool bWasCancelled) override;

protected:
	/** Logica da magia por tick. Chamado somente no servidor, ja com a mana paga. */
	virtual void OnChannelTick(float DeltaSeconds) {}

private:
	UFUNCTION()
	void HandleInputReleased(float TimeHeld);

	void TickChannel();

	/** Paga a drenagem do tick; false se nao houver mana suficiente. */
	bool PayChannelCost(float DeltaSeconds);

	FTimerHandle TickTimer;
	float TickInterval = 0.1f;
};
