#include "Modules/ModuleManager.h"
#include "Internationalization/StringTableRegistry.h"
#include "Misc/Paths.h"

/**
 * Registra as String Tables carregadas direto de CSV (Content/Text/*.csv), sem asset binario.
 * Textos ficam versionados em texto e prontos para localizacao.
 */
class FArcanumCoreModule : public FDefaultModuleImpl
{
public:
	virtual void StartupModule() override
	{
		LOCTABLE_FROMFILE_GAME("ST_Spells", "ArcanumSpells", "Text/ST_Spells.csv");
	}

	virtual void ShutdownModule() override
	{
		FStringTableRegistry::Get().UnregisterStringTable("ST_Spells");
	}
};

IMPLEMENT_MODULE(FArcanumCoreModule, ArcanumCore);
