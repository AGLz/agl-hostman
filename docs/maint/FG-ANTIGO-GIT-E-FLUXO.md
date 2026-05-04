# fg_antigo — Git (org), fluxo SCL e limites (memória / execução / workers)

**Objetivo:** analisar o código localmente na org **AGLz**, garantir pushes do **agl-hostman**, e aumentar timeouts/limites alinhados (Nginx + PHP-FPM) para o fluxo: **login → movimentos futuros → opções contrato (ex. 1029) → extrato (ex. 37017)**.

## 1. Onde está o código hoje neste mono-repo (`agl-hostman`)

**Não** existe subtree/submodule com o código completo de `/var/www/fg_antigo` — apenas artefactos de manutenção, por exemplo:

| Caminho no repo | Conteúdo |
|-----------------|----------|
| `scripts/maint/fg_antigo/cons_pagtos_inq.php.snapshot` | Cópia de trabalho (consulta pagamentos / ligações a `opcoes_contrato.php`) |
| `scripts/maint/fg_antigo/cons_pagtos_inq_precarga.php` | Pré-carga anti–N+1 |
| `scripts/maint/fg_antigo/discover-scl-flow-php.sh` | Descobrir `.php` do fluxo no **servidor** |
| `tests/e2e/falg/` | Playwright (URL remota / credenciais via env) |

**Nomes de páginas citados pelo snapshot atual:** `cons_pagtos_inq.php`, `cons_pagtos_inq_precarga.php`, `opcoes_contrato.php`. Login / movimentos futuros / extrato **confirmar no servidor** (`discover-scl-flow-php.sh`) ou DevTools → Network ao clicar.

## 2. GitHub — `agl-hostman` neste checkout

Este clone apontou (ver `git remote -v`):

`origin git@github.com:aguileraz/agl-hostman.git`

- **Org `AGLz`:** conferir na UI do GitHub se já existe **`AGLz/agl-hostman`** ou se o projeto é só **`aguileraz/agl-hostman`**. Migrar para a org costuma ser *Transfer repository* ou *Fork* conforme política da equipa.
- **Repositório `fg_antigo` dedicado:** hoje não está referenciado no remoto como submodule. Fluxo típico:
  1. Criar repositório vazio **`github.com/AGLz/fg_antigo`** (ou nome acordado).
  2. No servidor ou cópia NFS (`/var/www/fg_antigo` ou montagem SMB/NFS já documentada em `docs/FILESERVER5-*`): `git init`, `.gitignore` (logs, uploads, caches), primeiro commit apenas de `public_html`, `includes`, conforme política — **sem credenciais** em claro nos ficheiros.
  3. `git remote add origin git@github.com:AGLz/fg_antigo.git` → `push` branch principal.

Até esse repo existir, a análise local pode usar **cópia rsync/rsnapshot** ou **mount NFS** para uma pasta dentro do workstation; o **agl-hostman** continua a ser o lugar para scripts e snapshots parciais.

### 2.2 Repositório **`AGLz/fg-legacy`** — código no CT243 / cópia com histórico local a preservar

**Objectivo:** remoto **`git@github.com:AGLz/fg-legacy.git`** (ou HTTPS equivalente), branch **`dev`**, mantendo **o que já está no servidor** como fonte de verdade e **ignorando** o conteúdo inicial do remoto se for só README/licença ou árvore antiga.

**No CT (ou máquina com cópia completa de `/var/www/fg_antigo`):**

```bash
cd /var/www/fg_antigo   # ou só public_html se decidirem repo parcial — ser consistente
git init
git checkout -b dev
# .gitignore: logs, uploads pesados, caches, credenciais (conectar.php, etc.)
${EDITOR:-vim} .gitignore
git add -A
git status   # rever; nunca commitar segredos
git commit -m "chore(fg-legacy): import inicial a partir do CT (estado produção)"
git remote add origin git@github.com:AGLz/fg-legacy.git
git fetch origin
```

**Se o remoto estiver vazio** (sem commits): `git push -u origin dev`.

**Se o remoto já tiver commits (ex. README) e quiserem descartar a árvore remota a favor do vosso trabalho local:**

```bash
git push -u origin dev --force
```

**Se quiserem *manter* histórico remoto mas resolver tudo a favor do código actual do CT** (merge único, conflitos = lado CT):

```bash
git branch -m dev                    # já em dev
git fetch origin
git merge -X ours origin/main --allow-unrelated-histories   # ou origin/master
# rever resultado; git push -u origin dev
```

(`-X ours` = em conflitos, ficam as alterações da branch **`dev`** actual.)

**Pós-push:** política de PRs `main` ← `dev` na org **AGLz**; o **agl-hostman** continua só com scripts/docs — não duplicar o mono-repo legado inteiro aqui salvo decisão explícita (submodule ou subtree).

### 2.1 Migração FGSRV07 / disco limitado — **sem Git no servidor**

Em produção (ex.: FGSRV04 com **`/` quase cheio**), **não** contar com `.git` nem `git pull` no host:

- Copiar **`/var/www/fg_antigo`** para o CT novo **apenas com `rsync`** (ou `tar` + pipe SSH), incluindo `vendor*`/`public_html` conforme necessário.
- Ficheiros sensíveis (**`conectar.php`**, **`configs.php`**, `.env`, etc.**) continuam a ir **à parte** do fluxo de código público — mesmo patrão já usado em commits seguros.
- Guia operacional: **`docs/maint/FGSRV07-fg-antigo-ct-provisioning.md`** e checkpoint de runtime PHP 5.6 em **`docs/maint/FGSRV04-php-runtime-fg-antigo-checkpoint.md`**.

## 3. Commits/push no `agl-hostman` antes de clonar/analisar fg_antigo

Incluir (revisão `git status` só o que faz sentido ao projecto):

- `scripts/maint/fg_antigo/` (snapshot, precarga, `discover-scl-flow-php.sh`)
- `playwright.falg.config.js`, `tests/e2e/falg/`, `tests/e2e/helpers/falg-login.js`
- `docs/maint/FG-ANTIGO-GIT-E-FLUXO.md`, `docs/maint/FGSRV04-fg-antigo-php-optimization.md` (se alterados)
- `package.json` / `package-lock.json` apenas se aceitarem lockfile atual (evitar commits acidentais de `node_modules/` — deve estar ignorado pelo `.gitignore`)

Comandos sugeridos:

```bash
git status
git diff
git add scripts/maint/fg_antigo docs/maint playwright.falg.config.js tests/e2e/falg tests/e2e/helpers/falg-login.js package.json package-lock.json .gitignore
git commit -m "feat(maint): fg_antigo SCL precarga/descovery, Playwright FALG, docs fluxo e tuning"
git pull --rebase origin develop
git push origin develop
```

## 4. Limites de memória e tempo (e workers FPM mais baixo)

Filosofia:

- **`memory_limit` / `max_execution_time`** no PHP FPM devem ficar **abaixo ou iguais** a `fastcgi_read_timeout` / `request_terminate_timeout` do Nginx e FPM, senão o browser ou o gateway corta antes do PHP declarar erro.
- Com `memory_limit` **1 GiB** nos pedidos pesados, **reduzir `pm.max_children`** (exemplo no template: **6**) para não estourar RAM: ~1 GiB × `pm.max_children` ≤ 70–80% da RAM usável pelo pool FPM.

Ficheiros de modelo neste repo:

| Ficheiro | Uso |
|----------|-----|
| `scripts/maint/templates/php-fpm-conf.d-heavy-scl-example.ini` | Copiar/blendar em `conf.d/` do PHP-FPM (**1 G, 300s**) só no host/pool onde corre o fg_antigo |
| `scripts/maint/templates/nginx-snippet-fg-antigo-scl-timeouts.conf` | Incluir no `server{}`/`location ~ \\.php$` que serve `falg.com.br` os `*_timeout` até 300s |
| `scripts/maint/templates/php-fpm-www-pool-low-workers-snippet.conf.example` | Ajustar `pm.max_children` / `pm.max_spare_servers` no **pool correto** (nome real varia por distro) |

O script **`scripts/maint/fgsrv04-php-agl-production-ini.sh`** usa por defeito **`FG_ANTIGO_PHP_MEMORY=1024M`** (sobrescrever com `512M`/`256M` em hosts pequenos); ver comentários no topo do script.

## 5. Incidente pós–24/04/2026 (enrosco geral “retorno de queries”)

Para além dos limites:

- **MySQL:** slow query log + `SHOW PROCESSLIST` no pico do extrato.
- **Dados/MySQL upstream:** migrações recentes ou réplica/partição.
- **Código:** continuar pré-carga/índices como em `cons_pagtos_inq_precarga.php` nos outros `.php` do fluxo (mapear com `discover-scl-flow-php.sh`).

---

**Última atualização:** 2026-04-28 (§2.2 `AGLz/fg-legacy` + branch `dev`; §2.1 — rsync sem Git no host)
