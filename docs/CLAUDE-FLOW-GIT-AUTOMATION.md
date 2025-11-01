# Claude Flow Git Automation Configuration

> **Last Updated**: 2025-11-01
> **Version**: 1.0.0
> **Location**: `~/.zshrc` (lines 298-335)

## 📋 Overview

Claude Flow provides automated Git workflow management through environment variables. This allows you to enable automatic commits and pushes during AI-assisted development sessions.

## 🔧 Environment Variables

### Core Git Automation

```bash
# Auto-commit: Automatically commit changes after file edits
export CLAUDE_FLOW_AUTO_COMMIT="false"  # Set to "true" to enable

# Auto-push: Automatically push commits to remote
export CLAUDE_FLOW_AUTO_PUSH="false"    # Set to "true" to enable
```

### Commit Configuration

```bash
# Commit message customization
export CLAUDE_FLOW_COMMIT_PREFIX="chore"              # Default prefix
export CLAUDE_FLOW_COMMIT_TEMPLATE="{{prefix}}: {{description}}"
```

### GitHub Integration

```bash
# GitHub automation features
export CLAUDE_FLOW_GITHUB_INTEGRATION="true"   # Enable GitHub features
export CLAUDE_FLOW_AUTO_RELEASE="false"        # Auto-create releases
```

### Workflow Automation

```bash
# Checkpoint system
export CLAUDE_FLOW_AUTO_CHECKPOINT="true"      # Enable checkpoints
export CLAUDE_FLOW_CHECKPOINT_FREQUENCY="10"   # Checkpoint every N edits
```

### Other Features

```bash
# Core configuration
export CLAUDE_FLOW_MAX_AGENTS=12               # Max concurrent agents
export CLAUDE_FLOW_MEMORY_SIZE=8GB             # Memory allocation
export CLAUDE_FLOW_ENABLE_NEURAL=true          # Enable neural features

# Feature toggles
export CLAUDE_FLOW_HOOKS_ENABLED="true"        # Enable hooks system
export CLAUDE_FLOW_TELEMETRY_ENABLED="true"    # Enable telemetry
export CLAUDE_FLOW_TRAINING_ENABLED="true"     # Enable training mode
```

## 🚀 Quick Start

### Using the Control Script

A helper script is available at `~/.dev-setup/scripts/claude-flow-git`:

```bash
# Show current status
claude-flow-git status

# Enable auto-commit only
claude-flow-git enable commit

# Enable both auto-commit and auto-push
claude-flow-git enable all

# Disable auto-push
claude-flow-git disable push

# Disable all automation
claude-flow-git disable all

# Show help
claude-flow-git help
```

### Manual Configuration

Edit `~/.zshrc` directly:

```bash
# Open in editor
nano ~/.zshrc

# Find the Claude Flow section (around line 298)
# Change "false" to "true" for the features you want

# Reload configuration
source ~/.zshrc
```

## 📊 Configuration Presets

### 1. Conservative (Default) ✅
**Best for**: Learning, cautious development
```bash
CLAUDE_FLOW_AUTO_COMMIT="false"
CLAUDE_FLOW_AUTO_PUSH="false"
```

### 2. Auto-Commit Only
**Best for**: Local development, frequent saves
```bash
CLAUDE_FLOW_AUTO_COMMIT="true"
CLAUDE_FLOW_AUTO_PUSH="false"
```

### 3. Full Automation
**Best for**: Trusted environments, CI/CD pipelines
```bash
CLAUDE_FLOW_AUTO_COMMIT="true"
CLAUDE_FLOW_AUTO_PUSH="true"
```

### 4. GitHub Integration
**Best for**: Teams using GitHub releases
```bash
CLAUDE_FLOW_AUTO_COMMIT="true"
CLAUDE_FLOW_AUTO_PUSH="true"
CLAUDE_FLOW_GITHUB_INTEGRATION="true"
CLAUDE_FLOW_AUTO_RELEASE="true"
```

## ⚙️ How It Works

### Auto-Commit Workflow

1. **File Edit Detection**: Claude Flow monitors file changes during sessions
2. **Automatic Staging**: Modified files are automatically staged (`git add`)
3. **Smart Commit Messages**: AI-generated commit messages based on changes
4. **Commit Execution**: Automatic `git commit` with template-based message

### Auto-Push Workflow

1. **Commit Detection**: After auto-commit completes
2. **Remote Check**: Verifies remote repository configuration
3. **Push Execution**: Automatically pushes to configured remote branch
4. **Error Handling**: Graceful fallback if push fails

### Checkpoint System

1. **Edit Tracking**: Counts file modifications
2. **Checkpoint Trigger**: Creates checkpoint every N edits (default: 10)
3. **Snapshot Creation**: Saves current state as Git commit
4. **Optional Release**: Can create GitHub release for checkpoint

## 🔒 Security Considerations

### ⚠️ Important Warnings

1. **Sensitive Data**: Auto-commit may commit sensitive files (`.env`, credentials)
2. **Unreviewed Changes**: Auto-push sends code without manual review
3. **Force Push**: Never enable with destructive Git operations

### Best Practices

```bash
# Always use .gitignore for sensitive files
echo ".env" >> .gitignore
echo "credentials.json" >> .gitignore
echo "*.key" >> .gitignore

# Review git status before enabling auto-push
git status

# Test auto-commit first before enabling auto-push
claude-flow-git enable commit  # Test this first
claude-flow-git enable push    # Enable after testing
```

## 🐛 Troubleshooting

### Auto-Commit Not Working

**Check configuration**:
```bash
claude-flow-git status
echo $CLAUDE_FLOW_AUTO_COMMIT  # Should output: true
```

**Verify Git repository**:
```bash
git status  # Should be in a Git repository
```

**Check permissions**:
```bash
ls -la .git  # Verify Git directory is writable
```

### Auto-Push Fails

**Check remote configuration**:
```bash
git remote -v  # Verify remote is configured
```

**Verify authentication**:
```bash
git push  # Test manual push first
```

**Check branch tracking**:
```bash
git branch -vv  # Should show upstream branch
```

### Commits Not Appearing

**Reload shell configuration**:
```bash
source ~/.zshrc
```

**Verify environment variables**:
```bash
env | grep CLAUDE_FLOW
```

## 📝 Commit Message Templates

### Default Template
```
{{prefix}}: {{description}}
```

### Examples with Custom Prefixes

```bash
# Feature commits
export CLAUDE_FLOW_COMMIT_PREFIX="feat"
# Output: "feat: add user authentication system"

# Bug fixes
export CLAUDE_FLOW_COMMIT_PREFIX="fix"
# Output: "fix: resolve login validation error"

# Chores (default)
export CLAUDE_FLOW_COMMIT_PREFIX="chore"
# Output: "chore: update dependencies"
```

### Custom Templates

```bash
# With scope
export CLAUDE_FLOW_COMMIT_TEMPLATE="{{prefix}}({{scope}}): {{description}}"

# With ticket number
export CLAUDE_FLOW_COMMIT_TEMPLATE="[{{ticket}}] {{prefix}}: {{description}}"

# Detailed format
export CLAUDE_FLOW_COMMIT_TEMPLATE="{{prefix}}: {{description}}\n\n{{body}}\n\n🤖 Auto-generated by Claude Flow"
```

## 🔗 Integration with Other Tools

### Claude Code Hooks

Combine with Claude Code hooks for advanced workflows:

```bash
# ~/.claude/hooks/pre-task.sh
#!/bin/bash
# Disable auto-commit for sensitive operations
export CLAUDE_FLOW_AUTO_COMMIT="false"
```

### CI/CD Pipelines

```yaml
# .github/workflows/claude-flow.yml
env:
  CLAUDE_FLOW_AUTO_COMMIT: "true"
  CLAUDE_FLOW_AUTO_PUSH: "true"
  CLAUDE_FLOW_GITHUB_INTEGRATION: "true"
```

## 📚 Related Documentation

- **Node.js Issue**: See `docs/NODE-18-CLAUDE-FLOW-ISSUE.md` for signal-exit bug
- **Infrastructure**: See `docs/INFRA.md` for Git workflows
- **Workflows**: See `docs/WORKFLOWS.md` for Agent OS integration

## ⚡ Quick Reference Card

| Command | Description | Risk Level |
|---------|-------------|------------|
| `claude-flow-git status` | Show current config | ✅ Safe |
| `claude-flow-git enable commit` | Enable auto-commit | ⚠️ Medium |
| `claude-flow-git enable push` | Enable auto-push | 🔴 High |
| `claude-flow-git enable all` | Enable full automation | 🔴 High |
| `claude-flow-git disable all` | Disable all features | ✅ Safe |

## 🎯 Recommendations

### For Individual Developers
```bash
# Conservative: Manual control (RECOMMENDED)
claude-flow-git disable all

# Or: Auto-commit only, manual push
claude-flow-git enable commit
```

### For Teams
```bash
# Protected branches: Manual only
claude-flow-git disable all

# Feature branches: Auto-commit allowed
claude-flow-git enable commit
```

### For CI/CD
```bash
# Full automation in pipelines
export CLAUDE_FLOW_AUTO_COMMIT="true"
export CLAUDE_FLOW_AUTO_PUSH="true"
```

---

**Maintained by**: AGL Infrastructure Team
**Last Updated**: 2025-11-01
**Status**: ✅ Production Ready
