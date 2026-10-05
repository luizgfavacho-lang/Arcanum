# Monta o conteudo de editor da fatia vertical (Docs/04-FatiaVertical.md §4) sem abrir o editor.
# Idempotente. O editor deve estar FECHADO (os assets sao salvos pelo commandlet).
#   1. Copia o manequim do template Third Person para Content/Characters (so o que a malha e o AnimBP usam)
#   2. setup_content.py (fase pre): input, Blueprints, Niagara, abilities, L_Sandbox, DefaultEngine.ini
#   3. import_data.py (via validacao): DataTables + DA_Spell_* (liga AbilityClass aos GA_* do passo 2)
#   4. setup_content.py (fase post): ProcStateTag, StartingSpells, EnemyRow (dependem do passo 3)
#   5. verify_content.py: confere tudo; sai com erro se algo falhar
. "$PSScriptRoot/Common.ps1"

$engine = Get-EngineRoot
$editor = Get-EditorCmd $engine

# --- 1. Manequim (mantem /Game/Characters/... do template: as referencias internas dependem do caminho)
$src = Join-Path $engine "Templates/TemplateResources/High/Characters/Content/Mannequins"
$dst = Join-Path $Root "Content/Characters/Mannequins"
$include = @("Meshes", "Materials", "Textures", "Rigs", "Anims/Unarmed")
$exclude = @("T_Manny_02_N.uasset", "CR_Mannequin_Procedural.uasset", "MM_Dash.uasset", "MM_WallJump.uasset", "Attack")
if (-not (Test-Path $src)) { Write-Host "ERRO: template nao encontrado em $src"; exit 2 }
$copied = 0
foreach ($dir in $include) {
    Get-ChildItem (Join-Path $src $dir) -Recurse -File -Filter *.uasset | Where-Object {
        $parts = $_.FullName.Substring($src.Length + 1) -split '[\\/]'
        -not ($parts | Where-Object { $exclude -contains $_ })
    } | ForEach-Object {
        $target = Join-Path $dst $_.FullName.Substring($src.Length + 1)
        if (-not (Test-Path $target)) {
            New-Item -ItemType Directory -Force -Path (Split-Path $target) | Out-Null
            Copy-Item $_.FullName $target
            $copied++
        }
    }
}
Write-Host "[Setup] Manequim: $copied arquivo(s) copiado(s) do template"

function Invoke-EditorPython([string]$Script, [string]$LogName, [string]$Pattern) {
    $log = Join-Path $LogDir "$LogName.log"
    & $editor $Project -run=pythonscript "-script=$(Join-Path $PSScriptRoot "Python/$Script")" -unattended -nopause -nosplash -nullrhi "-abslog=$log" *> $null
    $code = $LASTEXITCODE
    Show-Filtered $log $Pattern 60
    return $code
}

$failed = $false

# --- 2. Assets que precisam existir antes do import
$env:ARCANUM_SETUP_PHASE = "pre"
if ((Invoke-EditorPython "setup_content.py" "SetupContent" '(\[Setup\]|Error:|Warning: Python)') -ne 0) { $failed = $true }

# --- 3. Import dos CSV (valida antes)
& (Get-Python) (Join-Path $PSScriptRoot "validate_data.py")
if ($LASTEXITCODE -ne 0) { Write-Host "SETUP ABORTADO: dados invalidos"; exit 1 }
if ((Invoke-EditorPython "import_data.py" "ImportData" '(\[ImportData\]|Error:)') -ne 0) { $failed = $true }

# --- 4. Ligacoes que dependem dos assets importados
$env:ARCANUM_SETUP_PHASE = "post"
if ((Invoke-EditorPython "setup_content.py" "SetupContentPost" '(\[Setup\]|Error:|Warning: Python)') -ne 0) { $failed = $true }
Remove-Item Env:ARCANUM_SETUP_PHASE

# --- 5. Verificacao (so mostra falhas e o resumo)
if ((Invoke-EditorPython "verify_content.py" "VerifyContent" '(\[Verify\] (FALHOU|Resumo)|Error: (?!\[Verify\]))') -ne 0) { $failed = $true }

if ($failed) { Write-Host "SETUP COM FALHAS (logs em $LogDir)"; exit 1 }
Write-Host "SETUP OK"
