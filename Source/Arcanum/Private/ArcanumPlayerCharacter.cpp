#include "ArcanumPlayerCharacter.h"

#include "ArcanumPlayerState.h"
#include "Camera/CameraComponent.h"
#include "Components/ArcanumAbilitySystemComponent.h"
#include "Components/ArcanumSpellbookComponent.h"
#include "EnhancedInputComponent.h"
#include "EnhancedInputSubsystems.h"
#include "Engine/LocalPlayer.h"
#include "GameFramework/CharacterMovementComponent.h"
#include "GameFramework/PlayerController.h"
#include "GameFramework/SpringArmComponent.h"
#include "InputActionValue.h"

AArcanumPlayerCharacter::AArcanumPlayerCharacter()
{
	TeamId = ArcanumTeams::Player;

	// Mago estilo "caster": o corpo segue a yaw da camera para mirar.
	bUseControllerRotationYaw = true;
	GetCharacterMovement()->bOrientRotationToMovement = false;
	GetCharacterMovement()->MaxWalkSpeed = 500.f;

	CameraBoom = CreateDefaultSubobject<USpringArmComponent>(TEXT("CameraBoom"));
	CameraBoom->SetupAttachment(RootComponent);
	CameraBoom->TargetArmLength = 350.f;
	CameraBoom->SocketOffset = FVector(0.f, 60.f, 70.f); // ombro direito
	CameraBoom->bUsePawnControlRotation = true;

	FollowCamera = CreateDefaultSubobject<UCameraComponent>(TEXT("FollowCamera"));
	FollowCamera->SetupAttachment(CameraBoom, USpringArmComponent::SocketName);
	FollowCamera->bUsePawnControlRotation = false;
}

void AArcanumPlayerCharacter::PossessedBy(AController* NewController)
{
	Super::PossessedBy(NewController);
	InitFromPlayerState(); // servidor
}

void AArcanumPlayerCharacter::OnRep_PlayerState()
{
	Super::OnRep_PlayerState();
	InitFromPlayerState(); // cliente
}

void AArcanumPlayerCharacter::InitFromPlayerState()
{
	AArcanumPlayerState* PS = GetPlayerState<AArcanumPlayerState>();
	if (!PS)
	{
		return;
	}

	InitAbilitySystem(PS->GetArcanumAbilitySystem(), PS->GetAttributeSet(), PS);

	if (HasAuthority())
	{
		PS->GetSpellbook()->InitializeWithAbilitySystem(PS->GetArcanumAbilitySystem());
	}
}

void AArcanumPlayerCharacter::PawnClientRestart()
{
	Super::PawnClientRestart();

	const APlayerController* PC = Cast<APlayerController>(GetController());
	if (!PC || !DefaultMappingContext)
	{
		return;
	}
	if (UEnhancedInputLocalPlayerSubsystem* Subsystem = ULocalPlayer::GetSubsystem<UEnhancedInputLocalPlayerSubsystem>(PC->GetLocalPlayer()))
	{
		Subsystem->RemoveMappingContext(DefaultMappingContext);
		Subsystem->AddMappingContext(DefaultMappingContext, 0);
	}
}

void AArcanumPlayerCharacter::SetupPlayerInputComponent(UInputComponent* PlayerInputComponent)
{
	Super::SetupPlayerInputComponent(PlayerInputComponent);

	UEnhancedInputComponent* Input = Cast<UEnhancedInputComponent>(PlayerInputComponent);
	if (!Input)
	{
		return;
	}

	if (MoveAction)
	{
		Input->BindAction(MoveAction, ETriggerEvent::Triggered, this, &AArcanumPlayerCharacter::Move);
	}
	if (LookAction)
	{
		Input->BindAction(LookAction, ETriggerEvent::Triggered, this, &AArcanumPlayerCharacter::Look);
	}
	if (JumpAction)
	{
		Input->BindAction(JumpAction, ETriggerEvent::Started, this, &ACharacter::Jump);
		Input->BindAction(JumpAction, ETriggerEvent::Completed, this, &ACharacter::StopJumping);
	}

	for (int32 Slot = 0; Slot < SpellSlotActions.Num() && Slot < UArcanumSpellbookComponent::NumSlots; ++Slot)
	{
		if (const UInputAction* Action = SpellSlotActions[Slot])
		{
			Input->BindAction(Action, ETriggerEvent::Started, this, &AArcanumPlayerCharacter::OnSpellPressed, Slot);
			Input->BindAction(Action, ETriggerEvent::Completed, this, &AArcanumPlayerCharacter::OnSpellReleased, Slot);
		}
	}

	if (CastSelectedAction)
	{
		Input->BindAction(CastSelectedAction, ETriggerEvent::Started, this, &AArcanumPlayerCharacter::OnCastSelectedPressed);
		Input->BindAction(CastSelectedAction, ETriggerEvent::Completed, this, &AArcanumPlayerCharacter::OnCastSelectedReleased);
	}
	if (CycleSlotAction)
	{
		Input->BindAction(CycleSlotAction, ETriggerEvent::Started, this, &AArcanumPlayerCharacter::OnCycleSlot);
	}
}

void AArcanumPlayerCharacter::Move(const FInputActionValue& Value)
{
	const FVector2D Axis = Value.Get<FVector2D>();
	if (!Controller)
	{
		return;
	}
	const FRotator Yaw(0.f, Controller->GetControlRotation().Yaw, 0.f);
	AddMovementInput(FRotationMatrix(Yaw).GetUnitAxis(EAxis::X), Axis.Y);
	AddMovementInput(FRotationMatrix(Yaw).GetUnitAxis(EAxis::Y), Axis.X);
}

void AArcanumPlayerCharacter::Look(const FInputActionValue& Value)
{
	const FVector2D Axis = Value.Get<FVector2D>();
	AddControllerYawInput(Axis.X);
	AddControllerPitchInput(Axis.Y);
}

void AArcanumPlayerCharacter::OnSpellPressed(int32 Slot)
{
	if (AbilitySystem)
	{
		AbilitySystem->AbilityLocalInputPressed(Slot);
	}
}

void AArcanumPlayerCharacter::OnSpellReleased(int32 Slot)
{
	if (AbilitySystem)
	{
		AbilitySystem->AbilityLocalInputReleased(Slot);
	}
}

void AArcanumPlayerCharacter::OnCycleSlot(const FInputActionValue& Value)
{
	const int32 Step = Value.Get<float>() >= 0.f ? 1 : -1;
	SelectedSlot = (SelectedSlot + Step + UArcanumSpellbookComponent::NumSlots) % UArcanumSpellbookComponent::NumSlots;
}
