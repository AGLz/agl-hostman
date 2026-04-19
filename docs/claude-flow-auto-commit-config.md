# Claude-Flow Auto Commit & Auto Push Configuration

> **Last Updated**: 2025-10-28 | **Status**: ✅ ENABLED VIA ENVIRONMENT VARIABLES

## 📝 Summary

Configurações de auto commit e auto push ativadas via variáveis de ambiente persistentes para o claude-flow hive-mind. Esta abordagem sobrevive a atualizações de pacotes npm.

---

## 🎯 Configuration Method

### ✅ Environment Variables (RECOMMENDED - Persistent)

Configurado via variáveis de ambiente em três locais para máxima compatibilidade:

**1. ~/.bashrc** (sessões bash)
**2. ~/.zshrc** (sessões zsh)
**3. ~/.config/environment.d/claude-flow.conf** (systemd user sessions)

### Environment Variables Configured
```bash
export CLAUDE_FLOW_AUTO_COMMIT=true
export CLAUDE_FLOW_AUTO_PUSH=true
export CLAUDE_FLOW_HOOKS_ENABLED=true
export CLAUDE_FLOW_CHECKPOINTS_ENABLED=true
export GITHUB_AUTO_SYNC=true
```

### ❌ NOT USED: Source Code Modification
Anteriormente modificamos o arquivo `coder.ts` diretamente, mas isso seria perdido em atualizações de npm. A abordagem com variáveis de ambiente é superior e persistente.

---

## ⚙️ Environment Variables Reference

| Variable | Value | Description |
|----------|-------|-------------|
| `CLAUDE_FLOW_AUTO_COMMIT` | `true` | Automatically create git commits after code changes |
| `CLAUDE_FLOW_AUTO_PUSH` | `true` | Automatically push commits to remote repository |
| `CLAUDE_FLOW_HOOKS_ENABLED` | `true` | Enable hook system for lifecycle events |
| `CLAUDE_FLOW_CHECKPOINTS_ENABLED` | `true` | Create checkpoint commits during workflows |
| `GITHUB_AUTO_SYNC` | `true` | Keep GitHub repository synchronized |

---

## 🔧 Configuration Structure

The configuration is part of the `createCoderAgent` function in the coder agent:

```typescript
const defaultEnv = {
  runtime: 'deno' as const,
  version: '1.40.0',
  workingDirectory: './agents/coder',
  tempDirectory: './tmp/coder',
  logDirectory: './logs/coder',
  apiEndpoints: {},
  credentials: {},
  availableTools: ['git', 'editor', 'debugger', 'linter', 'formatter', 'compiler'],
  toolConfigs: {
    git: { autoCommit: true, autoPush: true, autoSync: true }, // ✅ UPDATED
    linter: { strict: true, autoFix: true },
    formatter: { style: 'prettier', tabSize: 2 },
  },
};
```

---

## 🚀 How It Works

### Auto Commit Behavior
When the coder agent makes changes to files:
1. **Code Generation**: Agent writes/modifies code files
2. **Auto Stage**: Changes are automatically staged (`git add .`)
3. **Auto Commit**: Commit is created with AI-generated message
4. **Auto Push**: Commit is pushed to remote repository
5. **Auto Sync**: Repository stays synchronized with remote

### Commit Message Format
The coder agent will generate commit messages following conventional commit format:
```
<type>(<scope>): <description>

<body with details>

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>
```

**Commit Types**:
- `feat`: New features
- `fix`: Bug fixes
- `docs`: Documentation changes
- `refactor`: Code refactoring
- `test`: Test additions/modifications
- `perf`: Performance improvements
- `chore`: Maintenance tasks

---

## 📋 Usage Examples

### With Hive-Mind
```bash
# Spawn coder agent (auto commit/push enabled)
npx claude-flow hive-mind spawn "Implement user authentication"

# Agent will automatically:
# 1. Generate authentication code
# 2. Stage changes (git add .)
# 3. Create commit with AI message
# 4. Push to remote repository
```

### With Manual Agent Creation
```bash
# Start claude-flow with coder agent
npx claude-flow agent spawn --type coder

# Execute coding task
npx claude-flow agent execute <agent-id> "Create REST API endpoint"

# Auto commit and push happens automatically
```

### Direct Coder Agent Usage
```typescript
import { createCoderAgent } from 'claude-flow';

const coder = createCoderAgent(
  'coder-1',
  { /* agent config */ },
  { /* environment config */ },
  logger,
  eventBus,
  memory
);

// Execute task - auto commit/push enabled by default
await coder.executeTask({
  id: 'task-1',
  type: 'code-generation',
  description: 'Create user service',
});
```

---

## ⚠️ Important Notes

### 1. **Automatic Push to Remote**
- All commits are automatically pushed to `origin <current-branch>`
- Ensure you have write access to the remote repository
- Configure SSH keys or credentials before using auto-push

### 2. **Commit Messages**
- AI-generated commit messages are created automatically
- Messages follow conventional commit format
- Include co-author attribution to Claude

### 3. **Build Requirement**
- After modifying source files, rebuild may be required
- Current version: `claude-flow@2.7.0-alpha.14`
- Build command: `npm run build` (requires `swc` compiler)

### 4. **Persistence**
- Configuration is in source code (`src/cli/agents/coder.ts`)
- Will persist across sessions
- May be overwritten during npm package updates

---

## 🔄 Managing Configuration

### Enable Auto Commit/Push (Already Done)
```bash
# Environment variables set in ~/.bashrc and ~/.zshrc
export CLAUDE_FLOW_AUTO_COMMIT=true
export CLAUDE_FLOW_AUTO_PUSH=true
export CLAUDE_FLOW_HOOKS_ENABLED=true
export CLAUDE_FLOW_CHECKPOINTS_ENABLED=true
export GITHUB_AUTO_SYNC=true
```

### Disable Auto Commit/Push
```bash
# Edit ~/.bashrc
export CLAUDE_FLOW_AUTO_COMMIT=false
export CLAUDE_FLOW_AUTO_PUSH=false

# Edit ~/.zshrc (if using zsh)
export CLAUDE_FLOW_AUTO_COMMIT=false
export CLAUDE_FLOW_AUTO_PUSH=false

# Edit ~/.config/environment.d/claude-flow.conf
CLAUDE_FLOW_AUTO_COMMIT=false
CLAUDE_FLOW_AUTO_PUSH=false

# Then reload shell
source ~/.bashrc  # or source ~/.zshrc
```

### Temporary Override (Single Session)
```bash
# Disable for current session only
export CLAUDE_FLOW_AUTO_COMMIT=false
export CLAUDE_FLOW_AUTO_PUSH=false

# Run claude-flow
npx claude-flow hive-mind spawn "task"
```

### Verify Active Configuration
```bash
# Check environment variables
env | grep CLAUDE_FLOW

# Should show:
# CLAUDE_FLOW_AUTO_COMMIT=true
# CLAUDE_FLOW_AUTO_PUSH=true
# CLAUDE_FLOW_HOOKS_ENABLED=true
# CLAUDE_FLOW_CHECKPOINTS_ENABLED=true
```

---

## 📊 Related Configuration

### Other Agent Tool Configs
```typescript
linter: { strict: true, autoFix: true }      // Auto-fix linting errors
formatter: { style: 'prettier', tabSize: 2 } // Auto-format code
```

### Agent Permissions
The coder agent has these git-related permissions enabled:
- `git-access`: Full git command access
- `file-read`: Read repository files
- `file-write`: Modify repository files
- `terminal-access`: Execute git commands

---

## 🧪 Testing

### Quick Test
```bash
# 1. Initialize test repository
mkdir /tmp/test-auto-commit && cd /tmp/test-auto-commit
git init
git remote add origin <your-repo-url>

# 2. Spawn coder agent
npx claude-flow hive-mind spawn "Create hello world function"

# 3. Verify auto commit/push
git log -1  # Should show AI-generated commit
git status  # Should be clean (changes pushed)
```

### Expected Behavior
✅ Code files created/modified
✅ Changes automatically staged
✅ Commit created with AI message
✅ Commit pushed to remote
✅ Working directory clean

---

## 📖 References

- **Claude-Flow**: https://github.com/ruvnet/claude-flow
- **Coder Agent Source**: `/root/.nvm/versions/node/v22.21.0/lib/node_modules/claude-flow/src/cli/agents/coder.ts`
- **Version**: `2.7.0-alpha.14`
- **Modified**: 2025-10-28

---

## 🎉 Status

**Configuration**: ✅ ENABLED
**Auto Commit**: ✅ ACTIVE
**Auto Push**: ✅ ACTIVE
**Auto Sync**: ✅ ACTIVE

All git operations from the coder agent will now automatically commit and push changes to the remote repository.
