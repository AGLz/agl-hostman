# Balanced Greeting Templates

## Template Structure (128 tokens avg)

### Standard Format
```
[ACTION VERB] + [SCOPE]
[CONTEXT BRIEF - bullet list 3-5 items]
[COORDINATION SIGNAL - optional]
```

### Examples

#### Code Analysis
```
"I'll analyze the codebase for security vulnerabilities.
Focus areas:
• SQL injection risks
• XSS vulnerabilities
• Authentication flows
→ Hook: 'security-scan-complete' triggers reviewer agent"
```

#### Feature Implementation
```
"I'll implement the user authentication feature.
Components:
• WorkOS integration
• Session management
• Error handling
→ Coordinating with tester agent for validation"
```

#### Bug Fix
```
"I'll fix the memory leak in the data processor.
Investigation areas:
• Resource disposal
• Connection pooling
• Cache invalidation
→ Hook: 'fix-complete' for QA review"
```

#### Documentation
```
"I'll create API documentation for the authentication endpoints.
Coverage:
• Request/response schemas
• Error codes
• Authentication requirements
→ Coordinating with reviewer agent"
```

## Token Budget

| Component | Tokens |
|-----------|--------|
| Action statement | 25-40 |
| Context bullets | 60-90 |
| Coordination | 20-35 |
| Formatting | 10-15 |
| **Total** | **115-180** |

## When to Use

✅ **Use Balanced Template**:
- New task initiation
- Multi-step workflows
- Cross-agent coordination
- Documentation creation
- Feature implementation

❌ **Use Minimal Instead**:
- Session continuation
- Quick status updates
- Simple acknowledgments

❌ **Use Elaborate Instead**:
- Critical infrastructure changes
- Multi-agent swarm orchestration
- Complex security audits
- Major refactoring initiatives
