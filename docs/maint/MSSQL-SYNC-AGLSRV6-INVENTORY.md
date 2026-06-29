# Inventário MSSQL — sync VM620 ↔ CT610 (AGLSRV6)

**Data inventário geral:** 2026-06-06 · **Fase 0 `DB_IDE_Associacao`:** 2026-06-27  
**Host Proxmox:** man6 (`100.98.108.66`)  
**Credenciais:** CT610 → `ald-sys8/src/.env` (`DB_PASSWORD_ALD`); VM620 → `config/mssql-sync/mssql-sync.env` (gitignored, ver `.example`)

## Nós

| Nó                               | ID       | IP LAN          | IP Tailscale      | SO / SQL                                              |
| -------------------------------- | -------- | --------------- | ----------------- | ----------------------------------------------------- |
| **CT610** `mssql6`               | LXC 610  | `192.168.0.110` | `100.117.17.113`  | SQL Server **2022 Developer** (16.0.4135.4) Linux     |
| **VM620** `WinServer2016-VirtIO` | QEMU 620 | `192.168.0.200` | `100.102.182.100` | SQL Server **2016 Express SP2** (13.0.5026.0) Windows |

## CT610 — instância (validado via sqlcmd)

- **Edição:** Developer Edition (`EngineEdition` = 3)
- **SQL Agent:** **activado** (2026-06-06 via `scripts/mssql-sync/enable-sqlagent-ct610.sh`; `sqlagent.enabled = true`)
- **Porta:** 1433 (LAN + Tailscale)

### Bases de dados

| Base              | Recovery | Tabelas | Com PK | ~Linhas |
| ----------------- | -------- | ------- | ------ | ------- |
| ALD-SYS8          | FULL     | 200     | 199    | 174     |
| CEP_Brasil        | SIMPLE   | 4       | 3      | 606 692 |
| DB_IDE_Associacao | SIMPLE   | 83      | 57     | 431 276 |
| SILD              | SIMPLE   | 21      | 13     | 517 130 |

### SILD — tabelas sem chave primária (bloqueiam sync directo)

`TblCategoriaDeProdutos`, `TblDiaInverno`, `TblDiaNatal`, `TblFaixaEtária`, `TblIdadeGestante`, `TblSenhas`, `TblTiposDeEntidade`, `TblUnidadePeso`

**Acção:** adicionar PK surrogate (`sync_id`) ou excluir do piloto até correcção de schema.

## VM620 — instância (validado 2026-06-27)

- **Hostname SQL:** `SSPADLD01`
- **Estado VM:** running; porta **1433** OK
- **QEMU guest agent:** indisponível (sync via JDBC/LAN OK)
- **Login `sa`:** password distinta do CT610 (ver `mssql-sync.env` local; origem documentada em Associacoes SQLTools)
- **Edição:** Express SP2; SQL Server Agent não suportado

### Bases VM620 (user DBs)

`CEP_Brasil`, `DB_IDE_Associacao`, `DB_IDE_Associacao_SS1/2/3`, `SILD` — **sem** `ALD-SYS8` (só no CT610).

---

## DB_IDE_Associacao — Fase 0 (piloto SymmetricDS)

**Scripts:** `scripts/mssql-sync/inventory-db-ide.sh`, `compare-rowcounts-db-ide.sh`  
**Artefactos:** [`reconcile/DB_IDE_Associacao-reconcile-20260627.csv`](reconcile/DB_IDE_Associacao-reconcile-20260627.csv)

### Resumo comparativo (2026-06-27)

| Métrica                | CT610       | VM620               |
| ---------------------- | ----------- | ------------------- |
| Tabelas                | 83          | 83                  |
| Com PK                 | 57          | 57                  |
| Sem PK                 | 26          | 26 (mesmo conjunto) |
| ~Linhas totais         | **431 276** | **465 983**         |
| Schema (nomes tabelas) | Idêntico    | Idêntico            |

**Reconciliação:** 83 tabelas em ambos; **69 match**, **14 diverged** (VM620 à frente — .NET produção activa).

### Tabelas divergentes (VM620 > CT610)

| Tabela                          | CT610   | VM620   | Δ       |
| ------------------------------- | ------- | ------- | ------- |
| `ATE_Tratamento`                | 184 420 | 201 871 | +17 451 |
| `ASC_MapaContribuicaoAssociado` | 60 671  | 63 932  | +3 261  |
| `CRM_Pessoa`                    | 57 069  | 60 494  | +3 425  |
| `ASC_ContribuicaoAssociado`     | 31 687  | 34 631  | +2 944  |
| `ATE_AgendaPessoaTratamento`    | 46 290  | 51 529  | +5 239  |
| `FIN_Doacao`                    | 4 876   | 6 152   | +1 276  |
| `BIB_LivroDoado`                | 1 308   | 1 737   | +429    |
| `BIB_TomboTiluloEmprestimo`     | 6 704   | 7 053   | +349    |
| `BIB_Tombo`                     | 5 091   | 5 281   | +190    |
| `BIB_TituloAutor`               | 3 039   | 3 102   | +63     |
| `BIB_Titulo`                    | 3 044   | 3 116   | +72     |
| `VOL_LocalGrupoPessoa`          | 107     | 110     | +3      |
| `INI`                           | 5       | 8       | +3      |
| `SEG_Operador`                  | 20      | 22      | +2      |

**Interpretação:** VM620 é **fonte activa** (.NET legado); CT610 é **cópia desactualizada** (~34k linhas atrás no total). Carga inicial SymmetricDS deve **VM620 → CT610** nas tabelas divergentes; depois activar bidireccional.

### Tabelas sem PK (26) — excluir ou PK surrogate antes do sync

`ASS_AtendimentoDetalhe`, `ASS_CestaProduto`, `ASS_FamiliaObservacao`, `ASS_SenhaAtendimento`, `ATE_AgendaPessoaTratamento`, `BIB_LivroDoado`, `BIB_TituloAutor`, `BKPATE_AgendaPessoaTratamento`, `DIV_FotoGrupo`, `DIV_FotoPersonalidade`, `EDU_PessoaCurso`, `FIN_CentroCustoRateio`, `FIN_ContaSaldo`, `FIN_Doacao`, `FIN_FluxoCaixaRateioCentroCusto`, `IDE_Configuracao`, `INI`, `PlanoContas`, `tbl_Leitores`, `tmpContribuicao`, `VOL_Disponibilidade`, `VOL_LocalGrupoPessoaData`, `VOL_PessoaFaculdadeMediunica`, `VOL_PessoaFuncaoDoutrinaria`, `VOL_PessoaGrupo`, `VOL_PessoaGrupoNaoEspiritual`

**Sync v1:** 57 tabelas com PK; 26 restantes → Fase 1 schema ou Sync Key Names.

---

## VM620 — notas legado (secção anterior)

## Rede (man6)

| Verificação            | Resultado            |
| ---------------------- | -------------------- |
| `192.168.0.110:1433`   | OK                   |
| `192.168.0.200:1433`   | OK                   |
| `100.117.17.113:1433`  | OK (Tailscale CT610) |
| `100.102.182.100:1433` | OK (Tailscale VM620) |

**Sync recomendado:** LAN (`192.168.0.110` ↔ `192.168.0.200`) — menor latência no mesmo host Proxmox.

## Overlap ald-sys8 → CT610

Aplicação **ald-sys8** (`/mnt/overpower/apps/dev/ald/ald-sys8/src/.env`):

- `ALD-SYS8` → `DB_DATABASE_SYS` em `100.117.17.113`
- `DB_IDE_Associacao` → `DB_DATABASE_ALD` em `100.117.17.113`

CT610 recebe tráfego **ald-sys8** (`sqlsrv_ald`). VM620 recebe **.NET legado** (produção activa). Ambos têm `DB_IDE_Associacao` — **dual writer** até SymmetricDS estar activo.

## Referências

- Plano: `.cursor/plans/mssql_sync_aglsrv6_e96d6508.plan.md`
- Scripts: `scripts/mssql-sync/`
- Arquitectura: [`MSSQL-SYNC-AGLSRV6-ARCHITECTURE.md`](MSSQL-SYNC-AGLSRV6-ARCHITECTURE.md)
