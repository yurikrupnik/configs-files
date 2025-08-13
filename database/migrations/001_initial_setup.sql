-- Migration: 001_initial_setup
-- Description: Initial database setup with core tables
-- Created: 2024-06-27

BEGIN;

-- Check if migration already applied
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'schema_migrations') THEN
        IF EXISTS (SELECT 1 FROM schema_migrations WHERE version = '001') THEN
            RAISE NOTICE 'Migration 001 already applied, skipping';
            ROLLBACK;
            RETURN;
        END IF;
    END IF;
END
$$;

-- Create schema_migrations table if it doesn't exist
CREATE TABLE IF NOT EXISTS schema_migrations (
    version VARCHAR(255) PRIMARY KEY,
    applied_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Apply the migration from schema.sql
\i ../postgres/schema.sql

-- Record migration
INSERT INTO schema_migrations (version) VALUES ('001');

COMMIT;