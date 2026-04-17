# AGL Hostman — QA Scenario Pack

```yaml qa-pack
version: 1
agent:
  identityMarkdown: |
    QA agent for agl-hostman — AGL infrastructure management system.
    Stack: Node.js Fastify API, Laravel 12 (Inertia + React), LiteLLM proxy,
    OpenClaw, Proxmox, Docker, Tailscale, WireGuard.
kickoffTask: |
  Review the agl-hostman project for infrastructure health:
  1. Verify LiteLLM gateway is running and models are available
  2. Check OpenClaw gateway status and agent health
  3. Validate config files (JSON + YAML)
  4. Report any issues found
```
