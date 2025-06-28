#!/bin/bash

# Database migration script
set -e

DB_HOST=${DB_HOST:-localhost}
DB_PORT=${DB_PORT:-5432}
DB_NAME=${DB_NAME:-cluster_traces}
DB_USER=${DB_USER:-postgres}
DB_PASSWORD=${DB_PASSWORD:-postgres}

MIGRATIONS_DIR="$(dirname "$0")"
PSQL_CMD="psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME"

echo "🔄 Starting database migrations..."
echo "📍 Host: $DB_HOST:$DB_PORT"
echo "🗄️  Database: $DB_NAME"
echo "👤 User: $DB_USER"

# Wait for database to be ready
echo "⏳ Waiting for database to be ready..."
until $PSQL_CMD -c '\q' 2>/dev/null; do
    echo "⏳ Database not ready, waiting 2 seconds..."
    sleep 2
done

echo "✅ Database is ready!"

# Apply migrations in order
for migration_file in "$MIGRATIONS_DIR"/*.sql; do
    if [ -f "$migration_file" ]; then
        migration_name=$(basename "$migration_file")
        echo "📋 Applying migration: $migration_name"
        
        if $PSQL_CMD -f "$migration_file"; then
            echo "✅ Migration $migration_name applied successfully"
        else
            echo "❌ Migration $migration_name failed"
            exit 1
        fi
    fi
done

echo "🎉 All migrations completed successfully!"

# Show current schema version
echo "📊 Current schema version:"
$PSQL_CMD -c "SELECT version, applied_at FROM schema_migrations ORDER BY applied_at DESC LIMIT 5;"