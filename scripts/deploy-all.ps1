#Requires -Version 5.1
<#
.SYNOPSIS
  Commit (opcional) + push main + acompanha deploy web (Hetzner) e APK mobile.

.DESCRIPTION
  Pipeline FocoDev web+mobile:
    push main → Deploy to Hetzner (API/aluno/instrutor/admin)
             → Build Mobile Release (se mobile/** mudou)

.PARAMETER Message
  Mensagem de commit. Obrigatoria se houver alteracoes e -SkipCommit nao for usado.

.PARAMETER SkipCommit
  So faz push do que ja esta commitado (nao adiciona/commita).

.PARAMETER WebOnly
  Aguarda so o workflow Deploy to Hetzner.

.PARAMETER MobileOnly
  Aguarda so o workflow Build Mobile Release (nao faz push se nao houver mudancas mobile).

.PARAMETER NoWatch
  Push e sai sem aguardar Actions.

.PARAMETER ApiVersionUrl
  URL para checar versionCode apos o mobile (default academia.focodev.com.br).

.EXAMPLE
  .\scripts\deploy-all.ps1 -Message "Corrige X"

.EXAMPLE
  .\scripts\deploy-all.ps1 -SkipCommit
#>
param(
  [string]$Message = "",
  [switch]$SkipCommit,
  [switch]$WebOnly,
  [switch]$MobileOnly,
  [switch]$NoWatch,
  [string]$ApiVersionUrl = "https://academia.focodev.com.br/api/app/version"
)

$ErrorActionPreference = "Stop"
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $RepoRoot

# git escreve warnings em stderr; nao tratar como falha fatal
$GitErrorAction = $ErrorActionPreference

function Assert-Cmd([string]$Name) {
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Comando '$Name' nao encontrado no PATH."
  }
}

function Get-ChangedPaths {
  $prev = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    $staged = @(git diff --cached --name-only 2>$null)
    $unstaged = @(git diff --name-only 2>$null)
    $untracked = @(git ls-files --others --exclude-standard 2>$null)
  } finally {
    $ErrorActionPreference = $prev
  }
  @($staged) + @($unstaged) + @($untracked) | Where-Object { $_ } | Sort-Object -Unique
}

Assert-Cmd git
Assert-Cmd gh

$branch = (git rev-parse --abbrev-ref HEAD).Trim()
if ($branch -ne "main") {
  Write-Warning "Branch atual e '$branch' (pipeline de producao usa main)."
}

$paths = @(Get-ChangedPaths)
$hasChanges = $paths.Count -gt 0
$mobileTouched = $false

if (-not $SkipCommit -and $hasChanges) {
  if ([string]::IsNullOrWhiteSpace($Message)) {
    throw "Ha alteracoes locais. Passe -Message '...' ou use -SkipCommit."
  }

  # Nao versionar credenciais de teste
  $exclude = @("scripts/test-login.json", "scripts/test-admin-login.json", ".env")
  $toAdd = $paths | Where-Object {
    $p = $_ -replace "\\", "/"
    $exclude -notcontains $p -and $p -notmatch '\.env$'
  }

  if ($toAdd.Count -eq 0) {
    Write-Host "==> Nada seguro para commitar (so arquivos excluidos)."
  } else {
    Write-Host "==> Commit: $($toAdd.Count) arquivo(s)"
    git add -- $toAdd
    git commit -m $Message
  }
} elseif ($SkipCommit) {
  Write-Host "==> SkipCommit: nao criando commit"
} else {
  Write-Host "==> Working tree limpa"
}

# Detecta se o ultimo commit (ou push) toca mobile
$ahead = git rev-list --count "origin/main..HEAD" 2>$null
if (-not $ahead) { $ahead = "0" }
$range = if ([int]$ahead -gt 0) { "origin/main..HEAD" } else { "HEAD" }
$diffNames = @(git diff --name-only $range 2>$null)
if ($diffNames.Count -eq 0) {
  $diffNames = @(git show --name-only --pretty="" HEAD 2>$null)
}
$mobileTouched = $diffNames | Where-Object { $_ -match '^(mobile/|\.github/workflows/build-mobile-release\.yml)' } | Select-Object -First 1

Write-Host "==> Sync com origin/main"
git pull --rebase origin main
Write-Host "==> Push origin main"
git push origin main

if ($NoWatch) {
  Write-Host "Push feito. Use: gh run list --limit 5"
  exit 0
}

Start-Sleep -Seconds 4

function Wait-Workflow([string]$WorkflowFile, [string]$Label, [int]$TimeoutMin = 45) {
  Write-Host "==> Aguardando $Label ($WorkflowFile)..."
  $runs = gh run list --workflow $WorkflowFile --branch main --limit 1 --json databaseId,status,conclusion,url,displayTitle,createdAt | ConvertFrom-Json
  if (-not $runs -or $runs.Count -eq 0) {
    Write-Warning "Nenhuma run encontrada para $WorkflowFile"
    return $null
  }
  $id = $runs[0].databaseId
  Write-Host "    Run $id — $($runs[0].displayTitle)"
  Write-Host "    $($runs[0].url)"
  gh run watch $id --exit-status
  if ($LASTEXITCODE -ne 0) {
    throw "$Label falhou (run $id). Logs: gh run view $id --log-failed"
  }
  Write-Host "==> $Label OK"
  return $id
}

if (-not $MobileOnly) {
  Wait-Workflow "deploy-hetzner.yml" "Deploy web (Hetzner)"
}

$shouldMobile = -not $WebOnly -and ($MobileOnly -or $mobileTouched)
if ($shouldMobile) {
  Wait-Workflow "build-mobile-release.yml" "Build/publish APK"
  try {
    Write-Host "==> Versao publicada:"
    $ver = curl.exe -fsS $ApiVersionUrl
    Write-Host $ver
  } catch {
    Write-Warning "Nao foi possivel ler $ApiVersionUrl"
  }
} elseif (-not $WebOnly) {
  Write-Host "==> Sem mudancas em mobile/** — APK nao sera rebuildado."
  Write-Host "    Para forcar: gh workflow run build-mobile-release.yml"
}

Write-Host ""
Write-Host "Deploy concluido."
