# MCP Server Troubleshooting Guide

**Task**: AGL-25 - MCP Server Optimization
**Project**: AGL Hostman (550e8400-e29b-41d4-a716-446655440000)
**Last Updated**: 2026-02-08

---

## Quick Reference

### Health Check Commands

```bash
# Run comprehensive health check
./scripts/mcp-monitoring/mcp-health-check.sh check

# View health report
./scripts/mcp-monitoring/mcp-health-check.sh report

# Restart unhealthy servers
./scripts/mcp-monitoring/mcp-health-check.sh restart

# Continuous monitoring (60s interval)
./scripts/mcp-monitoring/mcp-health-check.sh monitor 60
```

### Auto-Restart Service

```bash
# Start auto-restart daemon
./scripts/mcp-monitoring/mcp-auto-restart.sh start

# Check status
./scripts/mcp-monitoring/mcp-auto-restart.sh status

# Stop service
./scripts/mcp-monitoring/mcp-auto-restart.sh stop

# Install as systemd service
./scripts/mcp-monitoring/mcp-auto-restart.sh systemd
```

---

## MCP Servers Configuration

### Local (npx-based) Servers

| Server | Command | Status | Notes |
|--------|---------|--------|-------|
| claude-flow | `npx claude-flow@alpha mcp start` | Operational | Core orchestration |
| ruv-swarm | `npx ruv-swarm mcp start` | Fixed (v1.0.20) | Enhanced coordination |
| flow-nexus | `npx flow-nexus@latest mcp start` | Operational | Cloud features |
| exa | `npx -y exa-mcp-server` | Operational | Search |
| agentic-payments | `npx agentic-payments@latest mcp` | Operational | Payments |

### HTTP-based Servers

| Server | URL | Status | Troubleshooting |
|--------|-----|--------|-----------------|
| archon | `http://192.168.0.183:8052/mcp` | Connected | No /health endpoint |
| archon-tailscale | `http://100.80.30.59:8051/mcp` | Connected | Verify Tailscale |

---

## Common Issues and Solutions

### Issue: ruv-swarm Failed to Connect

**Symptoms:**
- Error: "Failed to connect" in MCP list
- Cannot access ruv-swarm tools

**Root Cause:**
Package not installed globally

**Solution:**
```bash
# Install latest version
npm install -g ruv-swarm@latest

# Verify installation
npm list -g ruv-swarm

# Restart Claude Code
```

**Prevention:**
- Auto-restart service handles package updates
- Health check monitors package availability

---

### Issue: archon Server 404 Errors

**Symptoms:**
- `curl http://192.168.0.183:8052/health` returns 404
- MCP connection shows "Connected" but health endpoint missing

**Root Cause:**
Archon MCP server doesn't expose `/health` endpoint

**Solution:**
1. Verify MCP endpoint is reachable:
```bash
curl http://192.168.0.183:8052/mcp
```

2. Check archon service status:
```bash
ssh aglsrv1 "systemctl status archon"
```

3. Review archon logs:
```bash
ssh aglsrv1 "journalctl -u archon -n 50"
```

4. Check nginx config (if reverse proxy):
```bash
ssh aglsrv1 "cat /etc/nginx/sites-available/archon"
```

---

### Issue: archon-tailscale Connection Failed

**Symptoms:**
- Cannot reach `http://100.80.30.59:8051/mcp`
- Tailscale IP may have changed

**Root Cause:**
- Tailscale disconnected
- IP address changed
- Archon service not running on remote host

**Solution:**
1. Check Tailscale status:
```bash
tailscale status | grep aglsrv1
```

2. Verify current IP:
```bash
tailscale status --json | jq -r '.Peer[] | select(.Hostname=="aglsrv1") | .TailscaleIPs[0]'
```

3. Update MCP config if IP changed:
```bash
# Edit Claude Desktop config
claude mcp remove archon-tailscale
claude mcp add archon-tailscale http://[NEW_IP]:8051/mcp
```

4. Test connection:
```bash
curl -v http://100.80.30.59:8051/mcp
```

---

### Issue: npx Command Not Found

**Symptoms:**
- "npx: command not found"
- All npx-based MCP servers fail

**Root Cause:**
Node.js not installed or not in PATH

**Solution:**
```bash
# Check Node.js installation
which node
node --version

# If not installed, install via nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
source ~/.bashrc
nvm install --lts

# Verify npx
which npx
npx --version
```

---

### Issue: MCP Server Timeout

**Symptoms:**
- Servers take long time to connect
- Intermittent failures

**Root Cause:**
Network latency or package download time

**Solution:**
1. Check network connectivity:
```bash
ping registry.npmjs.org
```

2. Clear npm cache:
```bash
npm cache clean --force
```

3. Use npm mirror (if in China):
```bash
npm config set registry https://registry.npmmirror.com
```

4. Pre-install packages globally:
```bash
npm install -g claude-flow@alpha
npm install -g ruv-swarm@latest
npm install -g flow-nexus@latest
```

---

## Advanced Diagnostics

### Check MCP Server Logs

```bash
# View health check logs
cat logs/mcp-monitoring/mcp-alerts.log

# View auto-restart logs
cat logs/mcp-monitoring/auto-restart.log

# Real-time monitoring
tail -f logs/mcp-monitoring/mcp-alerts.log
```

### Manual Connection Testing

```bash
# Test HTTP server
curl -v --connect-timeout 5 http://192.168.0.183:8052/mcp

# Test with timeout
timeout 10 npx claude-flow@alpha mcp start --help

# Check package availability
npm view claude-flow@alpha
npm view ruv-swarm
```

### Debug Mode

```bash
# Enable verbose logging
export DEBUG=mcp:*
claude mcp list

# Test individual server
npx ruv-swarm mcp start --verbose
```

---

## Performance Optimization

### Reduce MCP Startup Time

```bash
# Pre-install all packages
npm install -g claude-flow@alpha ruv-swarm flow-nexus exa-mcp-server agentic-payments

# Clear npm cache weekly
0 3 * * 0 npm cache clean --force
```

### Monitor Resource Usage

```bash
# Check npx processes
ps aux | grep npx

# Monitor memory
watch -n 5 'ps aux | grep -E "(claude-flow|ruv-swarm)" | awk "{print \$4, \$11}"'
```

### Network Optimization

For remote MCP servers (archon, archon-tailscale):

1. **Enable keep-alive:**
```bash
# In nginx config for archon
proxy_set_header Connection "";
proxy_http_version 1.1;
```

2. **Adjust timeouts:**
```nginx
proxy_connect_timeout 60s;
proxy_send_timeout 60s;
proxy_read_timeout 60s;
```

---

## Automated Monitoring Setup

### Cron-based Monitoring

```bash
# Add to crontab
crontab -e

# Check every 5 minutes
*/5 * * * * /mnt/overpower/apps/dev/agl/agl-hostman/scripts/mcp-monitoring/mcp-health-check.sh check >> /mnt/overpower/apps/dev/agl/agl-hostman/logs/mcp-monitoring/cron.log 2>&1

# Daily health report
0 8 * * * /mnt/overpower/apps/dev/agl/agl-hostman/scripts/mcp-monitoring/mcp-health-check.sh report | mail -s "MCP Health Report" admin@agl.io
```

### systemd Service

```bash
# Create service
./scripts/mcp-monitoring/mcp-auto-restart.sh systemd

# Enable and start
sudo systemctl enable mcp-auto-restart
sudo systemctl start mcp-auto-restart

# Check status
sudo systemctl status mcp-auto-restart

# View logs
sudo journalctl -u mcp-auto-restart -f
```

---

## Prometheus Metrics Export

For integration with existing monitoring stack:

```bash
# Access metrics endpoint
curl http://localhost:9090/metrics | grep mcp

# Metrics available:
# - mcp_server_up{server="claude-flow"}
# - mcp_server_response_time_seconds{server="ruv-swarm"}
# - mcp_restart_total{server="exa"}
```

---

## Escalation Procedures

### Level 1: Auto-Recovery
- Triggered by: mcp-auto-restart.sh
- Actions: Package reinstallation, cooldown periods
- Max attempts: 3 per server per hour

### Level 2: Manual Intervention
Required when:
- Auto-restart fails 3+ times
- HTTP servers unreachable
- Network issues detected

Actions:
1. Check logs: `logs/mcp-monitoring/`
2. Run diagnostics: `mcp-health-check.sh check`
3. Manual restart: `mcp-health-check.sh restart`
4. Verify network: `ping` and `curl` tests

### Level 3: System Administrator
Required when:
- Circuit breaker open
- Multiple servers down
- Security concerns

Contact: System Administrator
Escalation: Create ticket in Archon

---

## Health Status Storage

Health status is automatically stored in Archon memory:

```bash
# Store health status
archon memory store swarm/mcp/health --file logs/mcp-monitoring/mcp-health-status.json

# Retrieve health status
archon memory get swarm/mcp/health
```

---

## Maintenance Schedule

### Daily
- Auto-restart daemon monitors continuously
- Health checks every 5 minutes (via cron)

### Weekly
- Review health reports
- Check for package updates
- Review logs for warnings

### Monthly
- Audit MCP server configurations
- Update documentation
- Performance tuning
- Security updates

---

## Contact and Support

- **Project**: AGL Hostman
- **Task**: AGL-25 (MCP Server Optimization)
- **Documentation**: `/docs/mcp-troubleshooting.md`
- **Scripts**: `/scripts/mcp-monitoring/`
- **Logs**: `/logs/mcp-monitoring/`

For issues not covered in this guide, please create a task in Archon with the `mcp` label.
