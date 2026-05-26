# Propaga Six Repos para harnesses Windows (aglwk45 / Verdent workstations).
# Uso (PowerShell como utilizador com U: mapeado):
#   cd U:\apps\dev\agl\agl-hostman
#   powershell -ExecutionPolicy Bypass -File .\scripts\skills\propagate-six-repos.ps1
#
# Variáveis de ambiente opcionais:
#   WK45_REPO_WIN — raiz do clone (default U:\apps\dev\agl\agl-hostman)
#   LLM_WIKI_WIN  — vault llm-wiki (default U:\apps\dev\agl\llm-wiki)

$ErrorActionPreference = "Stop"

$RepoRoot = if ($env:WK45_REPO_WIN) { $env:WK45_REPO_WIN } else { "U:\apps\dev\agl\agl-hostman" }
$LlmWiki = if ($env:LLM_WIKI_WIN) { $env:LLM_WIKI_WIN } else { "U:\apps\dev\agl\llm-wiki" }
$SyncSh = Join-Path $RepoRoot "scripts\skills\sync-six-repos.sh"
$VerifySh = Join-Path $RepoRoot "scripts\skills\verify-six-repos.sh"

Write-Host "=== propagate-six-repos (Windows) ===" -ForegroundColor Cyan
Write-Host "Repo: $RepoRoot"
Write-Host "Wiki: $LlmWiki"
Write-Host ""

if (-not (Test-Path $SyncSh)) {
    Write-Host "FAIL: sync-six-repos.sh em falta em $SyncSh" -ForegroundColor Red
    Write-Host "Confirma clone agl-hostman (U: = overpower) ou define WK45_REPO_WIN." -ForegroundColor Yellow
    exit 1
}

$Bash = $null
foreach ($candidate in @(
    "C:\Program Files\Git\bin\bash.exe",
    "C:\Program Files\Git\usr\bin\bash.exe"
)) {
    if (Test-Path $candidate) { $Bash = $candidate; break }
}

if (-not $Bash) {
    Write-Host "FAIL: Git Bash não encontrado — instalar Git for Windows." -ForegroundColor Red
    exit 1
}

$wikiForBash = ($LlmWiki -replace '\\', '/')
$repoForBash = ($RepoRoot -replace '\\', '/')

Write-Host "--- sync-six-repos (all) ---" -ForegroundColor Yellow
& $Bash -lc "cd '$repoForBash' && LLM_WIKI_DIR='$wikiForBash' ./scripts/skills/sync-six-repos.sh --repo all"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "--- verify-six-repos ---" -ForegroundColor Yellow
& $Bash -lc "cd '$repoForBash' && LLM_WIKI_DIR='$wikiForBash' ./scripts/skills/verify-six-repos.sh"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ""
Write-Host "OK propagate-six-repos Windows concluído." -ForegroundColor Green
Write-Host "Nota: Obsidian CLI requer Obsidian Desktop 1.12+ no Windows." -ForegroundColor Gray
