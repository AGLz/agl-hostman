# FGSRV04 — Checkpoint de runtime PHP (`fg_antigo`)

**Ambiente:** FGSRV04 (`100.111.79.2`), produção `falg.com.br` → `/var/www/fg_antigo/public_html`.

**Data da recolha:** 2026-04-28 (SSH root).

## Versão efectiva no Nginx

O vhost **`/etc/nginx/sites-enabled/fg_old`** usa:

```text
fastcgi_pass unix:/var/run/php/php5.6-fpm.sock;
```

Ou seja, **`fg_antigo` corre em PHP 5.6 FPM**, não no `php` default da CLI.

## Versões instaladas (CLI)

| Binário | Versão (resumo) |
|---------|------------------|
| `/usr/bin/php` (default) | **PHP 8.2.7** (Zend OPcache + **Xdebug** na CLI) |
| `/usr/bin/php5.6` | **PHP 5.6.40** (deb.sury, Ubuntu 18.04 target + Zend OPcache) |

Serviços **running:** `php5.6-fpm.service`, `php8.2-fpm.service`. Árvore `/etc/php/` inclui ramos **5.6 … 8.2**.

## Módulos PHP 5.6 (`php5.6 -m`) — espelhar no CT destino

Lista utilizada para checklist de pacotes no novo CT (ordem alfabética):

`bcmath`, `calendar`, `Core`, `ctype`, `curl`, `date`, `dom`, `ereg`, `exif`, `fileinfo`, `filter`, `ftp`, `gd`, `gettext`, `hash`, `iconv`, `imap`, `intl`, `json`, `libxml`, `mbstring`, `mhash`, **`mysql`**, **`mysqli`**, `mysqlnd`, `openssl`, `pcntl`, `pcre`, `PDO`, `pdo_mysql`, `pdo_sqlite`, `Phar`, `posix`, `readline`, `Reflection`, `session`, `shmop`, `SimpleXML`, `soap`, `sockets`, `SPL`, `sqlite3`, `standard`, `sysvmsg`, `sysvsem`, `sysvshm`, `tokenizer`, `wddx`, `xml`, `xmlreader`, `xmlrpc`, `xmlwriter`, `xsl`, **Zend OPcache**, `zip`, `zlib`.

## Notas

1. **`mysql`** (extensão legacy) está presente no 5.6 — migrations futuras para PHP mais novo devem eliminar dependência dessa extensão.
2. O **default CLI 8.2** tem **Xdebug** — **não** assumir isso em produção no novo CT (omitir ou só dev).
3. Ao construir o CT em **Debian/Proxmox**, confirmar repositório (**deb.sury.org** ou imagem base compatível) que disponibilize **`php5.6-fpm`** e módulos acima; se não for viável, abrir projeto formal de **upgrade de PHP** fora do escopo “lift-and-shift”.

**Última atualização:** 2026-04-28
