---
description: Auto-commit changes with AI-generated message and push to remote
---

# Auto-commit and Push Workflow

Execute the following steps in sequence:

1. **Stage all changes**:
   - Run: `git add .`
   - Verify: `git status`

2. **Generate AI commit message**:
   - Analyze `git diff --staged` 
   - Create conventional commit message with:
     - Type (feat/fix/docs/refactor/test/chore/perf)
     - Scope (component/module affected)
     - Clear description
     - Body with details if changes are significant
     - Include metrics if applicable
     - Add "🤖 Generated with Claude Code" footer

3. **Create commit**:
   - Use the generated message
   - Include co-author if applicable

4. **Push to remote**:
   - Run: `git push`
   - If upstream not set, run: `git push -u origin <current-branch>`

5. **Verify**:
   - Show commit hash
   - Confirm push succeeded

**Example commit format**:
```
feat(auth): add JWT token refresh mechanism

- Implement automatic token refresh before expiration
- Add refresh token rotation for security
- Update authentication middleware
- Add unit tests for refresh logic

Performance: 40% reduction in authentication overhead

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>
```

Execute all steps automatically without asking for confirmation unless errors occur.
