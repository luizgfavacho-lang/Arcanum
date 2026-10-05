# Reimporta Data/*.csv para DataTables e sincroniza os Data Assets de magia.
# Rode apos editar CSV (o editor deve estar FECHADO para salvar os assets).
. "$PSScriptRoot/Common.ps1"

& (Get-Python) (Join-Path $PSScriptRoot "validate_data.py")
if ($LASTEXITCODE -ne 0) { Write-Host "IMPORT ABORTADO: dados invalidos"; exit 1 }

$editor = Get-EditorCmd (Get-EngineRoot)
$log = Join-Path $LogDir "ImportData.log"
$script = Join-Path $PSScriptRoot "Python/import_data.py"

& $editor $Project -run=pythonscript "-script=$script" -unattended -nopause -nosplash -nullrhi "-abslog=$log" *> $null
Show-Filtered $log '(\[ImportData\]|Error:)' 30
