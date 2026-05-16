#Requires -Version 5.1
<#
.SYNOPSIS
  Aplica config do repo (apos git pull) em ~/.claude. Faz backup antes de sobrescrever.
#>

[CmdletBinding()]
param(
    [switch]$NoPull
)

$ErrorActionPreference = 'Stop'

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

if (-not (Test-Path $pluginsLive)) { New-Item -ItemType Directory -Path $pluginsLive | Out-Null }
foreach ($name in @('installed_plugins.json', 'known_marketplaces.json')) {
    $src = Join-Path $RepoRoot "plugins\$name"
    $dst = Join-Path $pluginsLive $name
    if (Test-Path $src) {
        Copy-Item $src $dst -Force
        Write-Host "  [OK] plugins/$name aplicado"
    }
}

Write-Host ""
Write-Host "==> Sync-pull concluido." -ForegroundColor Green
Write-Host "Reinicie o Claude Code para que ele recarregue settings, skills e re-clone marketplaces." -ForegroundColor Yellow
Write-Host "Plugins listados em ~/.claude/plugins/installed_plugins.json talvez precisem ser re-instalados via '/plugin install <nome>'." -ForegroundColor Yellow
} finally {
    Write-Host ""
    Read-Host "Pressione Enter para sair"
}
