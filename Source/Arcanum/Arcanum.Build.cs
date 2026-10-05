using UnrealBuildTool;

// Modulo do jogo: personagens, controle, input, modo de jogo. Depende do ArcanumCore.
public class Arcanum : ModuleRules
{
	public Arcanum(ReadOnlyTargetRules Target) : base(Target)
	{
		PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;

		PublicDependencyModuleNames.AddRange(new string[]
		{
			"Core",
			"CoreUObject",
			"Engine",
			"InputCore",
			"EnhancedInput",
			"GameplayAbilities",
			"GameplayTags",
			"GameplayTasks",
			"AIModule",
			"ArcanumCore"
		});
	}
}
