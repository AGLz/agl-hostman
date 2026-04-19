@echo off
REM OpenClaw Installation Script for aglwk45 (VM104)
REM Created: 2026-01-30
REM Usage: Run this script via RDP or as Administrator

echo ========================================
echo OpenClaw Installation for aglwk45
echo ========================================
echo.

REM Check if OpenClaw is already installed
echo [1/5] Checking OpenClaw installation...
where openclaw >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo ✓ OpenClaw found in PATH
    openclaw --version
) else (
    echo ✗ OpenClaw not found in PATH
    echo Trying direct path...
    if exist "C:\Program Files\nodejs\openclaw.cmd" (
        echo ✓ Found at C:\Program Files\nodejs\openclaw.cmd
        set "OPENCLAW_CMD=C:\Program Files\nodejs\openclaw.cmd"
    ) else (
        echo ✗ OpenClaw not installed. Installing...
        call npm install -g openclaw@latest
    )
)
echo.

REM Check Node.js version
echo [2/5] Checking Node.js version...
node --version
echo.

REM Run OpenClaw doctor
echo [3/5] Running OpenClaw doctor...
if exist "C:\Program Files\nodejs\openclaw.cmd" (
    call "C:\Program Files\nodejs\openclaw.cmd" doctor --fix
) else (
    call openclaw doctor --fix
)
echo.

REM Run onboarding
echo [4/5] Running OpenClaw onboarding...
echo This will configure the gateway and channels.
if exist "C:\Program Files\nodejs\openclaw.cmd" (
    call "C:\Program Files\nodejs\openclaw.cmd" onboard --install-daemon
) else (
    call openclaw onboard --install-daemon
)
echo.

REM Configure ZAI API key for GLM-4.7
echo [5/5] Configuring ZAI API key for GLM-4.7...
echo Creating auth-profiles.json with ZAI key...

set "CLAW_CONFIG=%USERPROFILE%\.openclaw"
if not exist "%CLAW_CONFIG%" (
    set "CLAW_CONFIG=C:\windows\system32\config\systemprofile\.clawdbot"
)

set "AUTH_FILE=%CLAW_CONFIG%\agents\main\agent\auth-profiles.json"

if not exist "%AUTH_FILE%" (
    echo Creating auth-profiles.json...
    mkdir "%CLAW_CONFIG%\agents\main\agent" 2>nul
    (
        echo {
        echo   "profiles": {
        echo     "zai:default": {
        echo       "type": "api_key",
        echo       "provider": "zai",
        echo       "key": "896fb1e6936a4cd1b61aa2314d6d3728.u2lsAqLNfajAslfx"
        echo     }
        echo   }
        echo }
    ) > "%AUTH_FILE%"
) else (
    echo Auth file already exists, please update manually if needed.
    echo Location: %AUTH_FILE%
)
echo.

REM Show status
echo ========================================
echo Installation Complete!
echo ========================================
echo.
echo To verify OpenClaw status, run:
echo   openclaw status
echo   openclaw doctor
echo   openclaw dashboard
echo.
echo ZAI API Key configured for GLM-4.7 model
echo.

pause
