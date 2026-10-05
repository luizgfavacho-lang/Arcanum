# Compila o projeto e imprime SO erros, avisos de codigo e o resultado.
# Uso: pwsh Scripts/Build.ps1 [-Target ArcanumEditor] [-Config Development]
param(
    [string]$Target = "ArcanumEditor",
    [string]$Config = "Development"
)
. "$PSScriptRoot/Common.ps1"

$engine = Get-EngineRoot
$platform = Get-HostPlatform
$log = Join-Path $LogDir "Build.log"

$batch = if ($platform -eq "Win64") { Join-Path $engine "Engine/Build/BatchFiles/Build.bat" }
         elseif ($platform -eq "Mac") { Join-Path $engine "Engine/Build/BatchFiles/Mac/Build.sh" }
         else { Join-Path $engine "Engine/Build/BatchFiles/Linux/Build.sh" }

& $batch $Target $platform $Config "-Project=$Project" -WaitMutex -NoHotReloadFromIDE *> $log
$code = $LASTEXITCODE

# error C2065 / warning C4996 (MSVC), file.cpp:10: error (clang), UHT/UBT errors.
Show-Filtered $log '(\berror\b|warning C\d+|: warning:|Error:|Result: )' 40
Write-Host ("BUILD {0} ({1} {2} {3}) - log: {4}" -f ($(if ($code -eq 0) { "OK" } else { "FALHOU" })), $Target, $platform, $Config, $log)
exit $code
