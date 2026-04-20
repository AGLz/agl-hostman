# PegaProx API - Documentação da Descoberta

**Data:** 2026-04-19  
**CT:** 210 (pegaprox) @ aglsrv1  
**Status:** ✅ Serviço corrigido e running

---

## Problema Encontrado e Corrigido

O serviço PegaProx estava em loop de restart com erro:
```
PermissionError: [Errno 13] Permission denied: 'plugins'
```

**Causa:** O diretório `plugins` não existia e o código tentava criá-lo.

**Correção aplicada:**
```bash
lxc-attach 210 -- bash -c 'mkdir -p /opt/PegaProx/plugins && chown pegaprox:pegaprox /opt/PegaProx/plugins'
lxc-attach 210 -- systemctl restart pegaprox
```

**Status atual:** ✅ Running (verificado via `systemctl status pegaprox`)

---

## Portas e Endpoints

| Porta | Serviço |
|-------|---------|
| 5000 | Web UI principal |
| 5001 | API HTTP |
| 5002 | WebSocket |

---

## Endpoints da API Identificados

### Autenticação
```
POST /api/auth/login              → Login (session-based)
POST /api/auth/logout             → Logout
GET  /api/auth/check              → Verificar sessão
GET  /api/auth/validate           → Validar token
GET  /api/health                  → Health check (sem auth?)
```

### Clusters
```
GET    /api/clusters                          → Listar clusters
POST   /api/clusters                          → Criar cluster
GET    /api/clusters/<id>/nodes               → Nodes do cluster
GET    /api/clusters/<id>/metrics             → Métricas do cluster
GET    /api/clusters/<id>/resources           → Recursos do cluster
GET    /api/clusters/<id>/vms                 → VMs/CTs do cluster
DELETE /api/clusters/<id>                     → Remover cluster
```

### Nodes
```
GET /api/clusters/<id>/nodes/<node>/summary   → Resumo do node
GET /api/clusters/<id>/nodes/<node>/rrddata   → Dados RRD (CPU, RAM)
GET /api/clusters/<id>/nodes/<node>/network   → Configuração de rede
GET /api/clusters/<id>/nodes/<node>/tasks     → Tarefas do node
```

### VMs / CTs
```
GET /api/clusters/<id>/vms                    → Listar todas VMs/CTs
GET /api/clusters/<id>/vms/<node>/<type>/<vmid>/backups  → Backups
```

Nota: `<type>` = `lxc` para containers ou `qemu` para VMs

---

## Autenticação

A API usa **session-based authentication** via decorator `@require_auth`.

**Headers necessários:**
```
Cookie: session=<session_id>
```

**Ou via API Token:** (observado no código)
```
Authorization: Bearer <token>
```

---

## Estrutura de Dados Esperada (baseado no código)

### Cluster Object
```json
{
  "id": "cluster_uuid",
  "name": "Nome do Cluster",
  "host": "192.168.0.xxx",
  "port": 8006,
  "nodes": ["node1", "node2"],
  "connected": true
}
```

### VM/CT Object (esperado)
```json
{
  "vmid": 179,
  "name": "agldv03",
  "type": "lxc",
  "node": "aglsrv1",
  "status": "running",
  "cpu": 0.23,
  "mem": 450000000,
  "maxmem": 2000000000,
  "disk": 12000000000,
  "maxdisk": 32000000000
}
```

---

## Próximos Passos para o Dashboard

1. **Criar sessão/login:** Usar `/api/auth/login` para obter session cookie
2. **Listar clusters:** `GET /api/clusters` → obter cluster_id
3. **Listar VMs/CTs:** `GET /api/clusters/<id>/vms` → obter dados
4. **Polling de métricas:** `GET /api/clusters/<id>/nodes/<node>/rrddata`

---

## Exemplo de Uso (Python)

```python
import requests

# Login
session = requests.Session()
login_resp = session.post('http://localhost:5000/api/auth/login', json={
    'username': 'admin',
    'password': 'senha'
})

# Listar clusters
clusters = session.get('http://localhost:5000/api/clusters').json()

# Listar VMs
vms = session.get(f'http://localhost:5000/api/clusters/{cluster_id}/vms').json()
```

---

## Notas

- A API usa Flask Blueprints (`@bp.route`)
- Permissões são verificadas via `@require_auth(perms=[...])`
- Roles: `ROLE_ADMIN`, `ROLE_USER`
- A API faz proxy para a API nativa do Proxmox (porta 8006)
- Cache é implementado no PegaProx para reduzir chamadas ao Proxmox

---

*Documentação gerada durante Office Hours - 2026-04-19*
