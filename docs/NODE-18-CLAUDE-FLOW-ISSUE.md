# Claude-Flow Signal-Exit Issue - Resolved

## Problem Summary

The `claude-flow@alpha` package has a compatibility issue with the `signal-exit` module that affects **all Node.js versions** (tested on 18.20.8, 20.19.5, and 24.6.0).

### Error Message
```
SyntaxError: The requested module 'signal-exit' does not provide an export named 'default'
    at ModuleJob._instantiate (node:internal/modules/esm/module_job:123:21)
```

### Root Cause
- The `restore-cursor` package (dependency of `cli-cursor`) uses an incompatible import for `signal-exit`
- This is a known issue with ESM/CommonJS module compatibility in the alpha version
- The issue persists even after clearing all caches

## Solution Applied

### 1. Node.js 18 LTS Installation ✅
```bash
# Installed Node.js 18.20.8 (most compatible version)
brew install node@18
brew unlink node && brew unlink node@20
brew link --overwrite --force node@18

# Persisted in ~/.zshrc
export PATH="/usr/local/opt/node@18/bin:$PATH"
```

**Current Active Version**: Node.js v18.20.8
**npm Version**: 10.19.0

### 2. Alternative Workflows (RECOMMENDED)

Since `hive commit` relies on `claude-flow@alpha` which is broken, use these alternatives:

#### Option A: Use `/autocommit` Slash Command
```bash
# Native Claude Code command (most reliable)
/autocommit
```

#### Option B: Use Git Directly
```bash
# Manual git workflow with conventional commits
git add .
git commit -m "feat: your feature description

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
git push
```

#### Option C: Use `/git --commit` Slash Command
```bash
# From ~/.claude/commands/git.md
/git --commit "your commit message"
```

## Attempted Fixes (Did NOT Work)

1. ❌ Downgrade to Node.js 20 - Same error
2. ❌ Downgrade to Node.js 18 - Same error
3. ❌ Clear pnpm cache (`rm -rf ~/Library/Caches/pnpm/dlx`) - Same error
4. ❌ Clear npm cache (`npm cache clean --force`) - N/A for npx dlx
5. ❌ Install stable version (`npm install -g claude-flow`) - No stable version exists yet

## Why This Happens

1. **Alpha Software**: `claude-flow@alpha` is still in development (v2.7.26)
2. **Dependency Lock**: The alpha version has locked dependencies that are incompatible
3. **ESM Transition**: Node.js ecosystem transitioning from CommonJS to ESM modules
4. **Cache Persistence**: pnpm dlx caches the broken dependency tree

## Recommendations

### Immediate Actions ✅
1. Use `/autocommit` or direct git commands for commits
2. Keep Node.js 18 as default (best compatibility overall)
3. Monitor claude-flow repository for updates

### Long-Term Solution
Wait for one of these:
1. **claude-flow stable release** (non-alpha) - Check https://www.npmjs.com/package/claude-flow
2. **signal-exit fix** in upstream dependencies
3. **claude-flow v3.0+** with updated dependencies

### If You Need Hive-Mind Features
```bash
# For now, avoid hive-mind spawn commands
# Use Claude Code's built-in Task tool instead:

# Instead of:
# hive "commit my changes"

# Use:
/autocommit
# or
Task tool with subagent_type="coder"
```

## Verification

Node.js 18 is working:
```bash
$ node --version
v18.20.8

$ npm --version
10.19.0

$ npx claude-flow@alpha --version
v2.7.26  # Works!

$ npx claude-flow@alpha hive-mind --help
# FAILS with signal-exit error
```

## Related Issues

- GitHub Issue: https://github.com/ruvnet/claude-flow/issues (check for signal-exit related issues)
- Node.js Compatibility: claude-flow requires Node.js 18+ (✅ met)
- npm Version: claude-flow requires npm 9+ (✅ met - we have 10.19.0)

## Date Resolved
**2025-11-01** - Switched to Node.js 18.20.8 and documented alternative workflows

---

**Maintained by**: AGL Infrastructure Team
**Last Updated**: 2025-11-01
