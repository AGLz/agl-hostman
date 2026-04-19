#!/bin/bash
# MySQL 8.0 Database Initialization Script
# AGL Hostman - Multi-Database Setup

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")/../"

# Load environment variables
if [ -f "$PROJECT_ROOT/.env" ]; then
    source "$PROJECT_ROOT/.env"
fi

# Set defaults
MYSQL_HOST=${MYSQL_HOST:-127.0.0.1}
MYSQL_PORT=${MYSQL_PORT:-3307}
MYSQL_DATABASE=${MYSQL_DATABASE:-agl_hostman}
MYSQL_USER=${MYSQL_USER:-agl_user}
MYSQL_PASSWORD=${MYSQL_PASSWORD:-secret}
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD:-root_secret}

echo "AGL Hostman - MySQL 8.0 Initialization"
echo "======================================="
echo "Host: $MYSQL_HOST"
echo "Port: $MYSQL_PORT"
echo "Database: $MYSQL_DATABASE"
echo ""

# Check if MySQL is running
echo "Checking MySQL connection..."
if ! docker exec agl-hostman-mysql mysqladmin ping -h localhost -u root -p"$MYSQL_ROOT_PASSWORD" --silent 2>/dev/null; then
    echo "Error: MySQL is not running or not accessible"
    echo "Start MySQL with: docker compose -f docker-compose.yml -f docker-compose.mysql.yml up -d mysql"
    exit 1
fi
echo "MySQL is running!"

# Create databases if they don't exist
echo ""
echo "Creating databases..."
docker exec agl-hostman-mysql mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "
    CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
    CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}_cache\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
    CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}_queue\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
    CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}_sessions\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
" 2>/dev/null

echo "Databases created successfully!"

# Grant privileges
echo ""
echo "Granting privileges..."
docker exec agl-hostman-mysql mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "
    GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}%\`.* TO '$MYSQL_USER'@'%';
    FLUSH PRIVILEGES;
" 2>/dev/null

echo "Privileges granted successfully!"

# Run migrations if Laravel artisan exists
if [ -f "$PROJECT_ROOT/src/artisan" ]; then
    echo ""
    echo "Running Laravel migrations..."
    cd "$PROJECT_ROOT/src"
    php artisan migrate --force
    echo "Migrations completed successfully!"
else
    echo "Warning: artisan not found. Run migrations manually:"
    echo "  cd src && php artisan migrate"
fi

echo ""
echo "MySQL 8.0 initialized successfully!"
echo ""
echo "Connection details:"
echo "  Host: $MYSQL_HOST"
echo "  Port: $MYSQL_PORT"
echo "  Database: $MYSQL_DATABASE"
echo "  User: $MYSQL_USER"
echo "  phpMyAdmin: http://localhost:8083"
