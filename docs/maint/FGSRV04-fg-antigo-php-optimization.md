# FGSRV04 — PHP (`fg_antigo`) e migração FGSRV07

**Contexto:** timeouts em chamadas PHP5 (e outras) para `api.falg.com.br` (FGSRV05), memória limitada no host actual e plano de **CT no Proxmox (FGSRV07)** para isolar a app em `/var/www/fg_antigo`.

## 1. Onde o PHP lê configuração (Debian/Ubuntu)

| Camada | Caminho típico |
|--------|----------------|
| FPM (produção web) | `/etc/php/<versão>/fpm/php.ini` + `.../fpm/conf.d/*.ini` |
| CLI (cron, artisan) | `/etc/php/<versão>/cli/php.ini` + `.../cli/conf.d/*.ini` |
| Pools FPM | `/etc/php/<versão>/fpm/pool.d/*.conf` (`php_admin_value[]` **sobrepõe** `php.ini`) |

**Regra:** preferir **um ficheiro em `conf.d/`** (ex.: `99-agl-fg-antigo.ini`) em vez de editar o `php.ini` principal — mais fácil de reverter e versionar.

### OPcache PHP 5.6 (FPM)

Ficheiro exemplo no repositório: `scripts/maint/templates/php56-fpm-conf.d-20-agl-opcache.ini` → instalar como `/etc/php/5.6/fpm/conf.d/20-agl-opcache.ini` (memória **96 MB**, `max_accelerated_files` **10000**, `revalidate_freq` **60 s**, `validate_timestamps` **1**). Depois: `php-fpm5.6 -t && systemctl reload php5.6-fpm`.

## 2. Directivas úteis (memória baixa + chamadas HTTP/Socket longas)

Ajustar à RAM real do CT/host; valores abaixo são **ponto de partida** para produção com API remota.

| Directiva | Notas |
|-----------|--------|
| `memory_limit` | Para fluxo SCL pesado no repo: **1024M** com `pm.max_children` baixo (ver template pool). Em CT muito pequeno, usar **256M–512M** ou subir RAM antes. |
| `max_execution_time` / `max_input_time` | Alinhar com Nginx `fastcgi_read_timeout` e FPM `request_terminate_timeout` (ex.: **300**). |
| `default_socket_timeout` | Segundos para streams `http://`, `fsockopen`, etc. **120–300** se a API for lenta. |
| `realpath_cache_size` / `realpath_cache_ttl` | Menos `stat()` em disco; típico **4096K** + **600** s. |
| `output_buffering` | **4096** ou `On`; reduz flush frequente. |
| **OPcache** (PHP ≥ 5.5 com extensão activa) | `opcache.memory_consumption` **64–128** MB; `opcache.max_accelerated_files` **10000**; em CT com pouca RAM, não subir acima do necessário. |

**PHP 5.6 (legado):** se ainda usares extensão `mysql` antiga, `mysql.connect_timeout` ajuda na ligação ao servidor MySQL; para `mysqli`, ver também `mysqli.reconnect` e timeouts no código.

## 3. Scripts no repositório

Ver também **`docs/maint/FG-ANTIGO-GIT-E-FLUXO.md`** (repo **AGLz**/clone `fg_antigo`, commit/push `agl-hostman`, templates nginx/FPM pesados).

No **FGSRV04**, os timeouts curtos (`send_timeout 10`, `client_* 12`) podem estar em **`/etc/nginx/conf.d/performance.conf`** (`include conf.d/*.conf`), não só em `nginx.conf`. O script `fgsrv04-falg-optimize-timeouts.sh` também patcheia esse ficheiro. **Importante:** não criar cópias `*.bak` dentro de **`/etc/nginx/sites-enabled/`** — o Nginx inclui todos os ficheiros desse diretório e pode dar `duplicate listen`.

**`location ~ \.php$` vs `location /include` (2026-04-28):** o snippet `include /etc/nginx/snippets/falg-fastcgi-timeouts.conf` **tem** de estar dentro do bloco **`location ~ \.php$`** em `fg_old` / `fg_old2` / `fg_old3`, logo a seguir a `include fastcgi_params;`. Só o ter em `/include` não afecta `/scl/extrato_pago.php` — o Nginx usa o default **~60 s** para `fastcgi_read_timeout` e o log mostra `upstream timed out` nos extratos pesados. O script acima passou a inserir esse `include` no bloco `.php` automaticamente (idempotente).

- `scripts/maint/fgsrv04-php-agl-report.sh` — **só leitura**: lista versões PHP, caminhos `php.ini` e valores chave (correr no FGSRV04).
- `scripts/maint/fgsrv04-php-agl-production-ini.sh` — cria `conf.d/99-agl-fg-antigo.ini` por versão (backup + idempotente); **requer root/sudo**. Defeito **`FG_ANTIGO_PHP_MEMORY=1024M`**; reduzir em hosts limitados. Alinhar **`pm.max_children`** (ex.: **6** no snippet) com ~1 GiB por worker.
- `scripts/maint/templates/php-fpm-conf.d-heavy-scl-example.ini`, `nginx-snippet-fg-antigo-scl-timeouts.conf`, `php-fpm-www-pool-low-workers-snippet.conf.example` — modelos para copiar no servidor após revisão manual.
- `scripts/maint/fg-antigo-remote-audit-commands.sh` — comandos `grep`/`find` sugeridos para `/var/www/fg_antigo` (executar no servidor).

## 4. Auditoria em profundidade em `/var/www/fg_antigo` (no servidor)

Objetivo: encontrar gargalos que **config PHP não resolve** (N+1 de HTTP, locks de sessão, queries lentas).

1. **Chamadas HTTP de saída:** `curl_*`, `file_get_contents('http`, `SoapClient`, `stream_context_create` — procurar timeouts baixos ou ausentes.
2. **Sessões:** muitos pedidos em paralelo com o mesmo `session_id` podem serializar e parecer “timeout”; avaliar `session_write_close()` após `$_SESSION` desnecessário no início do request.
3. **Incluir ficheiros:** `include` em loop remoto, `file_get_contents` sem cache.
4. **Base de dados:** queries sem índice, `SELECT *`, ligações remotas lentas (testar latência FGSRV04 → MySQL/API).
5. **Logs:** rotação de `error_log` / logs da app (auditoria anterior referiu **dezenas de GB** de logs Laravel noutros vhosts — garantir logrotate e nível de log).

## 5. Container no FGSRV07 (Proxmox)

- **Dimensão inicial sugerida:** 2–4 vCPU + **até 8 GB RAM** para PHP 5.6 + Nginx + SO (**consumo real da app acima do ideal**); validar com `ps`, `rss` dos workers FPM sob carga.
- **Deploy:** em hosts com **pouco espaço em disco**, **não** usar `git clone` no CT destino — copiar árvore com **`rsync`** desde FGSRV04 (ver `docs/maint/FGSRV07-fg-antigo-ct-provisioning.md`).
- **Swap:** 512M–1G no CT só para picos (não substituir RAM).
- **Filesystem:** mesmo layout `/var/www/fg_antigo` ou deploy via imagem; copiar os `conf.d/99-agl-fg-antigo.ini` para a mesma política de tuning.
- **Rede / DB:** latência FGSRV07 → `https://api.falg.com.br` aceitável; MySQL **primário** na FGSRV07 é **CT235** (**promovido** de replica — ver `docs/INFRA.md`). Testar `curl` e cliente MySQL a partir do CT.

## 6. Checklist rápido pós-mudança

- `php-fpm<x.y> -tt` / `systemctl reload php<x.y>-fpm`
- Página típica + fluxo que chama a API (browser ou `curl`)
- `/var/log/nginx/error.log` — ausência de `upstream timed out`

---

**Última atualização:** 2026-04-28 (CT FGSRV07: até 8 GiB RAM; DB CT235 primário; deploy rsync)
