#!/bin/sh
# Nginx + PHP-FPM no mesmo contentor (CT134 produção).
set -e

# Reason: volume Docker sobrescreve storage/ da imagem — garantir dirs Blade/cache
mkdir -p /var/www/html/storage/framework/cache/data \
    /var/www/html/storage/framework/sessions \
    /var/www/html/storage/framework/views \
    /var/www/html/storage/framework/testing \
    /var/www/html/storage/logs \
    /var/www/html/bootstrap/cache
# remover artefacto antigo de brace expansion (sh sem bash)
if [ -d '/var/www/html/storage/framework/{cache,sessions,views,testing}' ]; then
    rm -rf '/var/www/html/storage/framework/{cache,sessions,views,testing}'
fi
chown -R laravel:www-data /var/www/html/storage/framework /var/www/html/storage/logs /var/www/html/bootstrap/cache 2>/dev/null || true
chmod -R ug+rwx /var/www/html/storage/framework /var/www/html/storage/logs /var/www/html/bootstrap/cache 2>/dev/null || true

cat > /etc/nginx/nginx.conf <<'EOF'
events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    sendfile on;
    keepalive_timeout 65;
    client_max_body_size 40M;
    include /etc/nginx/conf.d/*.conf;
}
EOF

if [ -f /etc/nginx/conf.d/app.conf ]; then
    sed -i 's|/var/www/public|/var/www/html/public|g' /etc/nginx/conf.d/app.conf
    sed -i 's|fastcgi_pass app:9000|fastcgi_pass 127.0.0.1:9000|g' /etc/nginx/conf.d/app.conf
fi

nginx
exec php-fpm
