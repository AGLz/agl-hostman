# CT183 (Archon) - Quick Start Guide

## 🚀 Immediate Next Steps

Your new Archon container (CT183) is ready! Follow these steps to complete the deployment:

---

## 1. Create Supabase Account (5 minutes)

### Sign Up
1. Go to https://supabase.com
2. Sign up with GitHub or email
3. Verify your email

### Create Project
1. Click "New Project"
2. **Project name**: `archon-aglsrv1` (or your choice)
3. **Database password**: Choose a strong password (save it!)
4. **Region**: Select closest region (e.g., South America for Brazil)
5. Click "Create new project"
6. Wait 2-3 minutes for provisioning

---

## 2. Get Supabase Credentials (2 minutes)

### ⚠️ CRITICAL: Use SERVICE ROLE KEY (Not Anon Key!)

1. Go to your project dashboard
2. Navigate to **Settings** → **API**
   - Direct URL: `https://supabase.com/dashboard/project/YOUR_PROJECT_ID/settings/api`

3. Copy **Project URL**:
   ```
   https://abcdefghijklmnop.supabase.co
   ```

4. Copy **service_role key** (scroll down to "Project API keys"):
   - ✅ **Correct**: Look for the key labeled "service_role"
   - ✅ **Correct**: It's very LONG (starts with `eyJ...`, ~300+ characters)
   - ❌ **Wrong**: DO NOT use "anon" or "public" key (shorter)
   - ❌ **Wrong**: Using wrong key causes "permission denied" errors

**How to tell them apart**:
```bash
# SERVICE ROLE KEY (CORRECT) - Use this one!
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im...
# ^ Contains "service_role" in the JWT, very long

# ANON KEY (WRONG) - Don't use this
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im...
# ^ Contains "anon" in the JWT, shorter than service_role
```

---

## 3. Configure Archon (3 minutes)

### Connect to CT183
```bash
# From your machine (via SSH)
ssh root@192.168.0.183  # LAN access

# Or from CT179 (fastest)
ssh root@192.168.0.183
```

### Edit Environment File
```bash
cd /root/Archon
nano .env
```

### Update These 2 Lines
```env
# Replace these with your Supabase credentials
SUPABASE_URL=https://YOUR_PROJECT_ID.supabase.co
SUPABASE_SERVICE_KEY=YOUR_SERVICE_ROLE_KEY_HERE
```

**Example** (with fake values):
```env
SUPABASE_URL=https://xyzabc123.supabase.co
SUPABASE_SERVICE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh5emFiYzEyMyIsInJvbGUiOiJzZXJ2aWNlX3JvbGUiLCJpYXQiOjE2ODc0NTYwMDB9.LONG_STRING_HERE
```

**Save & Exit**:
- Press `Ctrl + O` to save
- Press `Enter` to confirm
- Press `Ctrl + X` to exit

---

## 4. Deploy Archon (1 minute)

### Start Services
```bash
cd /root/Archon
docker compose up -d
```

### Verify Deployment
```bash
# Check services are running
docker compose ps

# Should see:
# archon-server   Up   0.0.0.0:8181->8181/tcp
# archon-mcp      Up   0.0.0.0:8051->8051/tcp
# archon-ui       Up   0.0.0.0:3737->3737/tcp
```

### View Logs (Optional)
```bash
# Watch logs in real-time
docker compose logs -f

# Press Ctrl+C to exit
```

---

## 5. Access Archon UI (1 minute)

### Open Browser
```
http://192.168.0.183:3737
```

### First-Time Setup
1. Complete initial setup wizard
2. Create admin account
3. Configure default AI model (OpenAI/Gemini/Ollama)

---

## 6. Configure Claude Code MCP (5 minutes)

### On Your Development Machine

**Edit MCP Settings**:
```bash
# Location varies by OS:
# Linux/WSL: ~/.config/Code/User/globalStorage/claude-code/settings/mcp.json
# macOS: ~/Library/Application Support/Code/User/globalStorage/claude-code/settings/mcp.json
# Windows: %APPDATA%\Code\User\globalStorage\claude-code\settings\mcp.json

# Or use Claude Code command: Settings → MCP Servers
```

**Add Archon Server**:
```json
{
  "mcpServers": {
    "archon-aglsrv1": {
      "transport": "sse",
      "url": "http://192.168.0.183:8051/sse",
      "description": "AGL Infrastructure knowledge base"
    }
  }
}
```

### Test Connection
1. Restart Claude Code
2. Check MCP status (should show "archon-aglsrv1: Connected")
3. Test query: "What containers are running on AGLSRV1?"

---

## 7. Populate Knowledge Base (10 minutes)

### Upload Infrastructure Docs

**Via Web UI** (easiest):
1. Open http://192.168.0.183:3737
2. Go to "Documents" section
3. Click "Upload" button
4. Select files from `/root/agl-hostman/docs/`
5. Tag documents: "infrastructure", "proxmox", "wireguard"

**Key Documents to Upload**:
- `CLAUDE.md` (infrastructure overview)
- `docs/ct183-deployment-guide.md` (this container)
- `docs/archon-integration-guide.md` (integration patterns)
- Any container deployment guides (`docs/ct*-*.md`)

**Via API** (advanced):
```bash
# From CT183 or any machine with access
cd /root/agl-hostman

# Upload CLAUDE.md
curl -X POST http://192.168.0.183:8181/api/documents/upload \
  -F "file=@CLAUDE.md" \
  -F "tags=infrastructure,core"

# Batch upload all docs
for file in docs/*.md; do
  echo "Uploading $file..."
  curl -X POST http://192.168.0.183:8181/api/documents/upload \
    -F "file=@$file"
done
```

---

## ✅ Deployment Verification Checklist

Run these checks to confirm everything is working:

### 1. Container Status
```bash
ssh root@192.168.0.245 'pct status 183'
# Should show: status: running
```

### 2. Docker Services
```bash
ssh root@192.168.0.183 'docker ps | grep archon'
# Should show 3 containers: server, mcp, ui
```

### 3. Network Connectivity
```bash
# From any machine on LAN
curl -I http://192.168.0.183:3737
# Should return: HTTP/1.1 200 OK

curl http://192.168.0.183:8051/health
# Should return: {"status": "healthy"}
```

### 4. MCP Connection
```bash
# From Claude Code
# Type: "Search Archon knowledge base for containers"
# Should return: Results from uploaded documents
```

### 5. Knowledge Base
```bash
# Check documents count
curl http://192.168.0.183:8181/api/documents/count
# Should return: {"count": N} where N > 0
```

---

## 🔧 Troubleshooting

### Issue: "Permission denied" when saving documents

**Cause**: Using anon key instead of service_role key

**Solution**:
```bash
ssh root@192.168.0.183
cd /root/Archon
nano .env
# Replace SUPABASE_SERVICE_KEY with the CORRECT service_role key
# (the longer one, contains "service_role" in JWT)
docker compose restart
```

### Issue: Cannot connect to Archon UI

**Check firewall**:
```bash
ssh root@192.168.0.183 'ufw status'
# If enabled, allow port 3737:
ssh root@192.168.0.183 'ufw allow 3737/tcp'
```

**Check Docker**:
```bash
ssh root@192.168.0.183 'docker compose logs archon-ui'
# Look for errors
```

### Issue: MCP connection fails

**Check MCP server**:
```bash
curl http://192.168.0.183:8051/health
# Should return: {"status": "healthy"}
```

**Check Claude Code config**:
1. Verify MCP URL: `http://192.168.0.183:8051/sse`
2. Restart Claude Code
3. Check MCP logs: Settings → MCP Servers → View Logs

---

## 📚 Next Steps (After Basic Setup)

### 1. Configure WireGuard (Optional)
- Enable remote MCP access: `http://10.6.0.23:8051/sse`
- See: `/root/agl-hostman/docs/ct183-deployment-guide.md`

### 2. Configure Tailscale (Optional)
- Cross-site access for remote work
- MCP URL: `http://100.x.x.x:8051/sse`

### 3. Automate Documentation Sync
- Cron job to sync container configs
- Real-time updates via Proxmox hooks
- See: `/root/agl-hostman/docs/archon-integration-guide.md`

### 4. Multi-AI Integration
- Configure Cursor IDE
- Configure Windsurf IDE
- Share knowledge across all assistants

---

## 📞 Getting Help

### Documentation
- **Full Deployment Guide**: `/root/agl-hostman/docs/ct183-deployment-guide.md`
- **Integration Guide**: `/root/agl-hostman/docs/archon-integration-guide.md`
- **Archon Research**: `/root/agl-hostman/docs/archon-research/`

### Official Resources
- Archon GitHub: https://github.com/coleam00/Archon
- Supabase Docs: https://supabase.com/docs
- Docker Docs: https://docs.docker.com

### Common Commands
```bash
# Restart Archon
ssh root@192.168.0.183 'cd /root/Archon && docker compose restart'

# View logs
ssh root@192.168.0.183 'cd /root/Archon && docker compose logs -f'

# Stop Archon
ssh root@192.168.0.183 'cd /root/Archon && docker compose down'

# Update Archon
ssh root@192.168.0.183 'cd /root/Archon && git pull && docker compose up -d --build'
```

---

**Quick Start Version**: 1.0
**Last Updated**: 2025-10-27
**Estimated Time**: 15-20 minutes total
