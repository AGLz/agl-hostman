# Statusline Expected Output Documentation - FGSRV6

## 📊 Statusline Display Components

The statusline displays a comprehensive set of information in a single line, organized with color-coded segments for easy visual parsing.

### Basic Structure

```
[Model] in [Directory] on [Git Branch] │ [Swarm] [Agents] [Memory] [CPU] [Session] [Success Rate] [Avg Time] [Streak] [Tasks] [Hooks]
```

### Component Breakdown

#### 1. Core Information (Always Shown)

**Model Name**
- Format: `Claude` or `Sonnet 4.5` (or other model display name)
- Color: Bold white (`\033[1m...\033[0m`)
- Always present

**Current Directory**
- Format: Last segment of the path (e.g., `agl-hostman`)
- Special case: `claude-code-flow` → `🌊 Claude Flow`
- Color: Cyan (`\033[36m...\033[0m`)
- Always present

**Git Branch** (if in git repository)
- Format: `⎇ [branch-name]`
- Color: Yellow (`\033[33m...\033[0m`)
- Only shown if `.git` directory exists

#### 2. Claude-Flow Integration (if `.claude-flow` exists)

**Separator**: ` │ ` (vertical bar with spaces)

**Swarm Topology**
- Format: `⚡[topology-icon]`
- Color: Magenta (`\033[35m...\033[0m`)
- Topology mappings:
  - `balanced` → `⚡mesh`
  - `conservative` → `⚡hier`
  - `aggressive` → `⚡ring`
  - Other → `⚡[strategy-name]`
- Only shown if `swarm-config.json` exists and has `defaultStrategy`

**Agent Count**
- Format: ` 🤖 [count]`
- Color: Magenta (`\033[35m...\033[0m`)
- Shows number of agent profiles configured
- Only shown if `agentProfiles` count > 0

**Memory Usage**
- Format: ` 💾 [percentage]%`
- Color-coded by threshold:
  - Green (`\033[32m...\033[0m`) if < 60%
  - Yellow (`\033[33m...\033[0m`) if 60-80%
  - Red (`\033[31m...\033[0m`) if > 80%
- Only shown if `system-metrics.json` exists with valid data

**CPU Load**
- Format: ` ⚙ [percentage]%`
- Color-coded by threshold:
  - Green (`\033[32m...\033[0m`) if < 50%
  - Yellow (`\033[33m...\033[0m`) if 50-75%
  - Red (`\033[31m...\033[0m`) if > 75%
- Only shown if `system-metrics.json` exists with valid data

**Active Session**
- Format: ` 🔄 [session-id-abbreviated]`
- Color: Blue (`\033[34m...\033[0m`)
- Shows first part of session ID (before first dash)
- Only shown if `session-state.json` exists with `active: true`

**Task Success Rate**
- Format: ` 🎯 [percentage]%`
- Color-coded by threshold:
  - Green (`\033[32m...\033[0m`) if > 80%
  - Yellow (`\033[33m...\033[0m`) if 60-80%
  - Red (`\033[31m...\033[0m`) if < 60%
- Only shown if `task-metrics.json` exists with data

**Average Task Duration**
- Format: ` ⏱️ [formatted-time]`
- Color: Cyan (`\033[36m...\033[0m`)
- Smart formatting:
  - Seconds: `1.5s` (if < 60s)
  - Minutes: `2.3m` (if < 60m)
  - Hours: `1.5h` (if >= 60m)
- Only shown if `task-metrics.json` exists with data

**Success Streak**
- Format: ` 🔥 [count]`
- Color: Bright Red (`\033[91m...\033[0m`)
- Only shown if streak > 0
- Only shown if `task-metrics.json` exists with data

**Active Tasks**
- Format: ` 📋 [count]`
- Color: Cyan (`\033[36m...\033[0m`)
- Shows count of `.json` files in `tasks/` directory
- Only shown if `tasks/` directory exists and has files

**Hooks Status**
- Format: ` 🔗`
- Color: Magenta (`\033[35m...\033[0m`)
- Only shown if `hooks-state.json` exists with `enabled: true`

## 🎨 Color Reference

| Color | ANSI Code | Usage |
|-------|-----------|-------|
| Bold White | `\033[1m...\033[0m` | Model name |
| Cyan | `\033[36m...\033[0m` | Directory name, average time, active tasks |
| Yellow | `\033[33m...\033[0m` | Git branch, warnings (60-80% memory, 50-75% CPU) |
| Magenta | `\033[35m...\033[0m` | Swarm topology, agents, hooks |
| Blue | `\033[34m...\033[0m` | Active session |
| Green | `\033[32m...\033[0m` | Good status (<60% memory, <50% CPU, >80% success) |
| Red | `\033[31m...\033[0m` | Critical status (>80% memory, >75% CPU, <60% success) |
| Bright Red | `\033[91m...\033[0m` | Success streak |

## 📋 Example Outputs

### Example 1: Minimal Output (No Git, No Claude-Flow)

**Input:**
```json
{
  "model": {"display_name": "Claude"},
  "cwd": "/test"
}
```

**Output:**
```
Claude in test
```

### Example 2: With Git Branch

**Input:**
```json
{
  "model": {"display_name": "Sonnet 4.5"},
  "cwd": "/home/user/projects/agl-hostman"
}
```

**Output:**
```
Sonnet 4.5 in agl-hostman on ⎇ develop
```

### Example 3: Full Claude-Flow Integration

**Assume:**
- `.claude-flow/swarm-config.json` exists with `defaultStrategy: "balanced"` and 6 agents
- `.claude-flow/metrics/system-metrics.json` exists with `memoryUsagePercent: 45` and `cpuLoad: 0.3`
- `.claude-flow/session-state.json` exists with `active: true` and `sessionId: "abc-123-def"`
- `.claude-flow/metrics/task-metrics.json` exists with high success rate
- `.claude-flow/tasks/` exists with 3 task files

**Input:**
```json
{
  "model": {"display_name": "Sonnet 4.5"},
  "cwd": "/home/user/projects/agl-hostman"
}
```

**Output:**
```
Sonnet 4.5 in agl-hostman on ⎇ develop │ ⚡mesh 🤖 6  💾 45%  ⚙ 30%  🔄 abc  🎯 95%  ⏱️ 1.2s  📋 3
```

### Example 4: Warning States

**Assume:**
- Memory usage: 72% (yellow)
- CPU load: 65% (yellow)
- Success rate: 75% (yellow)

**Output:**
```
Sonnet 4.5 in agl-hostman │ 💾 72%  ⚙ 65%  🎯 75%
```

### Example 5: Critical States

**Assume:**
- Memory usage: 85% (red)
- CPU load: 80% (red)
- Success rate: 45% (red)

**Output:**
```
Sonnet 4.5 in agl-hostman │ 💾 85%  ⚙ 80%  🎯 45%
```

### Example 6: With Success Streak

**Assume:**
- 10 consecutive successful tasks

**Output:**
```
Sonnet 4.5 in agl-hostman │ 🎯 92%  ⏱️ 0.8s  🔥 10
```

### Example 7: With Hooks Enabled

**Assume:**
- `hooks-state.json` exists with `enabled: true`

**Output:**
```
Sonnet 4.5 in agl-hostman │ ⚡mesh 🔗
```

### Example 8: Claude-Flow Special Directory

**Input:**
```json
{
  "model": {"display_name": "Claude"},
  "cwd": "/home/user/claude-code-flow"
}
```

**Output:**
```
Claude in 🌊 Claude Flow on ⎇ main
```

## 🔍 Testing Output

### Verify Output Format

```bash
# Test basic output
echo '{"model":{"display_name":"Test"},"cwd":"/test"}' | .claude/statusline-command.sh

# Verify it contains expected components
OUTPUT=$(echo '{"model":{"display_name":"Test"},"cwd":"/test"}' | .claude/statusline-command.sh)
echo "$OUTPUT" | grep -q "Test" && echo "✓ Model present"
echo "$OUTPUT" | grep -q "test" && echo "✓ Directory present"
```

### Verify ANSI Color Codes

```bash
# Output should contain ANSI escape sequences
OUTPUT=$(echo '{}' | .claude/statusline-command.sh)

# Check for color codes (not literal strings)
if echo "$OUTPUT" | grep -q $'\033\[36m'; then
    echo "✓ Cyan color code present"
fi

# Should NOT contain literal escape sequences
if ! echo "$OUTPUT" | grep -q '\\033'; then
    echo "✓ No literal escape sequences"
fi
```

### Verify Line Format

```bash
# Should be single line
LINE_COUNT=$(echo '{}' | .claude/statusline-command.sh | wc -l)
if [ "$LINE_COUNT" -eq 1 ]; then
    echo "✓ Output is single line"
fi

# Should end with newline
if echo '{}' | .claude/statusline-command.sh | tail -c 1 | grep -q $'\n'; then
    echo "✓ Output ends with newline"
fi
```

## 📊 Metrics Interpretation

### Memory Usage
- **< 60% (Green)**: Healthy memory usage
- **60-80% (Yellow)**: Warning - monitor for growth
- **> 80% (Red)**: Critical - may need to free memory

### CPU Load
- **< 50% (Green)**: Healthy CPU load
- **50-75% (Yellow)**: Moderate load
- **> 75% (Red)**: High load - may impact performance

### Success Rate
- **> 80% (Green)**: Excellent task success rate
- **60-80% (Yellow)**: Acceptable but room for improvement
- **< 60% (Red)**: Concerning - investigate failures

### Average Duration
- Lower is better (faster task completion)
- Trend over time is more important than absolute value
- Significant increases may indicate performance issues

### Success Streak
- Shows consecutive successful task completions
- Higher streaks indicate stable, reliable execution
- Streak breaks when a task fails

## 🎯 Validation Rules

A valid statusline output:

1. **Always contains**:
   - Model name (bold white)
   - Directory name (cyan)

2. **May contain** (conditional):
   - Git branch (yellow, if in git repo)
   - Claude-Flow components (if `.claude-flow` exists)

3. **Must have**:
   - ANSI color codes (not literal strings)
   - Single line output
   - Ends with newline character

4. **Must not have**:
   - Error messages
   - Literal escape sequences (`\033`)
   - Multiple lines (except final newline)
   - Empty output

## 🚨 Troubleshooting Output Issues

### Issue: No output
**Check**: Script permissions, JSON parsing errors

### Issue: Raw ANSI codes visible
**Check**: Terminal compatibility, Nerd Font installation

### Issue: Missing components
**Check**: File existence (`.git`, `.claude-flow/*`)

### Issue: Slow display
**Check**: Execution time, cache configuration

### Issue: Colors not showing
**Check**: Terminal color support, TERM environment variable
