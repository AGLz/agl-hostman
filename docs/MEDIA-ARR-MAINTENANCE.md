# Media *arr — modo manutenção (downloads parados, grabs activos)

> **Estado actual (2026-05-29):** **grabs ON** (Prowlarr RSS + pesquisa automática) · **downloads OFF** (clientes Radarr/Sonarr desactivados, Autobrr parado).  
> **Não reactivar clientes de download** até haver espaço livre no storage (AGLSRV3 em expansão).

Documentação completa: **[`MEDIA-ARR-STACK-AGL.md`](MEDIA-ARR-STACK-AGL.md)**.

---

## Motivo

- Storage **sem espaço** nas root folders.
- Expansão em curso no **AGLSRV3**.
- Queres **continuar a encontrar releases** (grabs/fila) **sem** transferir ficheiros (qBit/SABnzbd/Aria2).

---

## Modos de operação

| Modo | Prowlarr RSS/auto | Clientes download *arr | Autobrr | Uso |
|------|-------------------|-------------------------|---------|-----|
| **Actual (grabs only)** | ON | OFF | OFF | Preencher fila sem ocupar disco |
| Freeze total | OFF | OFF | OFF | `arr-freeze-downloads.sh --no-grabs` |
| Normal | ON | ON | ON | `arr-unfreeze-downloads.sh` (após espaço) |

---

## Estado **antes** de qualquer freeze (referência)

| Componente | Configuração |
|------------|----------------|
| Radarr / Sonarr | Clientes **activos:** Aria2, qBittorrent AGLSRV1, SABnzbd |
| Prowlarr `Standard` | RSS **ON**, auto **ON** |
| Autobrr | **Activo** |

---

## O que está aplicado agora (grabs only)

| Componente | Estado | Efeito |
|------------|--------|--------|
| **Prowlarr** | RSS **ON**, pesquisa automática **ON** | Indexadores e sync para Radarr/Sonarr |
| **Radarr / Sonarr** | Clientes download **OFF** | Grabs podem entrar na **fila**; **não** enviam para qBit/SAB/Aria2 |
| **Autobrr** | **Parado** | Evita envio directo ao qBittorrent (contorna os *arr) |
| **qBittorrent** | Sem transferências activas forçadas | Fila histórica intacta |

**Nota:** a fila Radarr/Sonarr pode **crescer** com novos grabs; isso é esperado. Limpar ou importar só depois de haver espaço.

---

## Verificação rápida

```bash
# A partir do repo agl-hostman
bash scripts/media/arr-freeze-downloads.sh --verify-only
```

Saída esperada (modo grabs only):

- `Radarr: enabled=[]`
- `Sonarr: enabled=[]`
- `Prowlarr Standard: enableRss=True, enableAutomaticSearch=True, enableInteractiveSearch=True`
- `Autobrr: inactive`

Verificação manual (API keys lidas no CT, não documentadas aqui):

```bash
ssh root@100.107.113.33 'RADARR_KEY=$(pct exec 123 -- grep -oP "(?<=<ApiKey>)[^<]+" /var/lib/radarr/config.xml | head -1)
pct exec 123 -- curl -s -H "X-Api-Key: $RADARR_KEY" http://127.0.0.1:7878/api/v3/downloadclient \
  | python3 -c "import sys,json; print([x[\"name\"] for x in json.load(sys.stdin) if x[\"enable\"]])"'
```

---

## Antes de reactivar (checklist)

Ligar com **Fase 0–5** em [`MEDIA-ARR-STACK-AGL.md`](MEDIA-ARR-STACK-AGL.md).

1. **Espaço:** root folders com espaço livre validado (`df`, UI Radarr → Settings → Media Management).
2. **AGLSRV3:** novos discos integrados no pool usado por `/mnt/storage` (ou path canónico definido).
3. **Mounts:** CT121 (qBittorrent) com `mp0–mp9` alinhados a CT123/124/113.
4. **Fila:** limpar ou rever ~2768 itens Radarr (não reactivar cegamente).
5. **Indexadores:** Prowlarr-only, limites 429, RSS ≥15–20 min.
6. **Qualidade:** TRaSH/Recyclarr (Fase 3) — recomendado antes de volume alto de grabs.

---

## Reactivar downloads

```bash
bash scripts/media/arr-unfreeze-downloads.sh
```

O script pede confirmação interactiva. **Não** guarda passwords no Git; reactiva:

- Prowlarr `Standard` (RSS + auto search ON)
- Clientes Aria2, qBittorrent AGLSRV1, SABnzbd em Radarr/Sonarr
- Autobrr (`systemctl start`)

Ordem recomendada manual (se fizeres na UI): Prowlarr → Radarr/Sonarr → Autobrr → monitorizar disco.

---

## Só parar grabs de novo (downloads já off)

```bash
bash scripts/media/arr-freeze-downloads.sh --no-grabs
```

## Só reactivar grabs (sem downloads)

```bash
bash scripts/media/arr-enable-grabs.sh
```

## Parar tudo (grabs + downloads)

```bash
bash scripts/media/arr-freeze-downloads.sh --no-grabs
```

---

## CTs do stack (referência)

| VMID | Serviço | LAN |
|------|---------|-----|
| 123 | Radarr | 192.168.0.123:7878 |
| 124 | Sonarr | 192.168.0.124:8989 |
| 172 | Prowlarr | 192.168.0.172:9696 |
| 121 | qBittorrent | 192.168.0.121:8090 |
| 141 | SABnzbd | 192.168.0.141 |
| 144 | Autobrr | 192.168.0.144 |
| 113 | Plex | 192.168.0.113 |

Ver também [`INFRA.md`](INFRA.md) (secção Media & Automation).
