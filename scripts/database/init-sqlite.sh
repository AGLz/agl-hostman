#!/bin/bash
# SQLite Database Initialization Script
# AGL Hostman - Multi-Database Setup

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")/../src"
DATABASE_DIR="$PROJECT_ROOT/database"
DATABASE_FILE="$DATABASE_DIR/database.sqlite"

echo "AGL Hostman - SQLite Initialization"
echo "===================================="

# Create database directory if it doesn't exist
if [ ! -d "$DATABASE_DIR" ]; then
    echo "Creating database directory..."
    mkdir -p "$DATABASE_DIR"
fi

# Create database file if it doesn't exist
if [ ! -f "$DATABASE_FILE" ]; then
    echo "Creating SQLite database file..."
    touch "$DATABASE_FILE"
    echo "Database file created: $DATABASE_FILE"
else
    echo "Database file already exists: $DATABASE_FILE"
fi

# Set proper permissions
chmod 664 "$DATABASE_FILE"
echo "Permissions set to 664"

# Run migrations if Laravel artisan exists
if [ -f "$PROJECT_ROOT/artisan" ]; then
    echo ""
    echo "Running Laravel migrations..."
    cd "$PROJECT_ROOT"
    php artisan migrate --force
    echo "Migrations completed successfully!"
else
    echo "Warning: artisan.php not found. Run migrations manually:"
    echo "  cd src && php artisan migrate"
fi

echo ""
echo "SQLite database initialized successfully!"
echo "Database location: $DATABASE_FILE"
