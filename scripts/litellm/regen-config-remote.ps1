# Regenerate config/litellm/config-remote.yaml from config.yaml (fgsrv06 deltas).
# Run from repo root: powershell -ExecutionPolicy Bypass -File scripts/litellm/regen-config-remote.ps1
$repo = Split-Path (Split-Path $PSScriptRoot)
$src = Join-Path $repo "config/litellm/config.yaml"
$dst = Join-Path $repo "config/litellm/config-remote.yaml"
Copy-Item $src $dst -Force
$c = [System.IO.File]::ReadAllText($dst)
$c = $c.Replace('http://192.168.0.200:11434', 'http://100.116.57.111:11434')
$c = $c.Replace('host: "192168.0.137"', 'host: "litellm-redis"') # no-op safeguard
$c = $c.Replace('host: "192.168.0.137"', 'host: "litellm-redis"')
$c = $c.Replace('# Redis Cache Configuration (CT137 - aglsrv1)', '# Redis Cache Configuration (local - litellm-redis, fgsrv06 Docker)')
$c = $c -replace "`r?`n  password: `"os.environ/REDIS_PASSWORD`"`r?`n", "`n"
[System.IO.File]::WriteAllText($dst, $c, [System.Text.UTF8Encoding]::new($false))
Write-Host "OK: $dst"
