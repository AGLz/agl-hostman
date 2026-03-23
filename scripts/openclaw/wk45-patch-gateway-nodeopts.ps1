# Suprime o aviso Node DEP0040 (punycode deprecado) no arranque do gateway OpenClaw — Windows / wk45.
# Uso (PowerShell como utilizador que corre o gateway, ex. Administrator):
#   cd <raiz-do-repo-agl-hostman>   # onde existem as pastas scripts\, src\, etc.
#   powershell -ExecutionPolicy Bypass -File .\scripts\openclaw\wk45-patch-gateway-nodeopts.ps1
# Na wk45 com U: = overpower (espelho de /mnt/overpower/...):
#   cd U:\apps\dev\agl\agl-hostman
# Ou caminho absoluto:
#   powershell -ExecutionPolicy Bypass -File "U:\apps\dev\agl\agl-hostman\scripts\openclaw\wk45-patch-gateway-nodeopts.ps1"
#
# Reason: dependências ainda importam `punycode` core; correção definitiva é upstream (Node/OpenClaw).
# Node 18+: --disable-warning=DEP0040

param(
    [string] $GatewayCmd = "$env:USERPROFILE\.openclaw\gateway.cmd"
)

$marker = 'NODE_OPTIONS=--disable-warning=DEP0040'

if (-not (Test-Path $GatewayCmd)) {
    Write-Error "Ficheiro nao encontrado: $GatewayCmd"
    exit 1
}

$content = Get-Content -LiteralPath $GatewayCmd -Raw
if ($content -match [regex]::Escape('--disable-warning=DEP0040')) {
    Write-Host "Ja aplicado: $GatewayCmd"
    exit 0
}

Copy-Item -LiteralPath $GatewayCmd -Destination "$GatewayCmd.bak.nodeopts" -Force
$lines = Get-Content -LiteralPath $GatewayCmd
$out = New-Object System.Collections.Generic.List[string]
$inserted = $false
foreach ($line in $lines) {
    [void]$out.Add($line)
    if (-not $inserted -and $line.Trim() -eq '@echo off') {
        [void]$out.Add('rem AGL: suprime DEP0040 (punycode) ate dependencias atualizarem')
        [void]$out.Add('set "NODE_OPTIONS=%NODE_OPTIONS% --disable-warning=DEP0040"')
        $inserted = $true
    }
}
if (-not $inserted) {
    [void]$out.Insert(0, 'set "NODE_OPTIONS=%NODE_OPTIONS% --disable-warning=DEP0040"')
    [void]$out.Insert(0, 'rem AGL: NODE_OPTIONS para DEP0040')
}
Set-Content -LiteralPath $GatewayCmd -Value ($out -join "`r`n") -Encoding ascii
Write-Host "OK: $GatewayCmd (backup: .bak.nodeopts). Reinicie a tarefa OpenClaw Gateway ou openclaw gateway restart."
