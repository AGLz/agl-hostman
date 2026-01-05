# PostgreSQL Credentials - Quick Reference

> **Last Updated**: 2026-01-05
> **Servers**: AGLSRV1 (192.168.0.245)
> **⚠️ WARNING**: Development credentials - CHANGE BEFORE PRODUCTION!

---

## 🚀 Quick Connection Strings

### CT149 - PostgreSQL 17 (Native)

```
Host: 192.168.0.149
Port: 5432
Database: postgres / archon
User: postgres
Password: cJ8VMZLr84XSSZaucSRsa8JwvRFgUON6

Connection String:
postgresql://postgres:cJ8VMZLr84XSSZaucSRsa8JwvRFgUON6@192.168.0.149:5432/postgres
```

**CLI Access:**
```bash
export PGPASSWORD='cJ8VMZLr84XSSZaucSRsa8JwvRFgUON6'
psql -h 192.168.0.149 -U postgres -d postgres
```

---

### CT184 - Supabase (PostgreSQL 15.8)

```
Host: 192.168.0.184
Port: 5432 (transaction) / 6543 (session)
Database: postgres
User: postgres
Password: cJ8VMZLr84XSSZaucSRsa8JwvRFgUON6

Connection String:
postgresql://postgres:cJ8VMZLr84XSSZaucSRsa8JwvRFgUON6@192.168.0.184:5432/postgres
```

**Supabase Studio:**
```
URL: http://192.168.0.184:3000
User: supabase
Pass: TESRjOmK3olMIPL1
```

**API Gateway:**
```
URL: http://192.168.0.184:8000
Service Role Key: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3Njc1NjY1ODksImV4cCI6MTkyNTI0NjU4OX0.FH8qCZMjG5Hjq-gu9g21V8-7eKPZoKOcv8Y3eZ92V3o
JWT Secret: 3JPj1YjnzfvkAQoYBqBKdZBHChH4zW2nfcpwWBdlx3WT8RWIb1dE658GZ3ctyW
```

---

## 🧪 Quick Test Commands

### Test CT149
```bash
# From local machine
PGPASSWORD='cJ8VMZLr84XSSZaucSRsa8JwvRFgUON6' psql -h 192.168.0.149 -U postgres -d postgres -c "SELECT version();"

# Check if listening
nc -zv 192.168.0.149 5432
```

### Test CT184
```bash
# Test API
curl -s http://192.168.0.184:8000/rest/v1/archon_settings \
  -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3Njc1NjY1ODksImV4cCI6MTkyNTI0NjU4OX0.FH8qCZMjG5Hjq-gu9g21V8-7eKPZoKOcv8Y3eZ92V3o" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3Njc1NjY1ODksImV4cCI6MTkyNTI0NjU4OX0.FH8qCZMjG5Hjq-gu9g21V8-7eKPZoKOcv8Y3eZ92V3o"
```

---

## 🔧 Service Management

### From AGLSRV1 (192.168.0.245)

```bash
# CT149 PostgreSQL
ssh root@192.168.0.245 'pct exec 149 -- systemctl status postgresql'
ssh root@192.168.0.245 'pct exec 149 -- systemctl restart postgresql'

# CT184 Supabase
ssh root@192.168.0.245 'pct exec 184 -- docker ps'
ssh root@192.168.0.245 'pct exec 184 -- cd /root/supabase/docker && docker compose restart'

# CT183 Archon
ssh root@192.168.0.245 'pct exec 183 -- systemctl status archon'
ssh root@192.168.0.245 'pct exec 183 -- systemctl restart archon'
```

---

## 📊 Service Endpoints

| Service | CT | URL | Status |
|---------|----|----|--------|
| PostgreSQL Native | 149 | 192.168.0.149:5432 | ✅ |
| Supabase API | 184 | http://192.168.0.184:8000 | ✅ |
| Supabase Studio | 184 | http://192.168.0.184:3000 | ✅ |
| Archon API | 183 | http://192.168.0.183:8181 | ✅ |
| Archon MCP | 183 | http://192.168.0.183:8051/mcp | ✅ |
| Archon UI | 183 | http://192.168.0.183:3737 | ✅ |

---

**⚠️ SECURITY REMINDER**: Change all passwords before production deployment!
