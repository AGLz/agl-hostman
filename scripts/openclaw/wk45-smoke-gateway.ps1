$ErrorActionPreference = 'Continue'
$homeRoot = 'C:\Users\Administrator'
$node = 'C:\Program Files\nodejs\node.exe'
$dist = Join-Path $homeRoot 'src\openclaw\dist\index.js'
$out = Join-Path $homeRoot 'wk45-smoke-stdout.log'
$err = Join-Path $homeRoot 'wk45-smoke-stderr.log'
$env:USERPROFILE = $homeRoot
$env:HOME = $homeRoot
$env:APPDATA = Join-Path $homeRoot 'AppData\Roaming'
$env:LOCALAPPDATA = Join-Path $homeRoot 'AppData\Local'
Remove-Item $out, $err, (Join-Path $homeRoot 'wk45-smoke-result.txt') -Force -EA SilentlyContinue
$p = Start-Process -FilePath $node -ArgumentList @($dist, 'gateway', '--port', '18789') -WorkingDirectory (Split-Path $dist) -RedirectStandardOutput $out -RedirectStandardError $err -PassThru -WindowStyle Hidden
Start-Sleep 20
if (-not $p.HasExited) { Stop-Process -Id $p.Id -Force -EA SilentlyContinue }
"exit=$($p.ExitCode)" | Out-File (Join-Path $homeRoot 'wk45-smoke-result.txt') -Encoding utf8
Get-Content $err -Tail 40 -EA SilentlyContinue | Out-File (Join-Path $homeRoot 'wk45-smoke-result.txt') -Append -Encoding utf8
