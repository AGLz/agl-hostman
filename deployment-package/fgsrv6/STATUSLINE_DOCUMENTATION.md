# Statusline Documentation

## Overview

The statusline is a dynamic terminal display that shows real-time information about your Claude Code session, including system metrics, task performance, and swarm coordination status.

## What the Statusline Displays

### 1. **Model and Directory**
```
Claude in project-name
```
- **Model**: Current Claude model (e.g., Claude Sonnet)
- **Directory**: Current working directory (basename only)
- Special branding for "claude-code-flow" → "🌊 Claude Flow"

### 2. **Git Branch** (when in git repository)
```
 on ⎇ main
```
- Shows current git branch in yellow color
- Only appears when in a git repository

### 3. **Swarm Configuration** (when .claude-flow exists)
```
│ ⚡mesh 🤖 54
```
- **Topology Icon**: 
  - ⚡mesh = balanced strategy
  - ⚡hier = conservative strategy  
  - ⚡ring = aggressive strategy
  - ⚡[custom] = other strategies
- **Agent Count**: Number of configured agent profiles

### 4. **System Metrics** (real-time from system-metrics.json)

#### Memory Usage
```
 💾 45%
```
- **Color Coding**:
  - 🟢 Green: <60% memory usage
  - 🟡 Yellow: 60-80% memory usage
  - 🔴 Red: >80% memory usage

#### CPU Load
```
 ⚙ 32%
```
- **Color Coding**:
  - 🟢 Green: <50% CPU load
  - 🟡 Yellow: 50-75% CPU load
  - 🔴 Red: >75% CPU load

### 5. **Session State** (when active)
```
 🔄 a1b2c
```
- Shows abbreviated session ID (first part before dash)
- Only displays when session is active

### 6. **Performance Metrics** (from task-metrics.json)

#### Success Rate
```
 🎯 92%
```
- **Color Coding**:
  - 🟢 Green: >80% success rate
  - 🟡 Yellow: 60-80% success rate
  - 🔴 Red: <60% success rate
- Shows percentage of successful tasks

#### Average Task Duration
```
 ⏱️ 2.5s
 ⏱️ 1.2m
 ⏱️ 0.5h
```
- Smart formatting:
  - Seconds: X.Xs (for <60s)
  - Minutes: X.Xm (for <1h)
  - Hours: X.Xh (for ≥1h)

#### Task Streak
```
 🔥 12
```
- Number of consecutive successful tasks
- Only displays when streak > 0
- Red color for visibility

### 7. **Active Tasks**
```
 📋 3
```
- Count of active task files in .claude-flow/tasks/
- Only displays when > 0 tasks

### 8. **Hooks Status**
```
 🔗
```
- Purple link icon when hooks are enabled
- Indicates active hook system

## Example Complete Statusline

```
Claude in agl-hostman on ⎇ develop │ ⚡mesh 🤖 54  💾 45%  ⚙ 32%  🔄 a1b2c  🎯 92%  ⏱️ 2.5s  🔥 12  📋 3  🔗
```

## Data Sources

The statusline reads from several JSON files in `.claude-flow/`:

1. **swarm-config.json**: Swarm topology and agent count
2. **metrics/system-metrics.json**: Memory and CPU metrics
3. **session-state.json**: Session ID and active state
4. **metrics/task-metrics.json**: Success rates, durations, streaks
5. **tasks/*.json**: Active task count
6. **hooks-state.json**: Hooks enabled status

## Dependencies

- **jq**: JSON parser (required)
- **bc**: Calculator (for time formatting)
- **git**: For branch detection (optional)

## Color Codes

| Element | Colors Used |
|---------|-------------|
| Directory | Cyan (36) |
| Branch | Yellow (33) |
| Topology | Magenta (35) |
| Memory | Green (32) / Yellow (33) / Red (31) |
| CPU | Green (32) / Yellow (33) / Red (31) |
| Session | Blue (34) |
| Success Rate | Green (32) / Yellow (33) / Red (31) |
| Avg Time | Cyan (36) |
| Streak | Bright Red (91) |
| Tasks | Cyan (36) |
| Hooks | Magenta (35) |

## ANSI Escape Sequences

The script uses ANSI escape codes for colors and formatting:
- `\033[1m`: Bold
- `\033[0m`: Reset
- `\033[36m`: Cyan
- `\033[33m`: Yellow
- `\033[35m`: Magenta
- `\033[32m`: Green
- `\033[31m`: Red
- `\033[34m`: Blue
- `\033[91m`: Bright Red

## Configuration

The statusline is configured in `.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": ".claude/statusline-command.sh"
  }
}
```

## Files

- **Source**: `.claude/statusline-command.sh` (177 lines)
- **Config**: `.claude/settings.json` (statusline section)
- **Installation**: `install.sh` (automated setup)

## Installation on FGSRV6

```bash
# On FGSRV6 (186.202.57.120 or 10.6.0.5)
cd /root/deployment-package/fgsrv6
./install.sh
```

The installation script will:
1. Detect the operating system
2. Install required dependencies (jq, bc, git)
3. Create `.claude` directory
4. Copy configuration files
5. Set proper permissions
6. Verify installation

## Testing

To test the statusline manually:

```bash
# Test the script directly
echo '{"model": {"display_name": "Claude Sonnet"}, "workspace": {"current_dir": "/root"}}' | .claude/statusline-command.sh

# Or run from any directory
cd /your/project
.claude/statusline-command.sh
```

## Troubleshooting

### Statusline not showing
- Check if `.claude/settings.json` exists and has statusLine config
- Verify `statusline-command.sh` is executable (`chmod +x`)
- Check if jq is installed: `which jq`

### Missing metrics
- Ensure `.claude-flow/` directory exists
- Verify JSON files are valid: `jq . .claude-flow/metrics/system-metrics.json`
- Check file permissions

### Colors not displaying
- Ensure terminal supports ANSI colors
- Try with different terminals (iTerm2, Terminal.app, etc.)
- Check TERM environment variable

## Performance

The script:
- Runs on every prompt display
- Uses efficient JSON parsing with jq
- Caches results where possible
- Minimal I/O operations
- Sub-second execution time

## Maintenance

No regular maintenance required. The statusline automatically reads from dynamic data files that are updated by the Claude Flow system.

---

**Last Updated**: 2026-01-04
**Version**: 1.0
**Lines of Code**: 177 (statusline-command.sh)
