#pragma once

#include "CoreMinimal.h"
#include "UObject/Interface.h"
#include "Data/ArcanumSpellModifiers.h"
#include "ArcanumSpellModifierSource.generated.h"

class UArcanumSpellDefinition;

UINTERFACE(MinimalAPI, meta = (CannotImplementInterfaceInBlueprint))
class UArcanumSpellModifierSource : public UInterface
{
	GENERATED_BODY()
};

/**
 * Implementado por componentes que alteram magias (runas do cajado, talentos, passiva, artefatos).
 * O ASC encontra todos os componentes do dono (PlayerState) e do avatar que implementam esta
 * interface e os consulta a cada conjuracao. Deve ser deterministico (roda no cliente e no servidor).
 */
class ARCANUMCORE_API IArcanumSpellModifierSource
{
	GENERATED_BODY()

public:
	virtual void ModifySpell(const UArcanumSpellDefinition& Spell, FArcanumSpellModifiers& InOutModifiers) const = 0;
};
