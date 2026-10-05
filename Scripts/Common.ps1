# Funcoes compartilhadas pelos scripts. Requer a variavel de ambiente UE_ROOT
# (ex.: C:\Program Files\Epic Games\UE_5.5) apontando para a raiz da engine.

$script:Root = Split-Path -Parent $PSScriptRoot
$script:Project = Join-Path $script:Root "Arcanum.uproject"
$script:LogDir = Join-Path $script:Root "Saved/Logs"
New-Item -ItemType Directory -Force -Path $script:LogDir | Out-Null

function Get-EngineRoot {
    if (-not $env:UE_ROOT -or -not (Test-Path $env:UE_ROOT)) {
        Write-Host "ERRO: defina UE_ROOT com a pasta da engine (ex.: C:\Program Files\Epic Games\UE_5.5)."
        exit 2
    }
    return $env:UE_ROOT
}

function Get-HostPlatform {
    if ($PSVersionTable.PSEdition -eq "Desktop" -or $IsWindows) { return "Win64" }
    if ($IsMacOS) { return "Mac" }
    return "Linux"
}

function Get-EditorCmd([string]$Engine) {
    switch (Get-HostPlatform) {
        "Win64" { return Join-Path $Engine "Engine/Binaries/Win64/UnrealEditor-Cmd.exe" }
        "Mac"   { return Join-Path $Engine "Engine/Binaries/Mac/UnrealEditor.app/Contents/MacOS/UnrealEditor" }
        default { return Join-Path $Engine "Engine/Binaries/Linux/UnrealEditor" }
    }
}

# Imprime so as linhas que casam com $Pattern (no maximo $Max) e diz quantas foram omitidas.
function Show-Filtered([string]$LogPath, [string]$Pattern, [int]$Max = 40) {
    $hits = Select-String -Path $LogPath -Pattern $Pattern | ForEach-Object { $_.Line.Trim() } | Select-Object -Unique
    $hits | Select-Object -First $Max | ForEach-Object { Write-Host $_ }
    if ($hits.Count -gt $Max) { Write-Host "... (+$($hits.Count - $Max) linhas; log completo: $LogPath)" }
}

function Get-Python {
    foreach ($candidate in @("python3", "python", "py")) {
        if (Get-Command $candidate -ErrorAction SilentlyContinue) { return $candidate }
    }
    Write-Host "ERRO: Python 3 nao encontrado no PATH."
    exit 2
}
