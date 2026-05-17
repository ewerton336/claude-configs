#Requires -Version 5.1
<#
.SYNOPSIS
  Aplica config do repo (apos git pull) em ~/.claude. Faz backup antes de sobrescrever.
  Os JSONs de plugin do repo usam o token portatil "%USERPROFILE%\.claude\..."
  no lugar de caminhos absolutos. Este script substitui o token pelo perfil do
  usuario atual antes de aplicar, e tenta auto-resolver versoes de plugin que
  nao existam no cache local (ex: registrado 12.4.9, instalado 13.2.0).
#>

[CmdletBinding()]
param(
    [switch]$NoPull
)

$ErrorActionPreference = 'Stop'

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory)] [string]$Path,
        [Parameter(Mandatory)] [string]$Content
    )
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $enc)
}

function ConvertFrom-PortablePathJson {
    <#
      Substitui o token portatil "%USERPROFILE%\\.claude" pelo caminho real
      do usuario atual, ja com escape JSON (\\). Defensivamente, tambem
      reescreve qualquer "<DRIVE>:\\Users\\<outro>\\.claude" que tenha
      ficado para tras (manifesto vindo de versao antiga do script).
    #>
    param([Parameter(Mandatory)] [string]$JsonText)
    $userHome        = Join-Path $env:USERPROFILE '.claude'
    $userHomeEscaped = $userHome -replace '\\', '\\'   # escape para JSON

    # 1) %USERPROFILE%\.claude  ->  C:\Users\ewert\.claude (escapado)
    $out = $JsonText -replace [regex]::Escape('%USERPROFILE%\\.claude'), $userHomeEscaped

    # 2) Fallback: qualquer C:\\Users\\<outro>\\.claude ainda presente
    $pattern = '[A-Za-z]:\\\\Users\\\\[^\\\\"]+\\\\\.claude'
    $out = [regex]::Replace($out, $pattern, $userHomeEscaped)

    return $out
}

function Resolve-PluginInstallDir {
    <#
      Dado o installPath registrado, devolve um hashtable com:
        Path    = caminho que existe no disco (ou $null se nao deu)
        Version = string de versao correspondente (pode ser a registrada ou nova)
        Changed = $true se a versao foi alterada
      Estrategia:
        - Se o path registrado existir, usa.
        - Senao, lista o diretorio pai e pega: a versao registrada > 'unknown'
          > maior versao SemVer-like > primeiro alfabeticamente.
    #>
    param(
        [Parameter(Mandatory)] [string]$InstallPath,
        [Parameter(Mandatory)] [string]$RegisteredVersion
    )
    if (Test-Path -LiteralPath $InstallPath) {
        return @{ Path = $InstallPath; Version = $RegisteredVersion; Changed = $false }
    }
    $parent = Split-Path -Parent $InstallPath
    if (-not (Test-Path -LiteralPath $parent)) {
        return @{ Path = $null; Version = $RegisteredVersion; Changed = $false }
    }
    $dirs = @(Get-ChildItem -LiteralPath $parent -Directory -ErrorAction SilentlyContinue)
    if ($dirs.Count -eq 0) {
        return @{ Path = $null; Version = $RegisteredVersion; Changed = $false }
    }
    # ordena por SemVer-like (descending), com nao parseaveis no fim
    $sorted = $dirs | Sort-Object -Property @{Expression = {
        $v = $null
        if ([version]::TryParse(($_.Name -replace '^v',''), [ref]$v)) { $v } else { [version]'0.0.0' }
    }; Descending = $true}, @{Expression = { $_.Name }; Descending = $true}
    $best = $sorted[0]
    return @{ Path = $best.FullName; Version = $best.Name; Changed = $true }
}

function Repair-InstalledPluginsManifest {
    <#
      Le ~/.claude/plugins/installed_plugins.json, valida cada installPath
      contra o disco e ajusta versao/caminho quando necessario. Reescreve
      o arquivo apenas se algo mudou.
    #>
    param([Parameter(Mandatory)] [string]$ManifestPath)
    if (-not (Test-Path -LiteralPath $ManifestPath)) { return }

    $json = Get-Content -Raw -LiteralPath $ManifestPath | ConvertFrom-Json
    if (-not $json.plugins) { return }

    $changed = $false
    foreach ($prop in $json.plugins.PSObject.Properties) {
        foreach ($entry in $prop.Value) {
            if (-not $entry.installPath) { continue }
            $res = Resolve-PluginInstallDir -InstallPath $entry.installPath -RegisteredVersion $entry.version
            if ($null -eq $res.Path) {
                Write-Warning "  [!!] $($prop.Name): nenhuma versao encontrada no cache (esperado: $($entry.installPath)). Rode '/plugin install' depois."
                continue
            }
            if ($res.Changed) {
                Write-Host "  [fix] $($prop.Name): $($entry.version) -> $($res.Version) (versao registrada nao existe no cache)" -ForegroundColor Yellow
                $entry.installPath = $res.Path
                $entry.version     = $res.Version
                $entry.lastUpdated = (Get-Date).ToUniversalTime().ToString("o")
                $changed = $true
            }
        }
    }
    if ($changed) {
        $out = $json | ConvertTo-Json -Depth 20
        Write-Utf8NoBom -Path $ManifestPath -Content $out
        Write-Host "  [OK] installed_plugins.json reescrito com versoes corrigidas."
    }
}

try {

$RepoRoot   = Split-Path -Parent $PSScriptRoot
$ClaudeHome = Join-Path $env:USERPROFILE '.claude'

if (-not (Test-Path $ClaudeHome)) {
    throw "Pasta ~/.claude nao encontrada em '$ClaudeHome'. Instale o Claude Code primeiro."
}

Write-Host "==> Sync-pull: $RepoRoot -> $ClaudeHome" -ForegroundColor Cyan

# --- 1) git pull ---
if (-not $NoPull) {
    Push-Location $RepoRoot
    try {
        if (Test-Path (Join-Path $RepoRoot '.git')) {
            git pull --ff-only
        } else {
            Write-Warning ".git ausente, pulando git pull."
        }
    } finally {
        Pop-Location
    }
}

# --- 2) backup ---
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupDir = Join-Path $ClaudeHome "backups\sync-pull-$timestamp"
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

foreach ($rel in @('settings.json', 'CLAUDE.md')) {
    $p = Join-Path $ClaudeHome $rel
    if (Test-Path $p) { Copy-Item $p (Join-Path $backupDir $rel) -Force }
}
$skillsLive = Join-Path $ClaudeHome 'skills'
if (Test-Path $skillsLive) {
    & robocopy $skillsLive (Join-Path $backupDir 'skills') /MIR /NFL /NDL /NJH /NJS /NP | Out-Null
}
$pluginsLive = Join-Path $ClaudeHome 'plugins'
if (Test-Path $pluginsLive) {
    foreach ($name in @('installed_plugins.json', 'known_marketplaces.json')) {
        $p = Join-Path $pluginsLive $name
        if (Test-Path $p) { Copy-Item $p (Join-Path $backupDir $name) -Force }
    }
}
Write-Host "  [OK] backup em $backupDir" -ForegroundColor DarkGray

# --- 3) aplicar ---
$srcSettings = Join-Path $RepoRoot 'config\settings.json'
if (Test-Path $srcSettings) {
    Copy-Item $srcSettings (Join-Path $ClaudeHome 'settings.json') -Force
    Write-Host "  [OK] settings.json aplicado"
}

$srcClaudeMd = Join-Path $RepoRoot 'config\CLAUDE.md'
if (Test-Path $srcClaudeMd) {
    Copy-Item $srcClaudeMd (Join-Path $ClaudeHome 'CLAUDE.md') -Force
    Write-Host "  [OK] CLAUDE.md global aplicado"
}

$srcSkills = Join-Path $RepoRoot 'skills'
if (Test-Path $srcSkills) {
    if (-not (Test-Path $skillsLive)) { New-Item -ItemType Directory -Path $skillsLive | Out-Null }
    & robocopy $srcSkills $skillsLive /MIR /XD '.git' /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy falhou (exit=$LASTEXITCODE)." }
    Write-Host "  [OK] skills/ espelhada"
}

# Plugins: copia + reescreve com path do usuario atual + auto-resolve de versao.
if (-not (Test-Path $pluginsLive)) { New-Item -ItemType Directory -Path $pluginsLive | Out-Null }
foreach ($name in @('installed_plugins.json', 'known_marketplaces.json')) {
    $src = Join-Path $RepoRoot "plugins\$name"
    $dst = Join-Path $pluginsLive $name
    if (-not (Test-Path $src)) { continue }
    $raw      = Get-Content -Raw -LiteralPath $src
    $expanded = ConvertFrom-PortablePathJson -JsonText $raw
    Write-Utf8NoBom -Path $dst -Content $expanded
    Write-Host "  [OK] plugins/$name aplicado (%USERPROFILE% -> $env:USERPROFILE)"
}

# Tenta consertar versoes que nao existem mais no cache local
$installedManifest = Join-Path $pluginsLive 'installed_plugins.json'
if (Test-Path $installedManifest) {
    Repair-InstalledPluginsManifest -ManifestPath $installedManifest
}

Write-Host ""
Write-Host "==> Sync-pull concluido." -ForegroundColor Green
Write-Host "Reinicie o Claude Code para que ele recarregue settings, skills e re-clone marketplaces." -ForegroundColor Yellow
Write-Host "Plugins listados em ~/.claude/plugins/installed_plugins.json talvez precisem ser re-instalados via '/plugin install <nome>'." -ForegroundColor Yellow
} finally {
    Write-Host ""
    Read-Host "Pressione Enter para sair"
}
