# FGSRV07 — CT para `fg_antigo` (www5.falg.com.br): provisionamento

**Objectivo:** novo CT no **FGSRV07** para hospedar o legado **`fg_antigo`** com **Nginx + PHP 5.6 FPM**, dados migrados **só por `rsync`** (sem Git no servidor por limitação de disco).

**Tunnel Cloudflare:** o ingress hostname (**ex.: `www5.falg.com.br`**) fica **à cargo da console Cloudflare** — não duplicar `cloudflared` dentro deste CT se o **CT170** já encaminha para o IP interno do serviço HTTP.

---

## Estado (FGSRV07 — 2026-04-28)

| Item | Valor |
|------|--------|
| **VMID** | **243** |
| **Hostname** | **`fg-legacy`** |
| **LAN** | **192.168.70.243/24** (`vmbr70`, gw `192.168.70.1`) |
| **RAM** | **8192 MiB** · **vCPU** **4** (alvo 2026-04; antes 2) · **disco** **60 GiB** (`bkp`, alargado 2026-04-29) |
| **SO** | Ubuntu 22.04 template |
| **Serviços** | `nginx`, `php5.6-fpm` (PPA ondrej/php), extensões alinhadas ao checkpoint FGSRV04 |
| **Webroot** | `/var/www/fg_antigo/public_html` · `server_name` **www5.falg.com.br** (HTTP :80) |
| **Tailscale** | Pacote **1.96.x**; join com `--ssh`, `--accept-dns=false`, tag **`tag:servers`** (sem `tag:fgsrv` — não permitida nas ACLs) — ver secção abaixo |

Tunnel Cloudflare: apontar o hostname para **`http://192.168.70.243:80`** a partir do CT170 (ingress interno).

### Tailscale (CT243)

Num **LXC unprivileged**, o daemon precisa de **`/dev/net/tun`**. Sem isto, `tailscaled` termina com `CreateTUN("tailscale0") failed` / `/dev/net/tun does not exist`.

No **FGSRV07**, em `/etc/pve/lxc/243.conf`, garantir:

```text
lxc.cgroup2.devices.allow: c 10:200 rwm
lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
```

Depois: **`pct reboot 243`** (ou stop/start). Validar no CT: `ls -la /dev/net/tun` e `systemctl is-active tailscaled`.

**Join à tailnet** (autenticação no browser; **`tag:servers`** exige *tag owner* nas ACLs — **`tag:fgsrv`** não está permitida nesta tailnet):

```bash
tailscale up \
  --ssh \
  --accept-dns=false \
  --hostname=fg-legacy \
  --advertise-tags=tag:servers
```

- **`--accept-dns=false`** — evita que o MagicDNS substitua o resolver do CT (MySQL, clientes e DNS internos).
- **`--ssh`** — [Tailscale SSH](https://tailscale.com/kb/1193/tailscale-ssh/) para sessões autenticadas e **`rsync`** sobre a tailnet.

Script no repo: `scripts/maint/fgsrv07/ct243-tailscale-up.sh`. Referência geral: `docs/fgsrv07-tailscale-installation.md`.

### vCPU (Proxmox) — 4 cores em **CT243** e **CT235**

No **host FGSRV07** (root):

```bash
# Opcional: copiar o script do agl-hostman para o host e executar
bash scripts/maint/fgsrv07/pct-bump-fg-stack-cores.sh
# ou manualmente:
pct set 243 -cores 4   # fg-legacy
pct set 235 -cores 4   # mysql7
```

Validar dentro dos CTs (`nproc`, `htop`). Ajustar `CORES=…` no script se necessário.

**IP Tailscale** (após login): `tailscale ip -4` dentro do CT — registar em `docs/INFRA.md` quando estiver estável.

---

## 1. Recursos sugeridos do CT

| Recurso | Valor |
|---------|--------|
| **RAM** | **8192 MB** (máx. acordado; app com consumo elevado) |
| **vCPU** | **4** (fg-legacy + mysql7 alinhados; ver script `scripts/maint/fgsrv07/pct-bump-fg-stack-cores.sh`) |
| **Disco** | ≥ 40–60 GiB (validar vs tamanho actual em FGSRV04 + margem) |
| **Rede** | **vmbr70** (ex.: `192.168.70.0/24`), NAT/Masquerade já descritos em `docs/INFRA.md` |

SO template: preferir base onde **`php5.6-fpm`** esteja disponível via mesmos mecanismos que FGSRV04 (sury/Ondřej); ver checkpoint **`FGSRV04-php-runtime-fg-antigo-checkpoint.md`**.

---

## 2. Pacotes / stack (checklist)

- **Base:** `nginx`, **PHP 5.6 FPM** + módulos conforme checkpoint (mysqli, gd, curl, mbstring, soap, zip, imap, intl, mysql legacy se inevitável, etc.).
- **Cliente DB:** `mysql-client` / MariaDB client para testes de conectividade.
- **Ferramentas:** `rsync`, `openssh-server`, `curl`, `ca-certificates`, `vim`/`nano`, `htop`, `logrotate`.
- **Composer / Node:** só se for indispensável **no CT**; por defeito copiar **vendor** / assets já gerados com **`rsync`**.
- **Mail:** definir relay SMTP ou postfix satélite se a app enviar e-mail.

---

## 3. MySQL primário (FGSRV07)

O **CT235** está documentado como **primário promovido** (antes “slave”) — ver **`docs/INFRA.md`**.

- Apontar **`conectar.php` / configs** para o host/porta correctos (LAN Tailscale conforme política).
- Validar credenciais e **firewall** entre CT da app e CT235.

---

## 4. Cópia com `rsync` (sem `.git`)

Origem típica: **FGSRV04** `root@100.111.79.2:/var/www/fg_antigo/`.

Exemplo (ajustar chaves, exclusões e destino):

```bash
# Na máquina com SSH até ambos (ou directamente se FGSRV04 alcança FGSRV07)
rsync -avz --progress \
  --exclude '.git/' \
  -e 'ssh -i ~/.ssh/CHAVE' \
  root@ORIGEM_IP:/var/www/fg_antigo/ \
  root@DESTINO_IP:/var/www/fg_antigo/
```

Exclusões úteis caso queiram reduzir tráfego: caches regeneráveis, cópias gigantes já migradas por outro meio (`BB01`, etc.) — **alinhar com equipa** antes.

---

## 5. Nginx / PHP-FPM

- Root alinhado a **`…/public_html`** (como em `fg_old` em FGSRV04).
- **`fastcgi_pass`** para socket **`php5.6-fpm.sock`** (ou TCP interno equivalente).
- Incluir snippets de **timeouts** longos para fluxos SCL (ver templates em `scripts/maint/templates/` e `FGSRV04-fg-antigo-php-optimization.md`).
- **`memory_limit`** / **`pm.max_children`** coerentes com **8 GiB** RAM do CT.

---

## 6. DNS / Cloudflare

### Domínio **falg.com.br** noutra conta que o tunnel (AGLz / aglz.io)

A consola Zero Trust do tunnel **fgsrv7** só lista zonas da **mesma** conta Cloudflare (ex.: **aglz.io**, **aguileraz.net**). Se **falg.com.br** estiver noutra conta, **não** vais conseguir completar o fluxo “só na consola do tunnel” como se fosse a mesma zona.

A Cloudflare documenta que o subdomínio **`.cfargotunnel.com` só faz proxy de tráfego para registos DNS na mesma conta Cloudflare que o tunnel** — ou seja, um CNAME **proxied** na zona `falg.com.br` **noutra conta** **não** encaminha pelo tunnel dessa conta AGLz. Referência: [DNS records for Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/routing-to-tunnel/dns/).

**Caminhos possíveis (escolher com negócio / dono das contas):**

| Abordagem | Ideia |
|-----------|--------|
| **A. Zona na mesma conta que o tunnel** | Passar a gerir **falg.com.br** na conta onde está o **fgsrv7** (onboarding da zona nessa conta, ou *account transfer* se aplicável). Depois: *published route* `www5.falg.com.br` + CNAME na zona, tudo coerente com a doc oficial. |
| **B. Novo tunnel na conta do falg.com.br** | Na conta onde está **falg.com.br**: Zero Trust → novo tunnel (ou segundo `cloudflared` com credenciais dessa conta no CT170), rota `www5.falg.com.br` → `http://192.168.70.243`, e CNAME na **mesma** conta. O **fgsrv7** actual mantém-se para **aglz.io** / **man7**, etc. |
| **C. URL canónica aglz** | Manter produção acessível por **www5.aglz.io** (já na captura) até haver decisão de unificar contas ou novo tunnel; **falg.com.br** sem edge Cloudflare nesse desenho ou com outro origin. |

**Não** contes com CNAME laranja **www5.falg.com.br** → `*.cfargotunnel.com` do **fgsrv7** enquanto a zona **falg.com.br** estiver noutra conta — não é suportado para proxy pelo mesmo mecanismo.

### Caminho correcto (recomendado) — **zona e tunnel na mesma conta**

O **`cloudflared` corre no CT170** (tunnel `513cec7b-754d-4dd8-a69d-d15942180fe4` — ver `docs/INFRA.md`). Quando **falg.com.br** e o tunnel forem da **mesma** conta Cloudflare, para **`www5.falg.com.br`** servir o mesmo backend que **`192.168.70.243:80`**:

1. **Cloudflare Zero Trust → Networks → Connectors → Tunnels → [fgsrv7] → *Published application routes* → «+ Add a published application route»** (na UI pode aparecer como *Public hostnames* noutras versões):
   - **Hostname:** `www5.falg.com.br` · **Path:** `*`
   - **Service:** `http://192.168.70.243` (porta **80** implícita — o mesmo origin que **`www5.aglz.io`** já configurado no mesmo tunnel, conforme consola).
   - Guardar (certificado gerido pela Cloudflare para esse hostname).

   **Nota:** Enquanto **não** existir esta linha para `www5.falg.com.br`, o CNAME na zona DNS resolve ao tunnel mas o ingress não sabe para onde encaminhar esse hostname.

2. **Zona DNS `falg.com.br`** (na conta onde está esse domínio):
   - Criar **`CNAME`** `www5` → **`<UUID-do-tunnel>.cfargotunnel.com`** (hostname indicado pelo assistente ao configurar o public hostname — **não** inventar à mão).
   - Proxy **ligado** (nuvem laranja), salvo indicação em contrário para tunnels.

Assim o pedido HTTPS vai sempre pelo tunnel configurado para o host **`Host: www5.falg.com.br`** até ao origin CT243.

### Via script (API v4 + `curl`, mesmo padrão que `mysql-ha`)

O script **`scripts/maint/fgsrv07/cloudflare-dns-cname-tunnel.sh`** cria ou actualiza o **CNAME** `www5` → valor de **`CF_TUNNEL_CNAME_TARGET`** (formato `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx.cfargotunnel.com`) com **`Authorization: Bearer`** (ou `X-Auth-Email` / `X-Auth-Key` legado). Variáveis: cabeçalho do script e **`scripts/maint/fgsrv07/cloudflare-dns-www5-fgsrv7.env.example`**.

```bash
# Secagem (só mostra JSON):
export CF_DRY_RUN=1
source ./caminho/para/seu.env   # CF_ZONE_ID, etc.; token: `CF_API_TOKEN` ou `CLOUDFLARE_API_TOKEN` (ex. ~/.zshrc)
bash scripts/maint/fgsrv07/cloudflare-dns-cname-tunnel.sh

# Aplicar de facto:
unset CF_DRY_RUN
bash scripts/maint/fgsrv07/cloudflare-dns-cname-tunnel.sh
```

O **Public hostname** em Zero Trust (passo 1) continua obrigatório; a API só altera **DNS** na zona.

### Checklist — continuar configuração Cloudflare

1. **API Token** (My Account → API Tokens): para o script e para `GET /zones/…`, o token precisa de permissões na zona **`falg.com.br`** — no mínimo **Zone → DNS → Edit**; recomenda-se também **Zone → Zone → Read** (para listar/validar zona). Se usares token só a DNS sem leitura de zona, define **`CF_ZONE_ID`** manualmente (já documentado: `01ce76a70c797ca510bb56bf61f3a75e`). No **agldv03** evita dois `export CLOUDFLARE_API_TOKEN` no `.zshrc` (o último ganha); alinha com o token que tiver estes scopes.
2. **Public hostname (Zero Trust)** — passo 1 acima: confirmar que existe **`www5.falg.com.br`** → **`http://192.168.70.243:80`** no tunnel **fgsrv7** (`513cec7b-754d-4dd8-a69d-d15942180fe4`). Sem isto, o CNAME resolve mas o tunnel não encaminha.
3. **DNS na zona** — passo 2 ou script: CNAME **`www5`** → **`513cec7b-754d-4dd8-a69d-d15942180fe4.cfargotunnel.com`**, **proxied** ligado.
4. **Aplicar por API** (a partir da raiz do repo, com variáveis carregadas):

```bash
cp scripts/maint/fgsrv07/cloudflare-dns-www5-fgsrv7.env.example /tmp/cloudflare-dns-www5.env
# editar /tmp/cloudflare-dns-www5.env se precisares de CF_API_TOKEN explícito
set -a; source /tmp/cloudflare-dns-www5.env; source ~/.zshrc 2>/dev/null; set +a
export CF_DRY_RUN=1 && bash scripts/maint/fgsrv07/cloudflare-dns-cname-tunnel.sh
unset CF_DRY_RUN && bash scripts/maint/fgsrv07/cloudflare-dns-cname-tunnel.sh
```

5. **Validação rápida:** `dig +short www5.falg.com.br` (deve mostrar IPs Cloudflare se proxied) e `curl -sI https://www5.falg.com.br/` (200 ou redireccionamento da app, **não** 403 com `1014`).

### Execução no **agldv03** (quando o clone NFS não tem os scripts)

1. A partir da tua máquina com o repo actualizado:
   `rsync -avz scripts/maint/fgsrv07/cloudflare-dns-cname-tunnel.sh scripts/maint/fgsrv07/cloudflare-dns-www5-fgsrv7.env.example AGLDV03:/root/cloudflare-www5-dns/`
2. No agldv03: garantir **um** `CLOUDFLARE_API_TOKEN` válido (Zone DNS Edit + recomendado Zone Read). Se o `/root/.zshrc` tiver **dois** `export CLOUDFLARE_API_TOKEN`, o **último** prevalece — se for o token curto/errado, a API responde `Authentication failed (status: 400)` ao listar DNS.
3. Correr (exemplo):
   `cd /root/cloudflare-www5-dns && set -a && . ./cloudflare-dns-www5-fgsrv7.env.example && . /root/.zshrc && set +a && bash ./cloudflare-dns-cname-tunnel.sh`
   (opcional: `export CF_DRY_RUN=1` antes para secagem.)

### Erro típico: HTTP 403 e texto `error code: 1014`

Se criares **`CNAME`** em **`falg.com.br`** apontando para **`www5.aglz.io`** (hostname já atrás da mesma rede Cloudflare noutra zona/conta), o navegador mostra **403** / **`1014`** — [**Error 1014: CNAME Cross-User Banned**](https://developers.cloudflare.com/support/troubleshooting/http-status-codes/cloudflare-1xxx-errors/error-1014). Cloudflare **bloqueia** CNAME entre dois nomes proxied quando não há autorização (ex.: Cloudflare for SaaS / custom hostname no alvo).

**Não uses:** `www5.falg.com.br` → CNAME → **`www5.aglz.io`**.

**Usa:** public hostname **`www5.falg.com.br`** no **mesmo tunnel** + CNAME para **`*.cfargotunnel.com`** conforme passo 1–2.

Se **`falg.com.br`** e **`aglz.io`** estiverem na **mesma conta** Cloudflare, Continuum também permite configurar o hostname no tunnel sem 1014, desde que o CNAME vá ao **`cfargotunnel.com`** certo — não ao nome **`*.aglz.io`**.

### Teste Playwright no repo

`tests/e2e/falg/www5-hostnames.spec.js` — valida **`www5.aglz.io`** (200) e **`www5.falg.com.br`** (sem 403/1014 quando DNS estiver correcto).

Login autenticado no tunnel **aglz** (mesma sessão PHP que produção via www5):

```bash
PLAYWRIGHT_BASE_URL=https://www5.aglz.io \
FALG_E2E_USER='…' \
FALG_E2E_PASSWORD='…' \
FALG_E2E_LOGIN_URL='https://www5.aglz.io/scl/…' \
npm run test:e2e:falg:www5-aglz
```

Atalho (script já fixa `PLAYWRIGHT_BASE_URL`): `npm run test:e2e:falg:www5-aglz` — exportar só as três variáveis `FALG_E2E_*`.

```bash
PW_SKIP_WEBSERVER=1 npm run test:e2e:falg -- tests/e2e/falg/www5-hostnames.spec.js
```

---

## 7. Troubleshooting: `POST …/autentica.php` → HTTP 500

O browser mostra `net::ERR_HTTP_RESPONSE_CODE_FAILURE` / **500** porque o **PHP ou o FastCGI** devolveram erro interno — não é problema do Chrome nem do tunnel se **GET** à página inicial responder **200**.

### Caso real (2026-04): `POST /autentica.php` → 500

**Causa encontrada nos logs:** `PHP Parse error: unexpected end of file in arcabouco/funcoes.php` — não era falha de MySQL.

**Motivo:** em **`short_open_tag => Off`** (php.ini), a função **`alerta()`** fechava com **`<?`** em vez de **`<?php`** após `</script>`; o `}` seguinte não era PHP válido → ficheiro sintacticamente truncado.

**Correcção:** substituir o bloco:

```text
</script>
<?
}
```

por:

```text
</script>
<?php
}
```

**Validação:** `php5.6 -l arcabouco/funcoes.php` sem erros; `mysqli` a partir do CT para **192.168.70.135** OK; `POST /autentica.php` deixa de devolver 500 (ex.: redireccionamento 302 com credenciais erradas).

### `include/topo_js.php` → 500 (e erros em `interno.php` / `innerHTML` / `prettify.js`)

**Causa:** com **`short_open_tag => Off`**, fechos **`<? }`** (sem `php`) não reabrem PHP → **parse error** (`unexpected end of file` em `topo_js.php`).

**Correcção:** substituir **`<? }`** por **`<?php }`** (e padrões na mesma linha com **`else if`**). Backups **`topo_js.php.bak-shorttag-*`**. O mesmo problema pode existir noutros includes (`menu.php`, `rodape.php`, etc.) — validar com `php5.6 -l ficheiro.php`.

**Nota:** `include/body_tag.php` — primeira linha **`<? require_once`** e final **`<? } ?>`** foram corrigidos para **`<?php require_once`** / **`<?php } ?>`** (backup `*.bak-shorttag-*`).

### Mixed Content (HTTPS): jQuery bloqueado — `$ is not a function`

Se a página é servida por **HTTPS** (ex.: tunnel Cloudflare) e os `<script>` apontam para **`http://ajax.googleapis.com/...`**, o browser **bloqueia** o script → jQuery não carrega → **`$ is not a function`**.

**Correcção:** usar **`https://ajax.googleapis.com/...`** em `app/views/header.phtml` (e vistas que referenciem o CDN em HTTP). Backups `*.bak-https-*` no CT243.

### Console Chrome: jQuery via `document.write` (parser-blocking / cross-site)

**Sintoma:** aviso *“A parser-blocking, cross site … script … jquery.min.js, is invoked via document.write”* (Chrome), linha do `(index):39`.

**Causa:** padrão antigo em `app/views/header.phtml` — `window.jQuery || document.write('<script src=…googleapis…>')` a duplicar o `<script src="https://…jquery/2.0.3/…">` seguinte.

**Correcção (2026-04-29):** remover a linha com `document.write`; manter **um único** `<script type="text/javascript" src="https://ajax.googleapis.com/ajax/libs/jquery/2.0.3/jquery.min.js"></script>`. Se o **disco do CT243 estiver cheio** (`/dev/loop*` a 100%), o `sed` in-place no CT pode falhar: usar no **host FGSRV07** `pct pull 243 …/header.phtml /root/`, `sed` em `/root`, `pct push 243 …` e `chown www-data` no ficheiro.

**Outros avisos frequentes (não são bugs da app):**

- **`beacon.min.js` / Cloudflare Insights — `ERR_BLOCKED_BY_ADBLOCKER`:** tráfego de analítica injetado ou via extensão; com adblock é esperado — não requer alteração de código.
- **`webpage_content_reporter.js` — `Unexpected token 'export'`:** ficheiro típico de **extensão do browser** (não servido pelo `fg-legacy`); desactivar extensões para testar, ou ignorar.
- **Consola “limpa” (2026-04-29):** em `include/head_new.php` — Maps com **`&loading=async`** (recomendação Google), **Vue 1.0.15 `vue.min.js`** (remove aviso Devtools), **`pisca_alerta` / `fechar` / `abrir`** com verificação de DOM antes de `.style`. Paridade em `include/head.php` para `pisca_alerta`. Script: `scripts/maint/fgsrv07/patch-fg-head-console.py`.
- **`getthedate()` / `#clock` (2026-04-29):** se o elemento **`clock`** não existir no topo (AJAX ainda não carregou ou layout sem relógio), **`innerHTML` em `null`** — corrigido em **`head_new.php`** e **`head.php`** com testes a `document.all.clock` / `getElementById("clock")`; removido **`document.write`** nesse ramo. Script: `scripts/maint/fgsrv07/patch-fg-getthedate-clock.py`. **Nota:** consola totalmente vazia com adblock + CF Insights + extensões não é garantível só no PHP — desligar **Web Analytics** na zona Cloudflare reduz pedidos ao `beacon.min.js`.
- **`$ is not a function` na raiz `/` (2026-04-29):** em **`app/views/footer.phtml`**, **`bootstrap.min.js`** carregava antes de **`jQuery.noConflict()`** (`$tool` / `$place`), o que **libertava o `$` global** depois do Bootstrap se registar — os *data-api* do Bootstrap (ex. `dropdown-toggle`) rebentavam ao despachar. Correcção: remover **`noConflict`** nesse footer e usar **`jQuery(document).ready(function ($) { ... })`** e **`jQuery(function ($) { ... })`** para `$` local. Script: `scripts/maint/fgsrv07/patch-fg-footer-jquery-noconflict.py`.

### Disco no CT243 e Git

- **Alargamento (2026-04-29):** no **FGSRV07**, `pct resize 243 rootfs 60G` (imagem + `resize2fs` no host). Dentro do CT, `/` com **~60 GiB** e espaço livre para `apt` / Git.
- **Git no CT:** `git` instalado; `git init -b dev` em `/var/www/fg_antigo`, `git config --global safe.directory` para o path, primeiro commit com **`.gitignore`**, `git remote add origin git@github.com:AGLz/fg-legacy.git`. **`git push`** exige **chave SSH** em `/root/.ssh` (ou deploy key) no CT — sem chave, `Permission denied (publickey)`.
- **Apt e Tailscale:** se `apt-get update` falhar com **GPG** no repositório Tailscale, o `.list` pode estar em `tailscale.list.bak-apt` (renomeado temporariamente). **Repor** `tailscale.list` e reinstalar a chave (ver [docs Tailscale Ubuntu](https://tailscale.com/kb/1187/install-ubuntu-2204/)) ou manter o `.bak-apt` até corrigir chave em `/usr/share/keyrings/`.
- Guia geral: `docs/maint/FG-ANTIGO-GIT-E-FLUXO.md` §2.2.

### No CT243 (SSH)

1. **Logs** (caminhos típicos Ubuntu + Nginx + php5.6-fpm):

   ```bash
   sudo tail -80 /var/log/nginx/error.log
   sudo journalctl -u php5.6-fpm -n 80 --no-pager
   ```

   Procurar **Fatal error**, **mysqli_connect**, **Access denied**, **Unknown database**.

2. **Ligação MySQL a partir do próprio CT** (mesma rede que a app usa):

   ```bash
   mysql -h 192.168.70.135 -u root -p'***' -e "SELECT 1 AS ok;"
   ```

   Se falhar → firewall entre CT243↔CT235, credencial `root`@`192.168.70.%`, ou serviço MariaDB no CT235. Ver `docs/fg-mysql-ha/infos.md`.

3. **Onde a BD está definida no login**

   ```bash
   grep -nE 'mysqli|mysql_|MYSQL_|host|191\.252|192\.168' /var/www/fg_antigo/public_html/autentica.php
   grep -nE 'require|include' /var/www/fg_antigo/public_html/autentica.php | head -20
   ```

   O fluxo pode incluir **`arcabouco/constantes.php`** ou ter **host antigo** (`191.252.201.205`) ainda em linha — alinhar com **`MYSQL_HOST` = `192.168.70.135`** (mysql7).

4. **PHP fatal não tratado** — `display_errors` costuma estar off em produção; o **500** só desaparece quando o erro nos logs for corrigido (include em falta, função inexistente, extensão em falta).

### Depois de corrigir

- Voltar a testar login em **`https://www5.aglz.io`** (mesmo origin da sessão).
- Opcional: `npm run test:e2e:falg:www5-aglz` com `FALG_E2E_*` definidos.

---

## Referências cruzadas

- `docs/maint/FGSRV04-php-runtime-fg-antigo-checkpoint.md`
- `docs/maint/FGSRV04-fg-antigo-php-optimization.md`
- `docs/maint/FG-ANTIGO-GIT-E-FLUXO.md` (§2.1 rsync; §2.2 Git `AGLz/fg-legacy`)
- `docs/INFRA.md` — FGSRV07, CT235, CT170

**Última atualização:** 2026-04-29 (§console: footer `noConflict`/`$`, `getthedate`/`#clock`, Maps `loading=async`, Vue min, `pisca_alerta`/popup; jQuery `document.write` + disco CT243 + CF/adblock; §7+ anteriores)
