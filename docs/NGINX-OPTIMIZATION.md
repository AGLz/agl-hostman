# 🌐 NGINX OTIMIZAÇÃO - Melhorias de Performance

**Problema:** Nginx pode estar rejeitando conexões durante picos de tráfego
**Solução:** Configurar burst handling, timeouts otimizados e connection pooling
**Prioridade:** 🟢 BAIXA (após outras correções)

---

## 🎯 OBJETIVOS

1. Configurar burst handling para absorver picos de tráfego
2. Otimizar timeouts para evitar conexões travadas
3. Implementar connection pooling com PHP-FPM
4. Configurar rate limiting inteligente

---

## 🔍 PASSO 1: DIAGNOSTICAR CONFIGURAÇÃO ATUAL (fgsrv4 & fgsrv5)

```bash
# Localizar configuração nginx
nginx -V 2>&1 | grep "configure arguments"
nginx -t  # Testar sintaxe

# Configuração principal
sudo cat /etc/nginx/nginx.conf

# Configurações de sites
sudo ls -la /etc/nginx/sites-enabled/
sudo ls -la /etc/nginx/conf.d/

# Ver configuração atual do site
sudo cat /etc/nginx/sites-enabled/default
# OU
sudo cat /etc/nginx/conf.d/*.conf
```

---

## 🛠️ PASSO 2: OTIMIZAR NGINX.CONF PRINCIPAL

### Backup da configuração:

```bash
sudo cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup-$(date +%Y%m%d)
```

### Editar configuração principal:

```bash
sudo nano /etc/nginx/nginx.conf
```

### Configurações recomendadas:

```nginx
user www-data;
worker_processes auto;  # Usar todos os CPU cores
pid /run/nginx.pid;

events {
    worker_connections 2048;  # Aumentar de 1024
    use epoll;                # Linux otimizado
    multi_accept on;          # Aceitar múltiplas conexões
}

http {
    ##
    # Basic Settings
    ##

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    types_hash_max_size 2048;
    server_tokens off;  # Segurança: não expor versão nginx

    # Timeouts otimizados
    keepalive_timeout 65;
    client_body_timeout 30;
    client_header_timeout 30;
    send_timeout 30;

    # Buffer sizes
    client_body_buffer_size 128k;
    client_max_body_size 20M;
    client_header_buffer_size 1k;
    large_client_header_buffers 4 16k;

    ##
    # Gzip Compression
    ##

    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml+rss
        application/rss+xml
        font/truetype
        font/opentype
        application/vnd.ms-fontobject
        image/svg+xml;
    gzip_disable "msie6";

    ##
    # Connection Pooling para PHP-FPM
    ##

    upstream php-fpm {
        server unix:/run/php/php-fpm.sock;
        # OU: server 127.0.0.1:9000;

        keepalive 32;  # Manter 32 conexões abertas
    }

    ##
    # Rate Limiting (preparação - configurar por site)
    ##

    # Zona de rate limiting para IPs
    limit_req_zone $binary_remote_addr zone=general:10m rate=10r/s;
    limit_req_zone $binary_remote_addr zone=api:10m rate=30r/s;

    # Zona de conexões simultâneas
    limit_conn_zone $binary_remote_addr zone=addr:10m;

    ##
    # Logging Settings
    ##

    # Log format com timing
    log_format timing '$remote_addr - $remote_user [$time_local] '
                      '"$request" $status $body_bytes_sent '
                      '"$http_referer" "$http_user_agent" '
                      'rt=$request_time uct="$upstream_connect_time" '
                      'uht="$upstream_header_time" urt="$upstream_response_time"';

    access_log /var/log/nginx/access.log timing;
    error_log /var/log/nginx/error.log warn;

    ##
    # Virtual Host Configs
    ##

    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
```

---

## 🚀 PASSO 3: CONFIGURAR BURST HANDLING (fgsrv4 - falg.com.br)

### Editar configuração do site:

```bash
sudo nano /etc/nginx/sites-enabled/falg.com.br
# OU
sudo nano /etc/nginx/conf.d/falg.com.br.conf
```

### Configuração com burst handling:

```nginx
server {
    listen 80;
    listen [::]:80;
    server_name falg.com.br www.falg.com.br;

    # Redirect HTTP to HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name falg.com.br www.falg.com.br;

    root /var/www/falg.com.br;
    index index.php index.html index.htm;

    # SSL configuration (ajustar paths)
    ssl_certificate /etc/ssl/certs/falg.com.br.crt;
    ssl_certificate_key /etc/ssl/private/falg.com.br.key;

    # =========================================================================
    # RATE LIMITING COM BURST HANDLING
    # =========================================================================

    # Rate limiting: 10 req/s, burst de 20, sem delay
    limit_req zone=general burst=20 nodelay;

    # Limite de conexões simultâneas: 10 por IP
    limit_conn addr 10;

    # =========================================================================
    # PHP-FPM CONFIGURATION
    # =========================================================================

    location ~ \.php$ {
        try_files $uri =404;
        fastcgi_split_path_info ^(.+\.php)(/.+)$;

        # Usar upstream com keepalive
        fastcgi_pass php-fpm;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param PATH_INFO $fastcgi_path_info;

        # Timeouts otimizados
        fastcgi_connect_timeout 60s;
        fastcgi_send_timeout 180s;
        fastcgi_read_timeout 180s;

        # Buffer otimizado
        fastcgi_buffer_size 128k;
        fastcgi_buffers 256 16k;
        fastcgi_busy_buffers_size 256k;
        fastcgi_temp_file_write_size 256k;

        # IMPORTANTE: Manter conexões com PHP-FPM
        fastcgi_keep_conn on;
    }

    # =========================================================================
    # STATIC FILES CACHING
    # =========================================================================

    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
        access_log off;
    }

    # =========================================================================
    # SECURITY
    # =========================================================================

    location ~ /\.ht {
        deny all;
    }

    location = /favicon.ico {
        log_not_found off;
        access_log off;
    }

    location = /robots.txt {
        log_not_found off;
        access_log off;
    }
}
```

---

## 🔧 PASSO 4: CONFIGURAR API (fgsrv5 - api.falg.com.br)

### Editar configuração da API:

```bash
sudo nano /etc/nginx/sites-enabled/api.falg.com.br
# OU
sudo nano /etc/nginx/conf.d/api.falg.com.br.conf
```

### Configuração otimizada para Laravel API:

```nginx
server {
    listen 80;
    server_name api.falg.com.br;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name api.falg.com.br;

    root /var/www/api.falg.com.br/public;
    index index.php;

    # SSL configuration
    ssl_certificate /etc/ssl/certs/api.falg.com.br.crt;
    ssl_certificate_key /etc/ssl/private/api.falg.com.br.key;

    # =========================================================================
    # RATE LIMITING PARA API (mais permissivo)
    # =========================================================================

    # 30 requisições por segundo, burst de 50
    limit_req zone=api burst=50 nodelay;

    # 20 conexões simultâneas por IP
    limit_conn addr 20;

    # =========================================================================
    # LARAVEL ROUTING
    # =========================================================================

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        try_files $uri =404;
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass php-fpm;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;

        # Timeouts maiores para API
        fastcgi_connect_timeout 90s;
        fastcgi_send_timeout 300s;
        fastcgi_read_timeout 300s;

        # Buffers maiores para JSON responses
        fastcgi_buffer_size 256k;
        fastcgi_buffers 512 32k;
        fastcgi_busy_buffers_size 512k;

        # Keepalive
        fastcgi_keep_conn on;
    }

    # =========================================================================
    # SECURITY
    # =========================================================================

    location ~ /\.(?!well-known).* {
        deny all;
    }
}
```

---

## ✅ PASSO 5: TESTAR E APLICAR MUDANÇAS

```bash
# Testar configuração
sudo nginx -t

# Se OK, reload nginx
sudo systemctl reload nginx

# Verificar status
sudo systemctl status nginx

# Ver logs em tempo real
sudo tail -f /var/log/nginx/error.log
sudo tail -f /var/log/nginx/access.log
```

---

## 📊 PASSO 6: MONITORAR RATE LIMITING

### Ver rate limit em ação:

```bash
# Ver rejeições de rate limit
sudo grep "limiting requests" /var/log/nginx/error.log | tail -20

# Ver conexões rejeitadas
sudo grep "limiting connections" /var/log/nginx/error.log | tail -20

# Análise de timing (ver se melhorou)
sudo tail -100 /var/log/nginx/access.log | grep -E "rt=[0-9]\." | awk '{print $(NF-3)}' | sort -n
```

### Script de monitoramento nginx:

```bash
sudo tee /opt/scripts/monitor-nginx.sh > /dev/null <<'EOF'
#!/bin/bash

LOG_FILE="/var/log/nginx-monitor.log"

{
    echo "=== $(date) ==="

    echo "Active connections:"
    netstat -an | grep :80 | wc -l

    echo "Rate limit rejects (last hour):"
    sudo grep "limiting requests" /var/log/nginx/error.log | grep "$(date +%d/%b/%Y:%H)" | wc -l

    echo "Average response time (last 100 requests):"
    sudo tail -100 /var/log/nginx/access.log | grep -oP 'rt=\K[0-9.]+' | awk '{sum+=$1; count++} END {print sum/count "s"}'

    echo "Top 10 slowest requests:"
    sudo tail -1000 /var/log/nginx/access.log | grep -oP 'rt=\K[0-9.]+ .* ".*"' | sort -rn | head -10

    echo ""
} >> "$LOG_FILE"
EOF

sudo chmod +x /opt/scripts/monitor-nginx.sh

# Agendar a cada hora
sudo crontab -e
# Adicionar:
0 * * * * /opt/scripts/monitor-nginx.sh
```

---

## 🔧 OTIMIZAÇÕES ADICIONAIS

### A. Habilitar nginx stub_status:

```bash
# Adicionar ao nginx.conf ou criar arquivo separado
sudo tee /etc/nginx/conf.d/status.conf > /dev/null <<'EOF'
server {
    listen 127.0.0.1:8081;
    server_name localhost;

    location /nginx_status {
        stub_status on;
        access_log off;
        allow 127.0.0.1;
        deny all;
    }
}
EOF

sudo nginx -t && sudo systemctl reload nginx

# Testar
curl http://127.0.0.1:8081/nginx_status
```

### B. Configurar HTTP/2 Push (se aplicável):

```nginx
location = /index.html {
    http2_push /static/css/main.css;
    http2_push /static/js/main.js;
}
```

### C. Habilitar Brotli compression (se instalado):

```nginx
http {
    brotli on;
    brotli_comp_level 6;
    brotli_types text/plain text/css application/json application/javascript text/xml application/xml;
}
```

---

## 📋 CONFIGURAÇÕES DE TROUBLESHOOTING

### Durante problemas de timeout:

```bash
# 1. Ver conexões ativas
netstat -an | grep :80 | wc -l

# 2. Ver nginx workers
ps aux | grep nginx

# 3. Ver rate limit blocks em tempo real
sudo tail -f /var/log/nginx/error.log | grep limiting

# 4. Ver requests lentos em tempo real
sudo tail -f /var/log/nginx/access.log | grep -E "rt=[5-9]\."

# 5. Testar resposta do site
curl -w "\nTime: %{time_total}s\nHTTP Code: %{http_code}\n" -o /dev/null -s https://falg.com.br
```

---

## ✅ CHECKLIST DE EXECUÇÃO

### fgsrv4 (falg.com.br):
- [ ] Backup da configuração nginx
- [ ] nginx.conf otimizado (worker_connections, timeouts)
- [ ] Upstream php-fpm configurado com keepalive
- [ ] Rate limiting configurado (10r/s, burst=20)
- [ ] fastcgi_keep_conn on configurado
- [ ] Configuração testada (nginx -t)
- [ ] nginx recarregado
- [ ] Status page configurado
- [ ] Script de monitoramento agendado
- [ ] Documentação salva

### fgsrv5 (api.falg.com.br):
- [ ] Backup da configuração nginx
- [ ] nginx.conf otimizado
- [ ] Upstream php-fpm configurado
- [ ] Rate limiting API configurado (30r/s, burst=50)
- [ ] Timeouts maiores para API (300s)
- [ ] Buffers otimizados para JSON
- [ ] Configuração testada
- [ ] nginx recarregado
- [ ] Monitoramento configurado
- [ ] Documentação salva

---

## 🎯 RESULTADO ESPERADO

### Imediato:
- ✅ Burst handling absorvendo picos de tráfego
- ✅ Connection pooling reduzindo overhead
- ✅ Timeouts otimizados

### Durante janela 09:00-10:00:
- ✅ Menos conexões rejeitadas
- ✅ Response time mais estável
- ✅ Sem erros 502/504 de timeout

### Longo prazo:
- ✅ Performance consistente
- ✅ Melhor experiência do usuário
- ✅ Métricas de timing melhores

---

**Prioridade:** 🟢 BAIXA (mas importante)
**Tempo estimado:** 15-20 minutos por host
**Impacto esperado:** Melhoria geral de performance

---

**Criado por:** Hive Mind Collective Intelligence
**Complementa:** Todas as outras otimizações
**Nota:** Aplicar após correções de backup, cron e PHP-FPM
