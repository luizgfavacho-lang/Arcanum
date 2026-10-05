#include "Actors/ArcanumProjectile.h"

#include "AbilitySystemComponent.h"
#include "Abilities/ArcanumTargeting.h"
#include "Components/SphereComponent.h"
#include "Engine/OverlapResult.h"
#include "Engine/World.h"
#include "GameFramework/ProjectileMovementComponent.h"
#include "Net/UnrealNetwork.h"

AArcanumProjectile::AArcanumProjectile()
{
	PrimaryActorTick.bCanEverTick = true;
	bReplicates = true;
	SetReplicateMovement(true);

	Collision = CreateDefaultSubobject<USphereComponent>(TEXT("Collision"));
	Collision->InitSphereRadius(15.f);
	Collision->SetCollisionEnabled(ECollisionEnabled::QueryOnly);
	Collision->SetCollisionObjectType(ECC_ArcanumProjectile);
	Collision->SetCollisionResponseToAllChannels(ECR_Block);
	Collision->SetCollisionResponseToChannel(ECC_Pawn, ECR_Overlap);
	Collision->SetCollisionResponseToChannel(ECC_ArcanumProjectile, ECR_Ignore);
	Collision->SetCollisionResponseToChannel(ECC_Camera, ECR_Ignore);
	Collision->SetCollisionResponseToChannel(ECC_Visibility, ECR_Ignore);
	Collision->SetGenerateOverlapEvents(true);
	SetRootComponent(Collision);

	Movement = CreateDefaultSubobject<UProjectileMovementComponent>(TEXT("Movement"));
	Movement->UpdatedComponent = Collision;
	Movement->ProjectileGravityScale = 0.f;
	Movement->bRotationFollowsVelocity = true;
	Movement->bShouldBounce = false;
}

void AArcanumProjectile::GetLifetimeReplicatedProps(TArray<FLifetimeProperty>& OutLifetimeProps) const
{
	Super::GetLifetimeReplicatedProps(OutLifetimeProps);
	DOREPLIFETIME(AArcanumProjectile, SchoolTag);
}

void AArcanumProjectile::InitProjectile(const FArcanumProjectileParams& InParams)
{
	Params = InParams;
	SchoolTag = InParams.SchoolTag;

	Movement->InitialSpeed = Params.SpeedCm;
	Movement->MaxSpeed = Params.SpeedCm;

	if (AActor* Target = Params.HomingTarget.Get())
	{
		Movement->bIsHomingProjectile = true;
		Movement->HomingTargetComponent = Target->GetRootComponent();
		Movement->HomingAccelerationMagnitude = Params.HomingAccelerationCm;
	}
}

void AArcanumProjectile::BeginPlay()
{
	Super::BeginPlay();
	SpawnLocation = GetActorLocation();

	if (AActor* InstigatorActor = GetInstigator())
	{
		Collision->IgnoreActorWhenMoving(InstigatorActor, true);
	}

	if (HasAuthority())
	{
		Collision->OnComponentBeginOverlap.AddDynamic(this, &AArcanumProjectile::OnSphereOverlap);
		Collision->OnComponentHit.AddDynamic(this, &AArcanumProjectile::OnSphereHit);
	}
}

void AArcanumProjectile::Tick(float DeltaSeconds)
{
	Super::Tick(DeltaSeconds);
	if (!HasAuthority() || bFinished)
	{
		return;
	}

	// "Ima" dos teleguiados: acerto garantido a ~0,6 m da superficie do alvo.
	if (AActor* Target = Params.HomingTarget.Get())
	{
		const float Reach = Params.MagnetRadiusCm + Target->GetSimpleCollisionRadius();
		if (FVector::DistSquared(GetActorLocation(), Target->GetActorLocation()) <= FMath::Square(Reach)
			&& ArcanumTargeting::IsValidHostileTarget(GetInstigator(), Target))
		{
			HitActor(Target, Target->GetActorLocation());
			return;
		}
	}

	if (FVector::DistSquared(SpawnLocation, GetActorLocation()) >= FMath::Square(Params.MaxRangeCm))
	{
		FinishAt(GetActorLocation());
	}
}

void AArcanumProjectile::OnSphereOverlap(UPrimitiveComponent* OverlappedComponent, AActor* OtherActor,
	UPrimitiveComponent* OtherComp, int32 OtherBodyIndex, bool bFromSweep, const FHitResult& SweepResult)
{
	if (!bFinished && ArcanumTargeting::IsValidHostileTarget(GetInstigator(), OtherActor))
	{
		HitActor(OtherActor, bFromSweep ? FVector(SweepResult.ImpactPoint) : GetActorLocation());
	}
}

void AArcanumProjectile::OnSphereHit(UPrimitiveComponent* HitComponent, AActor* OtherActor, UPrimitiveComponent* OtherComp,
	FVector NormalImpulse, const FHitResult& Hit)
{
	// Geometria do mundo bloqueia o projetil.
	if (!bFinished)
	{
		FinishAt(Hit.ImpactPoint);
	}
}

void AArcanumProjectile::HitActor(AActor* Target, const FVector& ImpactPoint)
{
	if (AlreadyHit.Contains(Target))
	{
		return;
	}
	AlreadyHit.Add(Target);
	ApplyEffectsTo(Target);

	if (AlreadyHit.Num() >= FMath::Max(Params.MaxHits, 1))
	{
		FinishAt(ImpactPoint);
	}
}

void AArcanumProjectile::ApplyEffectsTo(AActor* Target)
{
	ArcanumTargeting::ApplySpecToActor(Params.DamageSpec, Target);
	if (Params.ProcSpec.IsValid() && FMath::FRand() < Params.ProcChance)
	{
		ArcanumTargeting::ApplySpecToActor(Params.ProcSpec, Target, Params.ProcStateTag);
	}
}

void AArcanumProjectile::Explode(const FVector& Location)
{
	if (Params.ExplosionRadiusCm <= 0.f)
	{
		return;
	}

	FCollisionQueryParams QueryParams(SCENE_QUERY_STAT(ArcanumProjectileExplosion), false, this);
	TArray<FOverlapResult> Overlaps;
	GetWorld()->OverlapMultiByObjectType(Overlaps, Location, FQuat::Identity, FCollisionObjectQueryParams(ECC_Pawn),
		FCollisionShape::MakeSphere(Params.ExplosionRadiusCm), QueryParams);

	for (const FOverlapResult& Overlap : Overlaps)
	{
		AActor* Target = Overlap.GetActor();
		if (Target && !AlreadyHit.Contains(Target) && ArcanumTargeting::IsValidHostileTarget(GetInstigator(), Target))
		{
			AlreadyHit.Add(Target);
			ApplyEffectsTo(Target);
		}
	}
}

void AArcanumProjectile::FinishAt(const FVector& Location)
{
	if (bFinished)
	{
		return;
	}
	bFinished = true;

	Explode(Location);

	if (Params.ImpactCueTag.IsValid() && Params.DamageSpec.IsValid())
	{
		if (UAbilitySystemComponent* SourceASC = Params.DamageSpec.Data->GetContext().GetInstigatorAbilitySystemComponent())
		{
			FGameplayCueParameters CueParams;
			CueParams.Location = Location;
			CueParams.Instigator = GetInstigator();
			CueParams.EffectCauser = this;
			CueParams.AggregatedSourceTags.AddTag(SchoolTag);
			SourceASC->ExecuteGameplayCue(Params.ImpactCueTag, CueParams);
		}
	}

	Destroy();
}
