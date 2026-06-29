# Runbook DR — MSSQL VM620 ↔ CT610 (AGLSRV6)

**Última revisão:** 2026-06-06  
**Host:** man6 (`100.98.108.66`)  
**Arquitectura:** SymmetricDS bidireccional (Opção B) — ver [`MSSQL-SYNC-AGLSRV6-ARCHITECTURE.md`](MSSQL-SYNC-AGLSRV6-ARCHITECTURE.md)

## Contactos e nós

| Papel             | Nó                           | IP LAN          | Tailscale         |
| ----------------- | ---------------------------- | --------------- | ----------------- |
| **Primário apps** | CT610 `mssql6`               | `192.168.0.110` | `100.117.17.113`  |
| **Legado / DR**   | VM620 `WinServer2016-VirtIO` | `192.168.0.200` | `100.102.182.100` |

**Credenciais CT610:** `ald-sys8/src/.env` (`DB_PASSWORD_SYS` / `DB_PASSWORD_ALD`).  
**Credenciais VM620:** SA distinta — definir em `config/mssql-sync/mssql-sync.env` (não commitar).

## RPO / RTO (alvo)

| Métrica | Alvo piloto SILD           | Produção                      |
| ------- | -------------------------- | ----------------------------- |
| **RPO** | ≤ 5 min (lag SymmetricDS)  | ≤ 1 min após rollout          |
| **RTO** | ≤ 30 min (failover manual) | ≤ 15 min com runbook ensaiado |

## Monitorização

```bash
# Do agldv03 ou qualquer host com SSH a man6
./scripts/mssql-sync/monitor-sync.sh
```

**Checks manuais:**

1. `qm status 620` e `pct status 610` em man6
2. Portas `1433` em ambos os IPs LAN
3. SymmetricDS: `http://192.168.0.110:31415/` (após deploy)
4. PBS Tier-1: jobs VMIDs `610,620` em `scripts/proxmox/pbs-setup-renumbered-hosts.sh`

## Cenário 1 — CT610 indisponível (failover para VM620)

### Sintomas

- Apps ald-sys8 não ligam a `100.117.17.113:1433`
- `pct status 610` stopped ou mssql-server down

### Procedimento

1. Confirmar VM620 acessível: `nc -zv 192.168.0.200 1433` desde man6
2. **Parar SymmetricDS** no CT610 (se ainda parcialmente up) para evitar conflitos
3. Actualizar **ald-sys8** `.env` temporariamente:
   - `DB_HOST_SYS` / `DB_HOST_ALD` → `100.102.182.100` ou `192.168.0.200`
4. Validar login SA VM620 e bases `ALD-SYS8`, `DB_IDE_Associacao`, `SILD`
5. Reiniciar workers Laravel / PHP-FPM nos hosts de app
6. Registar incidente; planear restore CT610

### Failback (CT610 restaurado)

1. Sincronizar delta VM620 → CT610 (SymmetricDS ou restore PBS + catch-up)
2. Verificar contagens de linhas em tabelas críticas
3. Reverter `.env` ald-sys8 para `100.117.17.113`
4. Reiniciar SymmetricDS bidireccional

## Cenário 2 — VM620 indisponível

- **Impacto:** DR legado perdido; apps continuam no CT610
- **Acção:** `qm start 620` ou restore PBS; não alterar `.env` das apps
- Re-sync SymmetricDS após VM620 online

## Cenário 3 — Divergência de dados (conflito)

1. Identificar tabela e `sym_data` / logs SymmetricDS
2. Resolver manualmente na base **autoritativa** (CT610 em operação normal)
3. Forçar reload da tabela no nó subordinado via consola SymmetricDS
4. Documentar em ticket bd

## Cenário 4 — Guest agent VM620 down

- Sync e sqlcmd remoto via rede LAN continuam se SA conhecido
- Reparo guest agent: ver notas em inventário; **não parar VM** sem janela
- Monitor legado `/root/monitor_sqlserver_vm200.sh` no man6 — **VMID=620** (renumber 200→620; subject e-mail «VM620 SQL Server»)

## Scripts úteis

| Script                                        | Uso                      |
| --------------------------------------------- | ------------------------ |
| `scripts/mssql-sync/inventory.sh`             | Inventário CT610 + VM620 |
| `scripts/mssql-sync/enable-sqlagent-ct610.sh` | Activar Agent no CT610   |
| `scripts/mssql-sync/apply-repl-logins.sh`     | Login `repl_mssql`       |
| `scripts/mssql-sync/deploy-symmetricds.sh`    | Deploy piloto            |
| `scripts/mssql-sync/monitor-sync.sh`          | Health check             |

## Pré-requisitos pendentes (checklist)

- [ ] Password SA VM620 documentada em `mssql-sync.env` (local)
- [ ] `MSSQL_REPL_PASSWORD` definido e logins aplicados
- [ ] SQL Agent activo no CT610
- [ ] Piloto SILD (só tabelas com PK) em observação 24–48 h
- [ ] Monitor man6 actualizado VMID 620
