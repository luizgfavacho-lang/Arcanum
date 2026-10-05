using UnrealBuildTool;

public class ArcanumTarget : TargetRules
{
	public ArcanumTarget(TargetInfo Target) : base(Target)
	{
		Type = TargetType.Game;
		DefaultBuildSettings = BuildSettingsVersion.Latest;
		IncludeOrderVersion = EngineIncludeOrderVersion.Latest;
		ExtraModuleNames.AddRange(new string[] { "ArcanumCore", "Arcanum" });
	}
}
