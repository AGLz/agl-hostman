# Elaborate Greeting Templates

## Template Structure (250+ tokens)

### Standard Format
```
[ACTION VERB] + [SCOPE]

## Methodology
[Bullet list: approach, tools, techniques]

## Focus Areas
[Bullet list: specific areas to address]

## Coordination Protocol
[Multi-agent workflow description]

## Success Criteria
[Measurable outcomes]

## Risk Mitigation
[Known risks and mitigation strategies]

## Timeline
[Estimated completion, milestones]
```

### Examples

#### Infrastructure Deployment
```
"I'll deploy the multi-region database infrastructure.

## Methodology
• Terraform for IaC
• Blue-green deployment strategy
• Automated rollback capability
• Monitoring via Prometheus

## Focus Areas
• Primary region: us-east-1
• Disaster recovery: us-west-2
• Replication latency < 100ms
• Data consistency validation

## Coordination Protocol
→ Hook: 'infra-prepare' triggers architect agent
→ Hook: 'infra-deploy' triggers tester agent
→ Hook: 'infra-validate' triggers monitoring agent

## Success Criteria
• 99.99% uptime maintained
• Zero data loss during failover
• Automated backup verification

## Risk Mitigation
• Pre-deployment snapshot
• Staged rollout (10% → 50% → 100%)
• Real-time rollback capability

## Timeline
• Preparation: 2 hours
• Deployment: 4 hours
• Validation: 2 hours
• Total: 8 hours"
```

#### Security Audit
```
"I'll conduct a comprehensive security audit of the authentication system.

## Methodology
• OWASP Top 10 vulnerability scan
• Static code analysis (SonarQube)
• Dynamic penetration testing
• Manual code review

## Focus Areas
• SQL injection vectors
• XSS vulnerabilities
• CSRF protection
• Authentication bypass
• Session hijacking risks
• Password strength validation
• Rate limiting effectiveness

## Coordination Protocol
→ Hook: 'security-scan-start' notifies all agents
→ Hook: 'vulnerability-found' triggers security specialist
→ Hook: 'scan-complete' triggers reviewer agent
→ Hook: 'remediation-plan' requires approval

## Success Criteria
• Zero critical vulnerabilities
• < 3 medium severity issues
• 100% remediation documentation
• Automated regression tests

## Risk Mitigation
• Non-destructive scanning first
• Staging environment validation
• Emergency rollback procedures
• Executive stakeholder notification

## Timeline
• Automated scanning: 4 hours
• Manual review: 8 hours
• Remediation: 16 hours
• Documentation: 4 hours
• Total: 32 hours (4 days)"
```

## Token Budget

| Component | Tokens |
|-----------|--------|
| Action statement | 30-50 |
| Methodology | 40-60 |
| Focus areas | 60-100 |
| Coordination | 40-70 |
| Success criteria | 30-50 |
| Risk mitigation | 30-50 |
| Timeline | 20-40 |
| **Total** | **250-420** |

## When to Use

✅ **Use Elaborate Template**:
- Critical infrastructure changes
- Multi-agent swarm orchestration
- Comprehensive security audits
- Major refactoring initiatives
- High-risk deployments
- Cross-team coordination

⚠️ **Use with Caution**:
- High token cost (250-420)
- Longer time to first action
- Potential information overload

❌ **Use Balanced Instead**:
- Standard feature development
- Routine bug fixes
- Documentation tasks
- Low-risk operations
