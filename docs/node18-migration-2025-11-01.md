# Node.js 18 Migration - Summary

## ✅ Successfully Completed

### 1. Node.js 18 Installation
- **Installed**: Node.js v18.20.8 (LTS - Hydrogen)
- **npm Version**: v10.8.2
- **Installation Method**: NVM (Node Version Manager)

### 2. Configuration Changes
- **Default Version**: Changed from v22.21.0 → v18.20.8
- **NVM Alias**: `default` now points to Node 18
- **Status**: ✅ Configured and active

### 3. Current Environment

```bash
# Versions installed via NVM:
- v18.20.8  ← NEW (LTS Hydrogen) - NOW DEFAULT
- v22.21.0  ← Previous default
- v23.11.1
- v24.10.0
- v25.0.0
```

## 🔄 How to Activate

### In Current Terminal Session
Since we changed Node version during the session, you need to reload:

```bash
# Reload shell configuration
source ~/.zshrc

# Or restart your terminal
exec zsh
```

### New Terminal Sessions
Node 18 will be **automatically loaded** in all new terminal sessions because it's set as default.

## 🧪 Verification Commands

```bash
# Check Node version
node --version
# Expected: v18.20.8

# Check npm version
npm --version
# Expected: 10.8.2

# Check NVM current
nvm current
# Expected: v18.20.8

# List all installed versions
nvm list
# Should show v18.20.8 as default
```

## 📋 Important Notes

### 1. Native Modules Need Recompilation
When switching Node versions, native modules (like `better-sqlite3`) need to be recompiled.

**Solution:**
```bash
# Clear pnpm cache (already done)
pnpm store prune
rm -rf ~/.cache/pnpm/dlx

# For local projects with native modules
cd your-project
rm -rf node_modules
pnpm install
```

### 2. Using Hive Command
The `hive` alias works in **interactive terminals only** (not in scripts/subshells).

**In interactive terminal:**
```bash
source ~/.zshrc
hive "your command here"
```

**Alternative (works everywhere):**
```bash
npx claude-flow@alpha hive-mind spawn "your command" --claude
```

### 3. Switching Between Node Versions
You can switch between installed versions anytime:

```bash
# Use Node 18 (default)
nvm use 18

# Use Node 22
nvm use 22

# Use latest
nvm use node

# Use LTS
nvm use --lts
```

## 🔧 Troubleshooting

### Issue: "command not found: hive" in scripts
**Cause**: Aliases don't work in non-interactive shells
**Solution**: Use full command:
```bash
npx claude-flow@alpha hive-mind spawn "command" --claude
```

### Issue: Native module errors after Node version change
**Cause**: Modules compiled for different Node version
**Solution**:
```bash
# Clear cache
pnpm store prune
rm -rf ~/.cache/pnpm/dlx

# Reinstall project dependencies
rm -rf node_modules
pnpm install
```

### Issue: Node version reverts to old version
**Cause**: Shell not reloaded
**Solution**:
```bash
source ~/.zshrc
# or
exec zsh
```

## 🎯 Quick Reference

| Command | Description |
|---------|-------------|
| `node --version` | Check current Node version |
| `nvm current` | Show active Node version |
| `nvm list` | List installed versions |
| `nvm use 18` | Switch to Node 18 |
| `nvm use 22` | Switch to Node 22 |
| `nvm alias default 18` | Set Node 18 as default |
| `nvm install 20` | Install Node 20 |
| `nvm uninstall 23` | Remove Node 23 |

## 📊 Configuration Files Updated

### ~/.zshrc
No changes needed - NVM configuration already existed and works with all versions.

### NVM Configuration (lines 242-244)
```bash
export NVM_DIR="/root/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
```

## ✅ Next Steps

1. **Reload your shell**:
   ```bash
   source ~/.zshrc
   ```

2. **Verify Node 18 is active**:
   ```bash
   node --version  # Should show v18.20.8
   ```

3. **Test in interactive terminal**:
   ```bash
   # Use hive command (only works in interactive shell)
   hive "hi"

   # Or use full command
   npx claude-flow@alpha hive-mind spawn "hi" --claude
   ```

4. **For local projects with node_modules**:
   ```bash
   cd your-project
   rm -rf node_modules
   pnpm install
   ```

---

**Migration Completed**: 2025-11-01
**Previous Version**: v22.21.0
**New Version**: v18.20.8
**Status**: ✅ Successful
