#pragma once

#include "CoreMinimal.h"
#include "ArcanumCharacterBase.h"
#include "ArcanumPlayerCharacter.generated.h"

class UCameraComponent;
class USpringArmComponent;
class UInputAction;
class UInputMappingContext;
struct FInputActionValue;

/**
 * Mago controlado pelo jogador: camera de ombro, Enhanced Input e 5 atalhos de magia.
 * O ASC vive no AArcanumPlayerState. Cada atalho manda Pressed/Released para o InputID
 * igual ao indice do slot (canalizadas terminam ao soltar).
 * Assets de input (IA_*/IMC_Default) sao ligados no BP_PlayerCharacter — ver Docs/04.
 */
UCLASS()
class ARCANUM_API AArcanumPlayerCharacter : public AArcanumCharacterBase
{
	GENERATED_BODY()

public:
	AArcanumPlayerCharacter();

	virtual void PossessedBy(AController* NewController) override;
	virtual void OnRep_PlayerState() override;
	virtual void PawnClientRestart() override;
	virtual void SetupPlayerInputComponent(UInputComponent* PlayerInputComponent) override;

protected:
	void Move(const FInputActionValue& Value);
	void Look(const FInputActionValue& Value);
	void OnSpellPressed(int32 Slot);
	void OnSpellReleased(int32 Slot);

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Camera")
	TObjectPtr<USpringArmComponent> CameraBoom;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Camera")
	TObjectPtr<UCameraComponent> FollowCamera;

	UPROPERTY(EditDefaultsOnly, Category = "Input")
	TObjectPtr<UInputMappingContext> DefaultMappingContext;

	UPROPERTY(EditDefaultsOnly, Category = "Input")
	TObjectPtr<UInputAction> MoveAction;

	UPROPERTY(EditDefaultsOnly, Category = "Input")
	TObjectPtr<UInputAction> LookAction;

	UPROPERTY(EditDefaultsOnly, Category = "Input")
	TObjectPtr<UInputAction> JumpAction;

	/** IA_Spell1..IA_Spell5 (teclas 1-5 / botoes do controle). */
	UPROPERTY(EditDefaultsOnly, Category = "Input")
	TArray<TObjectPtr<UInputAction>> SpellSlotActions;

	/** Conjura a magia do slot selecionado (botao esquerdo / gatilho direito). */
	UPROPERTY(EditDefaultsOnly, Category = "Input")
	TObjectPtr<UInputAction> CastSelectedAction;

	/** Troca rapida: proximo/anterior slot (roda do mouse / bumpers). Eixo 1D. */
	UPROPERTY(EditDefaultsOnly, Category = "Input")
	TObjectPtr<UInputAction> CycleSlotAction;

	UPROPERTY(BlueprintReadOnly, Category = "Input")
	int32 SelectedSlot = 0;

private:
	void InitFromPlayerState();
	void OnCastSelectedPressed() { OnSpellPressed(SelectedSlot); }
	void OnCastSelectedReleased() { OnSpellReleased(SelectedSlot); }
	void OnCycleSlot(const FInputActionValue& Value);
};
