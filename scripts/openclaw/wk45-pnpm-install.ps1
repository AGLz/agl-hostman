$ErrorActionPreference = 'Continue'
$homeRoot = 'C:\Users\Administrator'
$log = Join-Path $homeRoot 'pnpm-install.log'
$env:USERPROFILE = $homeRoot
$env:HOME = $homeRoot
$env:CI = 'true'
$env:PATH = "C:\Program Files\Git\bin;C:\Program Files\nodejs;$env:PATH"
Set-Location (Join-Path $homeRoot 'src\openclaw')
Remove-Item $log -Force -EA SilentlyContinue
"=== pnpm install $(Get-Date -Format o) ===" | Out-File $log -Encoding utf8
pnpm install 2>&1 | Tee-Object -FilePath $log -Append
"=== exit $LASTEXITCODE $(Get-Date -Format o) ===" | Tee-Object -FilePath $log -Append
if (Test-Path (Join-Path (Get-Location) 'node_modules\@openclaw\fs-safe')) {
  'OK fs-safe present' | Tee-Object -FilePath $log -Append
} else {
  'MISSING fs-safe' | Tee-Object -FilePath $log -Append
}
