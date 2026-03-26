# Empacota ~/.openclaw da aglwk45 para aplicar no agldv03 (skills, workspaces, agentes, etc.).
# Executar na VM Windows (aglwk45), na raiz do repo ou qualquer pasta:
#   powershell -ExecutionPolicy Bypass -File scripts/openclaw/pack-openclaw-for-agldv03.ps1
# Saida: Desktop\openclaw-wk45-for-agldv03-<timestamp>.tgz
# Copiar para agldv03 e correr: bash scripts/openclaw/apply-wk45-bundle-on-agldv03.sh /caminho/arquivo.tgz

$ErrorActionPreference = 'Stop'
$homeOc = Join-Path $env:USERPROFILE '.openclaw'
if (-not (Test-Path -LiteralPath $homeOc)) {
    Write-Error "Pasta nao encontrada: $homeOc"
}
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$out = Join-Path ([Environment]::GetFolderPath('Desktop')) "openclaw-wk45-for-agldv03-$stamp.tgz"

# Excluir browser (Chrome do OpenClaw: locks/permissoes) e logs (grandes); alinhar com vm104_guest_pack_openclaw.py
Push-Location $env:USERPROFILE
try {
    & tar.exe -czf $out --exclude='.openclaw/logs' --exclude='.openclaw/browser' '.openclaw'
    if ($LASTEXITCODE -ne 0) {
        throw "tar.exe exit $LASTEXITCODE"
    }
}
finally {
    Pop-Location
}

if (-not (Test-Path -LiteralPath $out)) {
    Write-Error "Falha ao criar $out"
}
Write-Host "OK: $out"
Write-Host "Proximo passo (exemplo): scp `"$out`" root@100.94.221.87:/tmp/"
Write-Host "Ou via Proxmox (AGLSRV1 + qemu guest): bash scripts/openclaw/sync-agldv03-openclaw-from-wk45-qemu.sh"
