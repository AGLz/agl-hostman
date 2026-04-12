# Diagnostico / reparacao do gateway OpenClaw na aglwk45 (PowerShell como Administrator).
# Problema do script anterior: cmd.exe + ReadLine() na consola pode bloquear ou nao capturar erros do Node.
#
# Uso:
#   powershell -ExecutionPolicy Bypass -File .\wk45-diagnostics-gateway.ps1
#   powershell -ExecutionPolicy Bypass -File .\wk45-diagnostics-gateway.ps1 -Repair
#   powershell -ExecutionPolicy Bypass -File .\wk45-diagnostics-gateway.ps1 -CaptureSeconds 30
# Smoke usa porta 18790 por defeito para NAO colidir com a tarefa OpenClaw Gateway (18789).

param(
    [switch]$Repair,
    [int]$CaptureSeconds = 25,
    # Porta so para o teste smoke (tarefa real = 18789 em gateway.cmd)
    [int]$SmokePort = 18790,
    # Perfil real do OpenClaw (qm guest exec corre como SYSTEM; usar Administrator explicitamente)
    [string]$OpenClawUserProfile = ''
)

$ErrorActionPreference = 'Continue'

$homeRoot = if ($OpenClawUserProfile) {
    $OpenClawUserProfile
} elseif ($env:USERPROFILE -match 'systemprofile|Service Profile') {
    'C:\Users\Administrator'
} else {
    $env:USERPROFILE
}

function Import-OpenClawDotEnv {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return }
    Get-Content -LiteralPath $Path -ErrorAction SilentlyContinue | ForEach-Object {
        $line = $_.Trim()
        if ($line -match '^\s*#' -or $line -eq '') { return }
        $eq = $line.IndexOf('=')
        if ($eq -lt 1) { return }
        $k = $line.Substring(0, $eq).Trim() -replace '^(?i)export\s+', ''
        if ($k -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') { return }
        $v = $line.Substring($eq + 1).Trim()
        if (($v.StartsWith('"') -and $v.EndsWith('"')) -or ($v.StartsWith("'") -and $v.EndsWith("'"))) {
            $v = $v.Substring(1, $v.Length - 2)
        }
        Set-Item -Path "Env:$k" -Value $v
    }
}

$oc = Join-Path $homeRoot '.openclaw'
$gwCmd = Join-Path $oc 'gateway.cmd'
$node = 'C:\Program Files\nodejs\node.exe'
$dist = Join-Path $homeRoot 'src\openclaw\dist\index.js'
$logDir = Join-Path $env:TEMP 'openclaw'
$outLog = Join-Path $env:TEMP 'openclaw-gateway-stdout.log'
$errLog = Join-Path $env:TEMP 'openclaw-gateway-stderr.log'
$combined = Join-Path $env:TEMP 'openclaw-gateway-smoke.log'

Write-Host "=== Ambiente LiteLLM (.env -> processo) ===" 
Import-OpenClawDotEnv (Join-Path $oc 'litellm-gateway.env')
Import-OpenClawDotEnv (Join-Path $oc 'litellm-master.secret.env')
if ($env:LITELLM_MASTER_KEY) {
    $kl = $env:LITELLM_MASTER_KEY.Length
    Write-Host "LITELLM_MASTER_KEY definida (comprimento $kl)"
    if ($kl -lt 36) {
        Write-Warning "Chave muito curta (tipico sk-litellm-... no agldv03 tem 40+ caracteres). Verifica litellm-gateway.env / redeploy."
    }
} else {
    Write-Warning "LITELLM_MASTER_KEY vazia - o gateway pode falhar ao falar com o LiteLLM."
}

Write-Host "`n=== Locks em $logDir ===" 
if (Test-Path $logDir) {
    Get-ChildItem $logDir -Filter 'gateway*.lock' -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName }
} else {
    Write-Host "(pasta inexistente)"
}

if ($Repair) {
    Write-Host "`n=== -Repair: remover locks e tentar tarefa agendada ===" 
    if (Test-Path $logDir) {
        Get-ChildItem -LiteralPath $logDir -Filter '*.lock' -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    }
    Get-CimInstance Win32_Process -Filter "Name = 'node.exe'" -ErrorAction SilentlyContinue | Where-Object {
        $_.CommandLine -and (
            $_.CommandLine -match 'openclaw\\dist\\index\.js|openclaw\.mjs.*gateway|\\\\openclaw\\\\dist\\\\index\.js'
        )
    } | ForEach-Object {
        Write-Host "A terminar PID $($_.ProcessId) (node openclaw gateway)"
        Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
    }
    try {
        $gwTask = Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -eq 'OpenClaw Gateway' } | Select-Object -First 1
        if ($gwTask) {
            Start-ScheduledTask -InputObject $gwTask
            Start-Sleep -Seconds 6
            $gwTask = Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -eq 'OpenClaw Gateway' } | Select-Object -First 1
            Write-Host "Estado da tarefa OpenClaw Gateway: $($gwTask.State)"
        } else {
            Write-Warning "Tarefa 'OpenClaw Gateway' nao encontrada."
        }
    } catch {
        Write-Warning "Nao foi possivel arrancar a tarefa: $($_.Exception.Message)"
    }
}

if (-not (Test-Path $gwCmd)) {
    Write-Error "Falta gateway.cmd: $gwCmd"
    exit 1
}
if (-not (Test-Path $dist)) {
    Write-Error "Falta dist do OpenClaw: $dist (clone / build em ~/src/openclaw)"
    exit 1
}
if (-not (Test-Path $node)) {
    Write-Error "Node nao encontrado: $node"
    exit 1
}

Remove-Item -Force $outLog, $errLog, $combined -ErrorAction SilentlyContinue

# Reason: qm guest exec / tarefa como SYSTEM faz o Node usar systemprofile\.openclaw (sem gateway.mode).
# Forcar perfil do utilizador OpenClaw para o child herdar caminho correcto.
$env:USERPROFILE = $homeRoot
$env:APPDATA = Join-Path $homeRoot 'AppData\Roaming'
$env:LOCALAPPDATA = Join-Path $homeRoot 'AppData\Local'
Write-Host "USERPROFILE para o gateway: $homeRoot"

Write-Host "`n=== Smoke: node dist\index.js gateway --port $SmokePort (${CaptureSeconds}s; tarefa real usa 18789) -> $outLog / $errLog ===" 
$wd = Split-Path $dist -Parent
if (-not (Test-Path $wd)) { $wd = $homeRoot }

$pr = Start-Process -FilePath $node `
    -ArgumentList @($dist, 'gateway', '--port', "$SmokePort") `
    -WorkingDirectory $wd `
    -RedirectStandardOutput $outLog `
    -RedirectStandardError $errLog `
    -PassThru `
    -WindowStyle Hidden

Start-Sleep -Seconds $CaptureSeconds
if ($pr.HasExited) {
    Write-Warning "Smoke terminou sozinho (exit code $($pr.ExitCode)). Se for -4091 ou erro de porta, confirma que SmokePort=$SmokePort esta livre. Le o fim de $errLog."
} elseif (-not $pr.HasExited) {
    Write-Host "(a terminar processo de smoke apos ${CaptureSeconds}s)"
    Stop-Process -Id $pr.Id -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
}

# O Node deixa lock em %TEMP%\openclaw; se ficar, a tarefa agendada pode nao voltar a arrancar.
$adminTempOpenclaw = Join-Path $homeRoot 'AppData\Local\Temp\openclaw'
foreach ($ld in @($logDir, $adminTempOpenclaw)) {
    if (Test-Path $ld) {
        Get-ChildItem -LiteralPath $ld -Filter '*.lock' -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    }
}

if ($Repair) {
    Write-Host "`n=== Pos-smoke (-Repair): voltar a arrancar tarefa OpenClaw Gateway ===" 
    try {
        $gwTask = Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -eq 'OpenClaw Gateway' } | Select-Object -First 1
        if ($gwTask) {
            Start-ScheduledTask -InputObject $gwTask
            Start-Sleep -Seconds 8
        }
    } catch {
        Write-Warning "Pos-smoke Start-ScheduledTask: $($_.Exception.Message)"
    }
}

$stdout = if (Test-Path $outLog) { Get-Content -LiteralPath $outLog -Raw -Encoding UTF8 -ErrorAction SilentlyContinue } else { '' }
$stderr = if (Test-Path $errLog) { Get-Content -LiteralPath $errLog -Raw -Encoding UTF8 -ErrorAction SilentlyContinue } else { '' }
@"
--- STDOUT ---
$stdout
--- STDERR ---
$stderr
"@ | Set-Content -LiteralPath $combined -Encoding UTF8

Write-Host "`n=== Ultimas linhas (combinado) ===" 
Get-Content -LiteralPath $combined -Tail 100

Write-Host "`n=== Portas gateway (18789=tarefa; $SmokePort=smoke) ===" 
Get-NetTCPConnection -LocalPort 18789, $SmokePort -ErrorAction SilentlyContinue | Format-Table -AutoSize
Write-Host "(18789 vazio: tarefa nao manteve o Node; $SmokePort apos smoke pode ficar TIME_WAIT breve.)"

Write-Host "`n=== Tarefa OpenClaw Gateway ===" 
Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -eq 'OpenClaw Gateway' } | Format-List TaskName, State, TaskPath

Write-Host "`nFicheiros: $outLog , $errLog , $combined" 

Write-Host "`n=== Tarefa OpenClaw Gateway: conta (deve ser Administrator, nao SYSTEM) ===" 
$stOut = & schtasks.exe /Query /TN '\OpenClaw Gateway' /V /FO LIST 2>$null
if ($stOut) {
    $stOut | Select-String -Pattern 'Run As User|Task To Run|Status'
} else {
    Write-Warning "schtasks nao devolveu dados (nome da tarefa diferente?)"
}
Write-Host "`nNota: se 'Run As User' for SYSTEM, o gateway falha com gateway.mode=local unset no systemprofile."
