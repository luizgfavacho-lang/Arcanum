using UnrealBuildTool;

// Framework de magia: GAS (atributos, abilities base, efeitos, calculo de dano),
// dados (Data Assets / linhas de DataTable) e matematica de balanceamento testavel.
public class ArcanumCore : ModuleRules
{
	public ArcanumCore(ReadOnlyTargetRules Target) : base(Target)
	{
		PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;

		PublicDependencyModuleNames.AddRange(new string[]
		{
			"Core",
			"CoreUObject",
			"Engine",
			"GameplayAbilities",
			"GameplayTags",
			"GameplayTasks",
			"DeveloperSettings",
			"AIModule", // IGenericTeamAgentInterface (hostilidade)
			"NetCore"
		});
	}
}
