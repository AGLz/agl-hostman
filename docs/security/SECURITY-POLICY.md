# AGL Infrastructure Security Policy

**Version**: 1.0.0
**Effective Date**: 2026-02-08
**Last Updated**: 2026-02-08
**Owner**: Security Team

---

## 1. Purpose

This document establishes the security policies and procedures for the AGL Hostman infrastructure management platform. All personnel managing, developing, or accessing AGL infrastructure must adhere to these policies.

---

## 2. Scope

This policy applies to:
- All AGL Hostman infrastructure components
- All MCP servers and endpoints
- All development, staging, and production environments
- All personnel with access to AGL systems
- All third-party services and integrations

---

## 3. Password Policy

### 3.1 Password Requirements

All passwords must meet the following requirements:
- **Minimum Length**: 16 characters
- **Complexity**: Must include uppercase, lowercase, numbers, and special characters
- **Expiration**: Rotate every 90 days
- **History**: Cannot reuse last 10 passwords
- **Storage**: Must be hashed using bcrypt or Argon2id

### 3.2 Default Passwords

- Default passwords are prohibited in all environments
- All default credentials must be changed before deployment
- Use `openssl rand -base64 32` to generate secure passwords

### 3.3 Password Management

- Use a password manager (1Password, Bitwarden, or HashiCorp Vault)
- Never share passwords via email, chat, or plain text
- Never hardcode passwords in source code or configuration files
- Use environment variables or secret management for all credentials

---

## 4. Access Control Policy

### 4.1 Principle of Least Privilege

- Users must have minimum necessary access to perform duties
- Access requests must be documented and approved
- Access reviews must be performed quarterly

### 4.2 Role-Based Access Control (RBAC)

Roles and permissions must be defined as follows:

| Role | Access Level | Description |
|------|-------------|-------------|
| Super Admin | Full | Complete system access |
| Admin | High | Management of users and resources |
| Operator | Medium | Operational tasks only |
| Viewer | Read-only | View-only access to dashboards |
| Auditor | Special | Access to audit logs only |

### 4.3 Authentication Requirements

**Production Environment**:
- Multi-factor authentication (MFA) required for admin accounts
- Session timeout: 2 hours maximum
- Lockout after 5 failed attempts
- 30-minute lockout duration

**Development/Staging**:
- Strong password required
- Session timeout: 8 hours maximum
- Lockout after 10 failed attempts

---

## 5. Network Security Policy

### 5.1 Network Segmentation

The AGL infrastructure must be segmented into the following zones:

```
DMZ Zone (10.6.0.0/24)
├── Public-facing services only
├── Archon (10.6.0.21)
└── VPN Gateway

Application Zone (192.168.0.0/24)
├── Application servers
├── Harbor (192.168.0.182)
├── Ollama (192.168.0.200)
└── Proxmox hosts

Data Zone (10.0.0.0/24)
├── Database servers
├── Backup storage
└── File storage
```

### 5.2 Firewall Rules

**Default Policy**: Deny all inbound, Allow all outbound

**Required Rules**:
- Allow WireGuard VPN: UDP/51820
- Allow HTTPS: TCP/443
- Allow HTTP: TCP/80 (redirect to 443)
- Allow SSH: TCP/22 (from VPN only)
- Allow MCP endpoints: TCP/8051 (with authentication)

### 5.3 VPN Access

- All administrative access must occur via VPN
- WireGuard VPN required for infrastructure access
- Tailscale for alternative remote access
- MFA required for VPN authentication

---

## 6. Secrets Management Policy

### 6.1 Secret Storage

All secrets must be stored in one of the following:
- HashiCorp Vault (preferred)
- AWS Secrets Manager
- Azure Key Vault
- Encrypted environment variables (temporary)

### 6.2 Secret Categories

| Category | Rotation | Examples |
|----------|----------|----------|
| Critical | 30 days | Database passwords, API keys |
| High | 90 days | Service credentials, OAuth tokens |
| Medium | 180 days | Application secrets, encryption keys |
| Low | Never | Public keys, non-sensitive configuration |

### 6.3 Secret Generation

Use cryptographically secure methods:
```bash
# Generate 32-byte random key
openssl rand -base64 32

# Generate UUID
uuidgen

# Generate hex string
openssl rand -hex 32
```

---

## 7. API Security Policy

### 7.1 MCP Server Security

All MCP servers must implement:
- API key authentication
- Rate limiting (60 requests/minute default)
- IP whitelisting (when applicable)
- Request/response logging
- TLS encryption in production

### 7.2 API Key Management

- API keys must be at least 64 characters
- API keys must be rotated every 90 days
- API keys must be prefixed with service identifier
- Revoke compromised keys immediately

### 7.3 Rate Limiting

| Endpoint Type | Rate Limit | Burst |
|--------------|-----------|-------|
| Public API | 60/minute | 10 |
| Authenticated | 100/minute | 20 |
| Admin | 200/minute | 50 |
| MCP | 60/minute | 10 |

---

## 8. Data Protection Policy

### 8.1 Data Classification

**Classified Data**:
- Confidential: User data, credentials, secrets
- Internal: Infrastructure details, configurations
- Public: Documentation, non-sensitive information

### 8.2 Encryption Requirements

**At Rest**:
- Database: AES-256-GCM
- File storage: AES-256-GCM
- Backups: AES-256-GCM + GPG

**In Transit**:
- TLS 1.3 minimum
- Strong cipher suites only
- Certificate validation required

### 8.3 Data Retention

- Audit logs: 1 year
- Application logs: 90 days
- Backup data: 90 days (30 days on-site, 60 days off-site)
- User data: Per GDPR requirements

---

## 9. Backup and Recovery Policy

### 9.1 Backup Frequency

| Data Type | Frequency | Retention |
|-----------|-----------|-----------|
| Database | Hourly | 30 days |
| Configuration | Daily | 90 days |
| Application | Weekly | 30 days |
| Logs | Daily | 90 days |

### 9.2 Backup Security

- All backups must be encrypted
- Backups must be stored off-site
- Backup integrity must be verified weekly
- Restoration tests must be performed monthly

### 9.3 Recovery Time Objectives

- RTO (Recovery Time Objective): 4 hours
- RPO (Recovery Point Objective): 1 hour
- Critical services: 1 hour RTO, 15 minutes RPO

---

## 10. Incident Response Policy

### 10.1 Incident Classification

**Severity Levels**:
- **Critical**: System compromise, data breach
- **High**: Service disruption, unauthorized access
- **Medium**: Security control failure, policy violation
- **Low**: Suspicious activity, near-miss

### 10.2 Response Times

| Severity | Response Time | Escalation |
|----------|--------------|------------|
| Critical | 15 minutes | Immediate |
| High | 1 hour | 4 hours |
| Medium | 4 hours | 24 hours |
| Low | 24 hours | 72 hours |

### 10.3 Incident Response Process

1. **Detection**: Identify and confirm incident
2. **Containment**: Limit damage and prevent spread
3. **Eradication**: Remove threat and vulnerability
4. **Recovery**: Restore systems and data
5. **Lessons Learned**: Document and improve processes

---

## 11. Compliance Requirements

### 11.1 SOC2 Compliance

- Access control monitoring
- Change management logging
- Security incident documentation
- Regular penetration testing
- Annual risk assessment

### 11.2 GDPR Compliance

- Data protection by design and default
- User consent management
- Right to access implementation
- Right to erasure implementation
- Data breach notification within 72 hours

### 11.3 OWASP Top 10

Annual compliance assessment against OWASP Top 10:
- A01: Broken Access Control
- A02: Cryptographic Failures
- A03: Injection
- A04: Insecure Design
- A05: Security Misconfiguration
- A06: Vulnerable Components
- A07: Authentication Failures
- A08: Data Integrity Failures
- A09: Logging Failures
- A10: Server-Side Request Forgery

---

## 12. Development Security Policy

### 12.1 Secure Development Lifecycle

- Security requirements in design phase
- Threat modeling for all features
- Code review required for all changes
- Security testing before deployment
- Dependency scanning in CI/CD

### 12.2 Code Security Standards

- No hardcoded credentials
- Input validation on all inputs
- Output encoding to prevent XSS
- Parameterized queries to prevent SQLi
- Proper error handling and logging

### 12.3 Third-Party Dependencies

- Vet all libraries before use
- Keep dependencies up to date
- Run automated vulnerability scans
- Subscribe to security advisories
- Document all dependencies

---

## 13. Monitoring and Logging Policy

### 13.1 Logging Requirements

All systems must log:
- Authentication attempts (success and failure)
- Authorization decisions
- Configuration changes
- Data access
- Security-relevant events
- System errors

### 13.2 Log Retention

- Security logs: 1 year
- Application logs: 90 days
- Audit logs: 7 years (where required)
- Access logs: 1 year

### 13.3 Monitoring Alerts

Alerts must be configured for:
- Failed authentication (5+ attempts)
- Unauthorized access attempts
- Rate limit violations
- System failures
- Anomalies in traffic patterns

---

## 14. Training and Awareness

### 14.1 Security Training

- All personnel: Annual security awareness training
- Developers: Secure coding training
- Administrators: Security operations training
- New hires: Security orientation within 30 days

### 14.2 Phishing Awareness

- Quarterly phishing simulations
- Report phishing attempts
- Verify unexpected communications
- Never share credentials via email

---

## 15. Policy Violations

### 15.1 Reporting

Report policy violations to:
- Security Team: security@aglz.io
- Direct Manager
- Anonymous hotline (if available)

### 15.2 Enforcement

- Unintentional violations: Training and remediation
- Negligent violations: Performance improvement plan
- Malicious violations: Termination and legal action

---

## 16. Policy Review

This policy must be reviewed:
- **Annually**: Comprehensive review
- **As needed**: After security incidents
- **As needed**: After significant changes

---

## 17. Approvals

| Role | Name | Signature | Date |
|------|------|-----------|------|
| Security Lead | _____________ | _____________ | ________ |
| CTO | _____________ | _____________ | ________ |
| Compliance Officer | _____________ | _____________ | ________ |

---

## Appendix A: Security Contact Information

- **Security Team**: security@aglz.io
- **Emergency Response**: emergency@aglz.io
- **Documentation**: https://docs.aglz.io/security

---

## Appendix B: Related Documents

- Security Audit Report: `docs/security/SECURITY-AUDIT-REPORT-2026-02-08.md`
- Incident Response Plan: `docs/security/INCIDENT-RESPONSE-PLAN.md`
- Architecture Documentation: `docs/architecture/`
- MCP Server Documentation: `docs/mcp/`

---

**End of Policy**
