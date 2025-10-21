# Plano de Upgrade: fg_OLD3 → PHP 8.4 + Laravel 11

**Data:** 2025-10-07
**Host:** FGSRV05 (100.71.107.26 via Tailscale)
**Aplicação:** /var/www/fg_OLD3
**Estado Atual:** Laravel 5.5 + PHP 7.4-fpm
**Estado Alvo:** Laravel 11 + PHP 8.4-fpm

---

## 📊 ANÁLISE DO ESTADO ATUAL

### Ambiente Atual
- **Laravel:** 5.5.* (EOL desde Setembro 2019)
- **PHP:** 7.4-fpm (EOL desde Novembro 2022) ⚠️
- **NGINX:** 1.23.2 ✅
- **Cache/Session:** Redis ✅
- **Banco:** MySQL + SQLite

### PHP Disponíveis no Sistema
```
✅ PHP 5.6, 7.0, 7.1, 7.2, 7.3, 7.4
✅ PHP 8.0, 8.1, 8.2, 8.3, 8.4
```

### Dependências Críticas
```json
"require": {
    "php": ">=7.0.0",
    "laravel/framework": "5.5.*",
    "eduardokum/laravel-boleto": "^0.7.1",  // ⚠️ Pode precisar atualização
    "tymon/jwt-auth": "dev-develop",          // ⚠️ Versão dev
    "barryvdh/laravel-dompdf": "^0.8.1",     // ⚠️ Antiga
    "spatie/laravel-backup": "^5.1"          // ⚠️ Antiga
}
```

### PHP-FPM 7.4 Pool Config (Atual)
```ini
pm = dynamic
pm.max_children = 5        // ⚠️ Muito baixo para produção
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 3
```

### Documentação Existente
- ✅ `00-INICIO-AQUI.md` - Overview
- ✅ `README-fg_OLD3.md` - Documentação completa
- ✅ `ANALISE_OTIMIZACAO.md` - Análise anterior
- ✅ `CORRECAO_DIGITO_CONTA_BOLETO.md` - Fix boleto
- ✅ `apply-boleto-fix.sh` - Script de fix

---

## 🎯 OBJETIVO: PHP 8.4 + LARAVEL 11

### PHP 8.4 Features
- ✅ Property hooks
- ✅ Asymmetric visibility
- ✅ `#[\Deprecated]` attribute
- ✅ JIT improvements
- ✅ Performance enhancements

### Laravel 11 Features
- ✅ Requires PHP 8.2+ (8.4 fully supported)
- ✅ Streamlined application structure
- ✅ Per-second rate limiting
- ✅ Health routing
- ✅ Graceful encryption rotation
- ✅ Improved queue testing
- ✅ Resolvable validation rules

---

## 🗺️ ESTRATÉGIA DE UPGRADE

### Opção A: Incremental Upgrade (RECOMENDADO)
**Tempo:** 5-7 dias
**Risco:** Baixo-Médio
**Caminho:** 5.5 → 6 → 8 → 10 → 11

**Vantagens:**
- ✅ Identifica problemas gradualmente
- ✅ Testa em cada versão
- ✅ Rollback mais fácil
- ✅ Documentação clara para cada passo

**Desvantagens:**
- ⏱️ Mais tempo
- 🔄 Múltiplos deploys

### Opção B: Salto Direto (ALTO RISCO)
**Tempo:** 2-3 dias
**Risco:** Alto
**Caminho:** 5.5 → 11 direto

**Vantagens:**
- ⚡ Mais rápido

**Desvantagens:**
- ❌ Muitos breaking changes simultâneos
- ❌ Difícil debugar
- ❌ Pode quebrar sem aviso claro
- ❌ NÃO RECOMENDADO

### Opção C: Reescrita Gradual (LONGO PRAZO)
**Tempo:** 3-6 meses
**Risco:** Baixo
**Caminho:** Nova aplicação Laravel 11 paralela

---

## 📋 PLANO DETALHADO: UPGRADE INCREMENTAL

### Fase 0: Preparação e Backup (1 dia)

#### 0.1 Criar Backup Completo
```bash
# Backup código
cd /var/www
tar -czf fg_OLD3_backup_$(date +%Y%m%d).tar.gz fg_OLD3/

# Backup banco de dados
mysqldump -u root -p falg_db > falg_db_backup_$(date +%Y%m%d).sql

# Backup Redis (se persistência ativa)
redis-cli --rdb /root/backups/dump_$(date +%Y%m%d).rdb
```

#### 0.2 Criar Branch Git
```bash
cd /var/www/fg_OLD3
git init
git add .
git commit -m "Estado inicial antes upgrade Laravel/PHP"
git branch upgrade-php84-laravel11
git checkout upgrade-php84-laravel11
```

#### 0.3 Documentar Estado Atual
```bash
cd /var/www/fg_OLD3
php7.4 artisan route:list > docs/routes_before_upgrade.txt
composer show > docs/packages_before_upgrade.txt
```

#### 0.4 Ambiente de Teste
```bash
# Criar cópia para teste
cp -r /var/www/fg_OLD3 /var/www/fg_OLD3_upgrade_test
cd /var/www/fg_OLD3_upgrade_test

# Configurar .env de teste
cp .env .env.production.backup
# Ajustar DB_DATABASE para banco de testes
```

---

### Fase 1: Laravel 5.5 → 6.0 (1 dia)

#### 1.1 Pré-requisitos
- PHP 7.2+ (já temos 7.4 ✅)
- Revisar [Laravel 6 Upgrade Guide](https://laravel.com/docs/6.x/upgrade)

#### 1.2 Atualizar composer.json
```json
{
    "require": {
        "php": "^7.2|^8.0",
        "laravel/framework": "^6.0",
        "laravel/tinker": "^2.0",
        // Atualizar outras dependências
    }
}
```

#### 1.3 Breaking Changes Principais
- `Str` e `Arr` helpers movidos para classes
- `$loop` variable changes
- Exception handling changes
- Authorization response changes

#### 1.4 Comandos
```bash
composer update
php artisan view:clear
php artisan cache:clear
php artisan config:clear
php artisan migrate
```

#### 1.5 Testes
- [ ] Login funciona
- [ ] Geração de boleto funciona
- [ ] API endpoints respondem
- [ ] Jobs/Queues processam

---

### Fase 2: Laravel 6 → 8 (1-2 dias)

#### 2.1 Laravel 7 (Intermediário)
**Pré-requisitos:** PHP 7.2.5+

```json
"laravel/framework": "^7.0"
```

**Breaking Changes:**
- `date` serialization format
- `password_hash` changes
- Factory classes

#### 2.2 Laravel 8
**Pré-requisitos:** PHP 7.3+ (temos 7.4 ✅)

```json
"laravel/framework": "^8.0"
```

**Breaking Changes Críticos:**
- Model factories reescrito completamente
- Maintenance mode improvements
- Closure event listeners
- `app/Models` namespace

#### 2.3 Mudanças Estruturais
```bash
# Mover models para app/Models/
mkdir -p app/Models
mv app/*.php app/Models/ 2>/dev/null || true

# Atualizar namespaces
find app/Models -type f -exec sed -i 's/namespace App;/namespace App\\Models;/g' {} \;
```

---

### Fase 3: Laravel 8 → 10 (1 dia)

#### 3.1 Laravel 9 (Intermediário)
**Pré-requisitos:** PHP 8.0+ (temos 8.4 ✅)

```json
"laravel/framework": "^9.0"
```

**Importante:** Aqui começamos a usar PHP 8.x!

#### 3.2 Laravel 10
**Pré-requisitos:** PHP 8.1+ (temos 8.4 ✅)

```json
"laravel/framework": "^10.0"
```

**Breaking Changes:**
- Minimum PHP 8.1
- Predis dependency
- Service mocking
- Dispatch return types

---

### Fase 4: Laravel 10 → 11 (1 dia)

#### 4.1 Pré-requisitos
- PHP 8.2+ (temos 8.4 ✅)

#### 4.2 Atualizar composer.json
```json
{
    "require": {
        "php": "^8.2",
        "laravel/framework": "^11.0"
    }
}
```

#### 4.3 Breaking Changes Principais
- Application structure streamlined
- Minimum PHP 8.2
- Carbon 3
- Password rehashing on change

#### 4.4 Comandos
```bash
composer update
php artisan optimize:clear
php artisan migrate
```

---

### Fase 5: Migração PHP 7.4 → 8.4 (0.5 dia)

#### 5.1 Verificar PHP 8.4-fpm
```bash
systemctl status php8.4-fpm
cat /etc/php/8.4/fpm/pool.d/www.conf
```

#### 5.2 Criar Pool Dedicado
```bash
# Criar pool dedicado para fg_OLD3
cat > /etc/php/8.4/fpm/pool.d/fg_old3.conf << 'EOF'
[fg_old3]
user = www-data
group = www-data
listen = /run/php/php8.4-fpm-fg_old3.sock
listen.owner = www-data
listen.group = www-data
listen.mode = 0660

pm = dynamic
pm.max_children = 20           # Aumentado para produção
pm.start_servers = 5
pm.min_spare_servers = 3
pm.max_spare_servers = 10
pm.max_requests = 500
pm.status_path = /status

php_admin_value[error_log] = /var/log/php8.4-fpm-fg_old3.log
php_admin_flag[log_errors] = on

; OPcache otimizado
php_value[opcache.enable] = 1
php_value[opcache.memory_consumption] = 256
php_value[opcache.max_accelerated_files] = 20000
php_value[opcache.validate_timestamps] = 0
php_value[opcache.revalidate_freq] = 0

; Limites
php_value[max_execution_time] = 60
php_value[max_input_time] = 60
php_value[memory_limit] = 256M
php_value[post_max_size] = 50M
php_value[upload_max_filesize] = 50M
EOF

# Reiniciar PHP-FPM
systemctl restart php8.4-fpm
```

#### 5.3 Atualizar NGINX Config
```nginx
# /etc/nginx/sites-available/api.falg.com.br
server {
    listen 80;
    listen [::]:80;

    server_name api.falg.com.br;
    root /var/www/fg_OLD3/public;
    index index.php;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    location / {
        try_files $uri $uri/ /index.php$is_args$args;
    }

    # Cache static assets
    location ~* \.(ico|pdf|flv|jpg|jpeg|png|gif|js|css|swf|woff|woff2)$ {
        expires 1y;
        etag off;
        add_header Cache-Control "public, no-transform";
    }

    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    location ~ \.php$ {
        try_files $uri =404;
        fastcgi_pass unix:/run/php/php8.4-fpm-fg_old3.sock;  # ← PHP 8.4!
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;

        # FastCGI optimizations
        fastcgi_buffers 16 16k;
        fastcgi_buffer_size 32k;
        fastcgi_connect_timeout 60;
        fastcgi_send_timeout 60;
        fastcgi_read_timeout 60;
    }

    location ~ /\.ht {
        deny all;
    }

    # Deny access to sensitive files
    location ~ /\.(git|env) {
        deny all;
    }
}
```

#### 5.4 Testar e Ativar
```bash
# Testar config
nginx -t

# Criar link simbólico
ln -sf /etc/nginx/sites-available/api.falg.com.br /etc/nginx/sites-enabled/

# Reload NGINX
systemctl reload nginx

# Verificar
curl -I http://api.falg.com.br
```

---

### Fase 6: Otimizações PHP 8.4 + Laravel 11 (0.5 dia)

#### 6.1 OPcache Configuration
```ini
; /etc/php/8.4/mods-available/opcache.ini
[opcache]
opcache.enable=1
opcache.enable_cli=1
opcache.memory_consumption=256
opcache.interned_strings_buffer=16
opcache.max_accelerated_files=20000
opcache.max_wasted_percentage=5
opcache.validate_timestamps=0        ; Produção
opcache.revalidate_freq=0            ; Produção
opcache.save_comments=1
opcache.fast_shutdown=1

; JIT (PHP 8+)
opcache.jit_buffer_size=256M
opcache.jit=tracing                  ; ou "function" para menos memory
```

#### 6.2 Laravel Optimizations
```bash
cd /var/www/fg_OLD3

# Clear all caches first
php8.4 artisan optimize:clear

# Build optimized caches
php8.4 artisan config:cache
php8.4 artisan route:cache
php8.4 artisan view:cache
php8.4 artisan event:cache

# Optimize autoloader
composer install --optimize-autoloader --no-dev

# Optimize Composer classmap
composer dump-autoload --optimize --classmap-authoritative
```

#### 6.3 Redis Configuration
```bash
# Verificar Redis
redis-cli ping
redis-cli INFO memory

# Configurar maxmemory se necessário
redis-cli CONFIG SET maxmemory 512mb
redis-cli CONFIG SET maxmemory-policy allkeys-lru
```

#### 6.4 Queue Workers (Supervisor)
```ini
; /etc/supervisor/conf.d/fg_old3_worker.conf
[program:fg_old3_worker]
process_name=%(program_name)s_%(process_num)02d
command=php8.4 /var/www/fg_OLD3/artisan queue:work redis --sleep=3 --tries=3 --max-time=3600
autostart=true
autorestart=true
stopasgroup=true
killasgroup=true
user=www-data
numprocs=4
redirect_stderr=true
stdout_logfile=/var/www/fg_OLD3/storage/logs/worker.log
stopwaitsecs=3600
```

```bash
# Ativar
supervisorctl reread
supervisorctl update
supervisorctl start fg_old3_worker:*
```

---

## 🧪 TESTES EM CADA FASE

### Checklist de Testes
- [ ] **Autenticação:** Login/logout funciona
- [ ] **API:** Endpoints principais respondem (200/401/403)
- [ ] **Boleto:** Geração de boleto + CNAB 400
- [ ] **Database:** Queries executam corretamente
- [ ] **Cache:** Redis funciona
- [ ] **Queue:** Jobs processam
- [ ] **Upload:** Upload de arquivos funciona
- [ ] **PDF:** Geração de PDF (dompdf)
- [ ] **Logs:** Logs são escritos corretamente
- [ ] **Performance:** Response time < 200ms (endpoints simples)

### Ferramentas de Teste
```bash
# Teste rápido HTTP
curl -X POST https://api.falg.com.br/api/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@falg.com.br","password":"test"}'

# Laravel Dusk (se configurado)
php artisan dusk

# PHPUnit
php artisan test
```

---

## ⚠️ PONTOS DE ATENÇÃO

### Dependências Críticas

#### 1. eduardokum/laravel-boleto
**Status:** Requer análise
**Fix Aplicado:** Posição 29 (dígito conta)

**Ações:**
- [ ] Verificar compatibilidade Laravel 11
- [ ] Manter patch/fork se necessário
- [ ] Testar CNAB 400/240

#### 2. tymon/jwt-auth
**Status:** `dev-develop` ⚠️

**Ações:**
- [ ] Atualizar para versão estável `^2.0`
- [ ] Verificar breaking changes
- [ ] Testar autenticação

#### 3. Packages EOL
```bash
# Verificar packages desatualizados
composer outdated

# Substituir se necessário:
# - barryvdh/laravel-dompdf → mpdf ou Browsershot
# - spatie/laravel-backup → versão 8.x+
```

### Breaking Changes PHP 8.4

1. **Deprecated Warnings:**
   - Implicit nullable types
   - `${var}` string interpolation

2. **Removidos:**
   - `get_class()` sem argumento em traits
   - Array/string offset access com `{}`

3. **Novos:**
   - Property hooks (não afetar código existente)
   - `#[\Deprecated]` attribute

---

## 📊 COMPARAÇÃO PERFORMANCE

### Benchmark Esperado

| Métrica | Laravel 5.5 + PHP 7.4 | Laravel 11 + PHP 8.4 | Melhoria |
|---------|------------------------|----------------------|----------|
| Request Time | ~150-200ms | ~80-120ms | **40-50%** ↓ |
| Memory Usage | ~45MB/req | ~35MB/req | **22%** ↓ |
| Throughput | ~100 req/s | ~180 req/s | **80%** ↑ |
| OPcache Hit | ~85% | ~95% | **10%** ↑ |

### Ferramentas de Benchmark
```bash
# Apache Bench
ab -n 1000 -c 10 https://api.falg.com.br/api/status

# wrk
wrk -t4 -c100 -d30s https://api.falg.com.br/api/status
```

---

## 🔄 ROLLBACK STRATEGY

### Rollback Rápido (NGINX + Symlink)
```bash
# Manter versões paralelas
/var/www/fg_OLD3_laravel5      # Original
/var/www/fg_OLD3_laravel11     # Novo

# NGINX aponta para symlink
/var/www/fg_OLD3 → fg_OLD3_laravel11

# Rollback instantâneo
ln -sfn /var/www/fg_OLD3_laravel5 /var/www/fg_OLD3
systemctl reload nginx
```

### Rollback de Banco de Dados
```bash
# Restore do backup
mysql -u root -p falg_db < falg_db_backup_YYYYMMDD.sql
```

### Rollback PHP-FPM Pool
```bash
# Trocar socket no NGINX
# fastcgi_pass unix:/run/php/php7.4-fpm.sock;
nginx -t && systemctl reload nginx
```

---

## 📅 CRONOGRAMA SUGERIDO

| Dia | Fase | Atividades | Responsável |
|-----|------|------------|-------------|
| **D0** | Preparação | Backups, Git, Docs | DevOps |
| **D1** | Laravel 5.5 → 6 | Upgrade + Testes | Dev + QA |
| **D2-D3** | Laravel 6 → 8 | Upgrade L7, L8 + Testes | Dev + QA |
| **D4** | Laravel 8 → 10 | Upgrade L9, L10 + Testes | Dev + QA |
| **D5** | Laravel 10 → 11 | Upgrade + Testes | Dev + QA |
| **D6** | PHP 8.4 | Migrar PHP-FPM + NGINX | DevOps |
| **D7** | Otimizações | OPcache, Caches, Supervisor | DevOps |
| **D8** | Testes Final | Validação completa | QA |
| **D9** | Deploy Produção | Go-live + Monitoramento | Todos |
| **D10+** | Estabilização | Monitoring + Ajustes | DevOps |

---

## 🎯 PRÓXIMOS PASSOS IMEDIATOS

### 1. Decisão de Estratégia
- [ ] Aprovar estratégia: Incremental vs Direto vs Reescrita
- [ ] Definir timeline
- [ ] Alocar recursos (dev/devops)

### 2. Preparação Ambiente
- [ ] Criar backups completos
- [ ] Configurar Git repository
- [ ] Preparar ambiente de staging

### 3. Fase Piloto
- [ ] Testar upgrade 5.5 → 6 em staging
- [ ] Validar boletos continuam funcionando
- [ ] Documentar issues encontrados

---

## 📚 REFERÊNCIAS

### Documentação Oficial
- [Laravel 6 Upgrade Guide](https://laravel.com/docs/6.x/upgrade)
- [Laravel 7 Upgrade Guide](https://laravel.com/docs/7.x/upgrade)
- [Laravel 8 Upgrade Guide](https://laravel.com/docs/8.x/upgrade)
- [Laravel 9 Upgrade Guide](https://laravel.com/docs/9.x/upgrade)
- [Laravel 10 Upgrade Guide](https://laravel.com/docs/10.x/upgrade)
- [Laravel 11 Upgrade Guide](https://laravel.com/docs/11.x/upgrade)
- [PHP 8.4 Migration Guide](https://www.php.net/manual/en/migration84.php)

### Ferramentas Úteis
- [Laravel Shift](https://laravelshift.com/) - Upgrade automatizado ($29-39/versão)
- [Rector](https://github.com/rectorphp/rector-laravel) - Refactoring automatizado
- [PHPStan](https://phpstan.org/) - Static analysis

---

**Status:** 🟡 Plano pronto, aguardando aprovação
**Última Atualização:** 2025-10-07
**Contato:** Claude Code AI + Hive Mind
