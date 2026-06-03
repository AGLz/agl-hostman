#!/usr/bin/env bash
# Locale pt_BR.UTF-8 + PHP 5.6 (America/Sao_Paulo) — CT fg-legacy (Ubuntu 22.04).
# Executar dentro do CT como root, após ct-set-timezone-sao-paulo.sh.

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

echo "=== pacotes locale pt-BR ==="
apt-get update -qq
apt-get install -y -qq locales language-pack-pt language-pack-pt-base

grep -q '^pt_BR.UTF-8' /etc/locale.gen 2>/dev/null || echo 'pt_BR.UTF-8 UTF-8' >>/etc/locale.gen
locale-gen pt_BR.UTF-8

cat >/etc/default/locale <<'EOF'
LANG=pt_BR.UTF-8
LANGUAGE=pt_BR:pt
LC_ALL=pt_BR.UTF-8
EOF
update-locale LANG=pt_BR.UTF-8 LANGUAGE=pt_BR:pt LC_ALL=pt_BR.UTF-8

echo "=== PHP 5.6 timezone / charset ==="
PHP_VER="${PHP_VER:-5.6}"
MOD_INI="/etc/php/${PHP_VER}/mods-available/99-agl-locale.ini"
mkdir -p "/etc/php/${PHP_VER}/mods-available"
cat >"${MOD_INI}" <<'EOF'
; AGL fg-legacy — Brasil
date.timezone = America/Sao_Paulo
default_charset = UTF-8
EOF

for sapi in cli fpm apache2 cgi; do
    conf_d="/etc/php/${PHP_VER}/${sapi}/conf.d"
    if [[ -d "${conf_d}" ]]; then
        ln -sf "../../mods-available/99-agl-locale.ini" "${conf_d}/99-agl-locale.ini"
    fi
    ini="/etc/php/${PHP_VER}/${sapi}/php.ini"
    if [[ -f "${ini}" ]]; then
        if grep -q '^date\.timezone' "${ini}"; then
            sed -i 's|^date\.timezone.*|date.timezone = America/Sao_Paulo|' "${ini}"
        elif grep -q '^;date\.timezone' "${ini}"; then
            sed -i 's|^;date\.timezone.*|date.timezone = America/Sao_Paulo|' "${ini}"
        else
            echo 'date.timezone = America/Sao_Paulo' >>"${ini}"
        fi
    fi
done

POOL="/etc/php/${PHP_VER}/fpm/pool.d/www.conf"
if [[ -f "${POOL}" ]]; then
    python3 - "${POOL}" <<'PY'
import sys
from pathlib import Path

pool = Path(sys.argv[1])
lines = pool.read_text().splitlines()
lines = [
    ln
    for ln in lines
    if "AGL pt-BR" not in ln
    and not ln.strip().startswith("env[LANG]")
    and not ln.strip().startswith("env[LC_ALL]")
    and not ln.strip().startswith("env[LANGUAGE]")
]
out: list[str] = []
for ln in lines:
    out.append(ln)
    if ln.strip() == "[www]":
        out.extend(
            [
                "; AGL pt-BR locale",
                "env[LANG] = pt_BR.UTF-8",
                "env[LC_ALL] = pt_BR.UTF-8",
                "env[LANGUAGE] = pt_BR:pt",
                "",
            ]
        )
        if not any("php_admin_value[date.timezone]" in x for x in lines):
            out.append("php_admin_value[date.timezone] = America/Sao_Paulo")
pool.write_text("\n".join(out).rstrip() + "\n")
PY
    systemctl reload "php${PHP_VER}-fpm" 2>/dev/null || systemctl reload php-fpm 2>/dev/null || true
fi

export LANG=pt_BR.UTF-8 LC_ALL=pt_BR.UTF-8
echo "=== verificação ==="
locale | head -3
php -r 'echo "php tz=".date_default_timezone_get().PHP_EOL; setlocale(LC_TIME,"pt_BR.UTF-8"); echo strftime("%A %d/%m/%Y",time()).PHP_EOL;' 2>/dev/null || echo "AVISO: php CLI indisponível"
echo "OK ct243 locale + PHP pt-BR"
