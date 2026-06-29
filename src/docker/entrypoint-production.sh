#!/bin/sh
# Nginx + PHP-FPM no mesmo contentor (CT134 produção).
set -e

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
