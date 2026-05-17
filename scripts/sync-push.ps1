#Requires -Version 5.1
<#
.SYNOPSIS
  Espelha ~/.claude (partes essenciais) para este repo, comita e da push.
  Normaliza caminhos absolutos (C:\Users\<user>\.claude\...) para o token
  portatil "%USERPROFILE%\.claude\..." antes de salvar no repo, para que
  outras maquinas (com outro usuario Windows) consigam aplicar via sync-pull.
#>

[CmdletBinding()]
param(
    [switch]$NoPush,
    [switch]$NoCommit
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

function ConvertTo-PortablePathJson {
    <#
      Recebe o conteudo (string) de um JSON de plugin do Claude e substitui
      qualquer ocorrencia de "<DRIVE>:\\Users\\<usuario>\\.claude" pelo
      token portatil "%USERPROFILE%\\.claude".
      Operacao em texto (regex) para preservar o formato original do arquivo.
    #>
    param([Parameter(Mandatory)] [string]$JsonText)
    # Em JSON, backslashes vem escapados como "\\\\" no source — mas no .NET
    # string runtime sao "\\". Padrao casa: <letra>:\Users\<algo-sem-barra>\.claude
    $pattern = '[A-Za-z]:\\\\Users\\\\[^\\\\""]+\\\\\.claude'
    return [regex]::Replace($JsonText, $pattern, '%USERPROFILE%\\.claude')
}

try {

$RepoRoot   = Split-Path -Parent $PSScriptRoot
$ClaudeHome = Join-Path $env:USERPROFILE '.claude'

if (-not (Test-Path $ClaudeHome)) {
    throw "Pasta ~/.claude nao encontrada em '$ClaudeHome'."
}

Write-Host "==> Sync-push: $ClaudeHome -> $RepoRoot" -ForegroundColor Cyan

# --- 1) settings.json ---
$srcSettings = Join-Path $ClaudeHome 'settings.json'
$dstSettings = Join-Path $RepoRoot  'config\settings.json'
if (Test-Path $srcSettings) {
    Copy-Item $srcSettings $dstSettings -Force
    Write-Host "  [OK] config/settings.json"
} else {
    Write-Warning "settings.json nao encontrado, pulando."
}

# --- 2) CLAUDE.md global ---
$srcClaudeMd = Join-Path $ClaudeHome 'CLAUDE.md'
$dstClaudeMd = Join-Path $RepoRoot  'config\CLAUDE.md'
if (Test-Path $srcClaudeMd) {
    Copy-Item $srcClaudeMd $dstClaudeMd -Force
    Write-Host "  [OK] config/CLAUDE.md"
} else {
    Write-Host "  [--] CLAUDE.md global ausente, pulando."
}

# --- 3) skills ---
$srcSkills = Join-Path $ClaudeHome 'skills'
$dstSkills = Join-Path $RepoRoot  'skills'
if (Test-Path $srcSkills) {
    if (-not (Test-Path $dstSkills)) { New-Item -ItemType Directory -Path $dstSkills | Out-Null }
    # robocopy /MIR espelha; /XD exclui caches; /NFL /NDL /NJH /NJS deixa o output limpo
    & robocopy $srcSkills $dstSkills /MIR /XD '.git' '__pycache__' 'node_modules' /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy falhou (exit=$LASTEXITCODE)." }
    Write-Host "  [OK] skills/ espelhada"
} else {
    Write-Host "  [--] skills/ ausente, pulando."
}

# --- 4) plugins (so manifestos, nao caches/marketplaces) ---
#     Normaliza caminhos absolutos para %USERPROFILE% antes de salvar no repo.
$pluginsDst = Join-Path $RepoRoot 'plugins'
if (-not (Test-Path $pluginsDst)) { New-Item -ItemType Directory -Path $pluginsDst | Out-Null }
foreach ($name in @('installed_plugins.json', 'known_marketplaces.json')) {
    $src = Join-Path $ClaudeHome "plugins\$name"
    $dst = Join-Path $pluginsDst $name
    if (-not (Test-Path $src)) {
        Write-Host "  [--] plugins/$name ausente, pulando."
        continue
    }
    $raw       = Get-Content -Raw -LiteralPath $src
    $portable  = ConvertTo-PortablePathJson -JsonText $raw
    Write-Utf8NoBom -Path $dst -Content $portable
    Write-Host "  [OK] plugins/$name (caminhos -> %USERPROFILE%)"
}

# --- 5) git: status, commit e push ---
Push-Location $RepoRoot
try {
    if (-not (Test-Path (Join-Path $RepoRoot '.git'))) {
        Write-Warning "Repo nao inicializado (.git ausente). Pulando commit/push."
        return
    }

    $changes = git status --porcelain
    if (-not $changes) {
        Write-Host "==> Sem mudancas para commitar." -ForegroundColor Green
        return
    }

    Write-Host "==> Mudancas detectadas:" -ForegroundColor Yellow
    Write-Host $changes

    if ($NoCommit) {
        Write-Host "==> -NoCommit: deixando staged sem commitar." -ForegroundColor Yellow
        git add -A
        return
    }

    git add -A
    $msg = "sync from $($env:COMPUTERNAME) at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    git commit -m $msg
    Write-Host "==> Commit criado: $msg" -ForegroundColor Green

    if ($NoPush) {
        Write-Host "==> -NoPush: pulando git push." -ForegroundColor Yellow
        return
    }

    $hasRemote = git remote
    if (-not $hasRemote) {
        Write-Warning "Nenhum remote configurado. Adicione com: git remote add origin <url>"
        return
    }

    git push
    Write-Host "==> Push concluido." -ForegroundColor Green
} finally {
    Pop-Location
}
} finally {
    Write-Host ""
    Read-Host "Pressione Enter para sair"
}
