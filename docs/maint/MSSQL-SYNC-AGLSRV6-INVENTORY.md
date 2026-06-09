# Inventário MSSQL — sync VM620 ↔ CT610 (AGLSRV6)

**Data:** 2026-06-06  
**Host Proxmox:** man6 (`100.98.108.66`)  
**Credenciais CT610:** `ald-sys8/src/.env` (`DB_*_SYS` / `DB_*_ALD`, utilizador `sa`)

## Nós

| Nó | ID | IP LAN | IP Tailscale | SO / SQL |
|----|-----|--------|--------------|----------|
| **CT610** `mssql6` | LXC 610 | `192.168.0.110` | `100.117.17.113` | SQL Server **2022 Developer** (16.0.4135.4) Linux |
| **VM620** `WinServer2016-VirtIO` | QEMU 620 | `192.168.0.200` | `100.102.182.100` | SQL Server **2016 Express SP2** (13.0.5026.0) Windows |

## CT610 — instância (validado via sqlcmd)

- **Edição:** Developer Edition (`EngineEdition` = 3)
- **SQL Agent:** **activado** (2026-06-06 via `scripts/mssql-sync/enable-sqlagent-ct610.sh`; `sqlagent.enabled = true`)
- **Porta:** 1433 (LAN + Tailscale)

### Bases de dados

| Base | Recovery | Tabelas | Com PK | ~Linhas |
|------|----------|---------|--------|---------|
| ALD-SYS8 | FULL | 200 | 199 | 174 |
| CEP_Brasil | SIMPLE | 4 | 3 | 606 692 |
| DB_IDE_Associacao | SIMPLE | 83 | 57 | 431 276 |
| SILD | SIMPLE | 21 | 13 | 517 130 |

### SILD — tabelas sem chave primária (bloqueiam sync directo)

`TblCategoriaDeProdutos`, `TblDiaInverno`, `TblDiaNatal`, `TblFaixaEtária`, `TblIdadeGestante`, `TblSenhas`, `TblTiposDeEntidade`, `TblUnidadePeso`

**Acção:** adicionar PK surrogate (`sync_id`) ou excluir do piloto até correcção de schema.

## VM620 — instância (parcial)

- **Estado VM:** running; porta **1433** acessível a partir de man6
- **QEMU guest agent:** indisponível (diagnóstico remoto limitado)
- **Login `sa` com credencial ald-sys8:** **falha** — password SA da VM620 é distinta da do CT610
- **Edição (sessão anterior com guest agent):** Express SP2; SQL Server Agent não suportado

### Bases VM620

Inventário SQL pendente até credencial SA VM620 ou recuperação do guest agent.  
**Hipótese:** clone legado SSPADLD01 / VM200 com bases homólogas às do CT610 (validar com `scripts/mssql-sync/inventory.sh`).

## Rede (man6)

| Verificação | Resultado |
|-------------|-----------|
| `192.168.0.110:1433` | OK |
| `192.168.0.200:1433` | OK |
| `100.117.17.113:1433` | OK (Tailscale CT610) |
| `100.102.182.100:1433` | OK (Tailscale VM620) |

**Sync recomendado:** LAN (`192.168.0.110` ↔ `192.168.0.200`) — menor latência no mesmo host Proxmox.

## Overlap ald-sys8 → CT610

Aplicação **ald-sys8** (`/mnt/overpower/apps/dev/ald/ald-sys8/src/.env`):

- `ALD-SYS8` → `DB_DATABASE_SYS` em `100.117.17.113`
- `DB_IDE_Associacao` → `DB_DATABASE_ALD` em `100.117.17.113`

CT610 é **fonte actual** das apps Laravel ald-sys8. VM620 é nó legado / DR alvo.

## Referências

- Plano: `.cursor/plans/mssql_sync_aglsrv6_e96d6508.plan.md`
- Scripts: `scripts/mssql-sync/`
- Arquitectura: [`MSSQL-SYNC-AGLSRV6-ARCHITECTURE.md`](MSSQL-SYNC-AGLSRV6-ARCHITECTURE.md)
