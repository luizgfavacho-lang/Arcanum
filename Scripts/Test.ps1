# Roda os testes automatizados (Automation) sem abrir janela e imprime so falhas + resumo.
# Uso: pwsh Scripts/Test.ps1 [-Filter Arcanum.]
param([string]$Filter = "Arcanum.")
. "$PSScriptRoot/Common.ps1"

# Dados primeiro: e instantaneo e nao precisa da engine.
& (Get-Python) (Join-Path $PSScriptRoot "validate_data.py")
if ($LASTEXITCODE -ne 0) { Write-Host "TESTES ABORTADOS: dados invalidos"; exit 1 }

$editor = Get-EditorCmd (Get-EngineRoot)
$log = Join-Path $LogDir "Tests.log"
$report = Join-Path $Root "Saved/Automation"

& $editor $Project "-ExecCmds=Automation RunTests $Filter; Quit" -unattended -nopause -nosplash -nullrhi -nosound `
    "-TestExit=Automation Test Queue Empty" "-ReportExportPath=$report" "-abslog=$log" -log *> $null

$passed = (Select-String -Path $log -Pattern 'Test Completed\. Result=\{Success\}').Count
$failed = Select-String -Path $log -Pattern 'Test Completed\. Result=\{Fail' | ForEach-Object { $_.Line.Trim() }
Show-Filtered $log 'LogAutomationController: Error:' 30
$failed | ForEach-Object { Write-Host $_ }

Write-Host ("TESTES: {0} ok, {1} falha(s) - log: {2}" -f $passed, $failed.Count, $log)
if ($failed.Count -gt 0 -or $passed -eq 0) { exit 1 }
exit 0
