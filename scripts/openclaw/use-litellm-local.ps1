# Configura OpenClaw para usar LiteLLM local (localhost:4000)
# Uso: .\scripts\openclaw\use-litellm-local.ps1
# Requer: Node.js, LiteLLM rodando em localhost:4000

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Resolve-Path (Join-Path $ScriptDir "..\..")
$NodeScript = Join-Path $ScriptDir "use-litellm-local.mjs"

node $NodeScript
