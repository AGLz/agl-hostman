#!/usr/bin/env python3
import yaml

path = "/mnt/overpower/apps/dev/agl/openclaw-repo/docker-compose.yml"
with open(path, "r") as f:
    data = yaml.safe_load(f)

# Add missing env vars to gateway
gw_env = data["services"]["openclaw-gateway"]["environment"]
missing_vars = [
    "TELEGRAM_BOT_TOKEN",
    "OPENROUTER_API_KEY",
    "DASHSCOPE_API_KEY",
    "ZAI_API_KEY",
]
for var in missing_vars:
    if var not in gw_env:
        gw_env[var] = f"${{{var}:-}}"
        print(f"Added {var} to openclaw-gateway")

# Also add to cli
cli_env = data["services"]["openclaw-cli"]["environment"]
for var in missing_vars:
    if var not in cli_env:
        cli_env[var] = f"${{{var}:-}}"
        print(f"Added {var} to openclaw-cli")

with open(path, "w") as f:
    yaml.dump(data, f, default_flow_style=False, sort_keys=False)

print("Done")
