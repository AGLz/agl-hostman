# doctor --fix com perfil Administrator (guest exec corre como SYSTEM).
$ErrorActionPreference = 'Continue'
$homeRoot = 'C:\Users\Administrator'
$clone = Join-Path $homeRoot 'src\openclaw'
$log = Join-Path $homeRoot 'wk45-doctor-fix.log'
$node = 'C:\Program Files\nodejs\node.exe'
$dist = Join-Path $clone 'dist\index.js'

$env:USERPROFILE = $homeRoot
$env:HOME = $homeRoot
$env:APPDATA = Join-Path $homeRoot 'AppData\Roaming'
$env:LOCALAPPDATA = Join-Path $homeRoot 'AppData\Local'
$env:PATH = "C:\Program Files\Git\bin;C:\Program Files\nodejs;$env:PATH"

Remove-Item $log -Force -EA SilentlyContinue
Set-Location $clone

"=== doctor --fix $(Get-Date -Format o) ===" | Out-File $log -Encoding utf8
& $node $dist doctor --fix --yes 2>&1 | Tee-Object -FilePath $log -Append
"=== exit $LASTEXITCODE ===" | Tee-Object -FilePath $log -Append
