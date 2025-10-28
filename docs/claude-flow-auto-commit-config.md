# Claude-Flow Auto Commit & Auto Push Configuration

> **Last Updated**: 2025-10-28 | **Status**: ✅ ENABLED

## 📝 Summary

Configurações de auto commit e auto push ativadas no agente coder do claude-flow hive-mind.

---

## 🎯 Configuration Changes

### File Modified
**Path**: `/root/.nvm/versions/node/v22.21.0/lib/node_modules/claude-flow/src/cli/agents/coder.ts`

**Line**: 922

### Original Configuration
```typescript
git: { autoCommit: false, autoSync: true },
```

### New Configuration
```typescript
git: { autoCommit: true, autoPush: true, autoSync: true },
```

---

## ⚙️ What Was Changed

| Setting | Before | After | Description |
|---------|--------|-------|-------------|
| `autoCommit` | `false` | `true` | Automatically create git commits after code changes |
| `autoPush` | N/A | `true` | Automatically push commits to remote repository |
| `autoSync` | `true` | `true` | Keep git repository synchronized |

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

## 🔄 Reverting Changes

To disable auto commit/push, edit the file and change back to:

```typescript
git: { autoCommit: false, autoSync: true },
```

Or create a custom configuration override (recommended for upgrades):

```bash
# Create user config directory
mkdir -p ~/.claude-flow/config

# Create custom coder config
cat > ~/.claude-flow/config/coder-agent.json << 'EOF'
{
  "toolConfigs": {
    "git": {
      "autoCommit": false,
      "autoPush": false,
      "autoSync": true
    }
  }
}
EOF
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
