#!/usr/bin/env python3
"""Fix YAML config - remove broken entries without litellm_params."""
import yaml

CONFIG = "/opt/litellm/config.yaml"
CONFIG_MOUNT = "/mnt/overpower/apps/dev/agl/agl-hostman/config/litellm/config.yaml"

with open(CONFIG) as f:
    content = f.read()

# The comment-out approach broke the YAML structure
# Instead, fully remove cerebras entries and fix any broken entries
lines = content.split("\n")
new_lines = []
skip_block = False
skip_depth = 0

i = 0
while i < len(lines):
    line = lines[i]
    
    # Check for DISABLED comment (our broken fix)
    if "# DISABLED:" in line and "cerebras" in line.lower():
        # Skip this line and all following commented lines that were part of the entry
        i += 1
        while i < len(lines) and lines[i].strip().startswith("#") and not lines[i].strip().startswith("# =="):
            i += 1
        continue
    
    # Check for cerebras model entry (uncommented)
    if '- model_name:' in line and 'cerebras' in line.lower():
        # Skip entire model entry block
        i += 1
        while i < len(lines):
            next_line = lines[i]
            if next_line.strip().startswith("- model_name:") or (next_line.strip() == "" and i+1 < len(lines) and lines[i+1].strip().startswith("- model_name:")):
                break
            if next_line.strip().startswith("# =="):
                break
            i += 1
        continue
    
    new_lines.append(line)
    i += 1

result = "\n".join(new_lines)

# Verify YAML is valid
try:
    data = yaml.safe_load(result)
    models = data.get("model_list", [])
    bad = [m for m in models if "litellm_params" not in m]
    print(f"Total models: {len(models)}")
    print(f"Bad entries (no litellm_params): {len(bad)}")
    for m in bad:
        print(f"  BAD: {m}")
    
    if bad:
        # Remove bad entries
        data["model_list"] = [m for m in models if "litellm_params" in m]
        result = yaml.dump(data, default_flow_style=False, allow_unicode=True)
        print(f"Removed {len(bad)} bad entries")
        print(f"Final model count: {len(data['model_list'])}")
except Exception as e:
    print(f"YAML parse error: {e}")
    # Fall back to backup
    print("Restoring from backup...")
    with open(CONFIG + ".bak") as f:
        result = f.read()

with open(CONFIG, "w") as f:
    f.write(result)
with open(CONFIG_MOUNT, "w") as f:
    f.write(result)

print("Config written and synced")
