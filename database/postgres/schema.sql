-- PostgreSQL schema for cluster traces and metrics

-- Extension for UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Clusters table
CREATE TABLE clusters (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL UNIQUE,
    environment VARCHAR(50) NOT NULL CHECK (environment IN ('local', 'staging', 'production')),
    cluster_type VARCHAR(50) NOT NULL CHECK (cluster_type IN ('local', 'aks', 'eks', 'gke')),
    region VARCHAR(100),
    zone VARCHAR(100),
    node_count INTEGER NOT NULL DEFAULT 1,
    node_size VARCHAR(50) NOT NULL DEFAULT 'medium',
    status VARCHAR(50) NOT NULL DEFAULT 'unknown' CHECK (status IN ('running', 'stopped', 'error', 'pending', 'unknown')),
    cost_budget DECIMAL(10,2) DEFAULT 0,
    cost_threshold INTEGER DEFAULT 80,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Applications table
CREATE TABLE applications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    cluster_id UUID NOT NULL REFERENCES clusters(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    namespace VARCHAR(255) NOT NULL DEFAULT 'default',
    version VARCHAR(100),
    status VARCHAR(50) NOT NULL DEFAULT 'unknown' CHECK (status IN ('running', 'stopped', 'error', 'pending', 'unknown')),
    enabled BOOLEAN NOT NULL DEFAULT true,
    helm_chart VARCHAR(255),
    helm_version VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(cluster_id, name, namespace)
);

-- Traces table for command execution traces
CREATE TABLE traces (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    cluster_id UUID REFERENCES clusters(id) ON DELETE SET NULL,
    trace_id VARCHAR(255) NOT NULL, -- OpenTelemetry trace ID
    span_id VARCHAR(255) NOT NULL,  -- OpenTelemetry span ID
    parent_span_id VARCHAR(255),
    operation_name VARCHAR(255) NOT NULL,
    service_name VARCHAR(255) NOT NULL,
    start_time TIMESTAMP WITH TIME ZONE NOT NULL,
    end_time TIMESTAMP WITH TIME ZONE,
    duration_ms BIGINT,
    status VARCHAR(50) DEFAULT 'pending' CHECK (status IN ('success', 'error', 'timeout', 'pending')),
    error_message TEXT,
    tags JSONB DEFAULT '{}',
    logs JSONB DEFAULT '[]',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Metrics table for numerical metrics
CREATE TABLE metrics (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    cluster_id UUID REFERENCES clusters(id) ON DELETE SET NULL,
    metric_name VARCHAR(255) NOT NULL,
    metric_type VARCHAR(50) NOT NULL CHECK (metric_type IN ('counter', 'gauge', 'histogram', 'summary')),
    value DECIMAL(15,6) NOT NULL,
    unit VARCHAR(50),
    labels JSONB DEFAULT '{}',
    timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Cost tracking table
CREATE TABLE costs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    cluster_id UUID NOT NULL REFERENCES clusters(id) ON DELETE CASCADE,
    cost_type VARCHAR(50) NOT NULL CHECK (cost_type IN ('compute', 'storage', 'network', 'total')),
    amount DECIMAL(10,2) NOT NULL,
    currency VARCHAR(3) NOT NULL DEFAULT 'USD',
    billing_period_start TIMESTAMP WITH TIME ZONE NOT NULL,
    billing_period_end TIMESTAMP WITH TIME ZONE NOT NULL,
    provider_cost_id VARCHAR(255),
    raw_data JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Uptime tracking
CREATE TABLE uptime_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    cluster_id UUID NOT NULL REFERENCES clusters(id) ON DELETE CASCADE,
    event_type VARCHAR(50) NOT NULL CHECK (event_type IN ('up', 'down', 'maintenance')),
    timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    duration_seconds INTEGER,
    reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Command executions (Nu script runs)
CREATE TABLE command_executions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    cluster_id UUID REFERENCES clusters(id) ON DELETE SET NULL,
    command VARCHAR(1000) NOT NULL,
    script_name VARCHAR(255),
    arguments JSONB DEFAULT '[]',
    exit_code INTEGER,
    stdout TEXT,
    stderr TEXT,
    start_time TIMESTAMP WITH TIME ZONE NOT NULL,
    end_time TIMESTAMP WITH TIME ZONE,
    duration_ms BIGINT,
    user_id VARCHAR(255),
    session_id UUID,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for better query performance
CREATE INDEX idx_traces_cluster_id ON traces(cluster_id);
CREATE INDEX idx_traces_trace_id ON traces(trace_id);
CREATE INDEX idx_traces_start_time ON traces(start_time);
CREATE INDEX idx_traces_operation_name ON traces(operation_name);
CREATE INDEX idx_traces_service_name ON traces(service_name);

CREATE INDEX idx_metrics_cluster_id ON metrics(cluster_id);
CREATE INDEX idx_metrics_name_timestamp ON metrics(metric_name, timestamp);
CREATE INDEX idx_metrics_timestamp ON metrics(timestamp);

CREATE INDEX idx_costs_cluster_id ON costs(cluster_id);
CREATE INDEX idx_costs_billing_period ON costs(billing_period_start, billing_period_end);

CREATE INDEX idx_uptime_cluster_id ON uptime_events(cluster_id);
CREATE INDEX idx_uptime_timestamp ON uptime_events(timestamp);

CREATE INDEX idx_commands_cluster_id ON command_executions(cluster_id);
CREATE INDEX idx_commands_start_time ON command_executions(start_time);
CREATE INDEX idx_commands_script_name ON command_executions(script_name);

-- Triggers for updated_at timestamps
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_clusters_updated_at BEFORE UPDATE ON clusters
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_applications_updated_at BEFORE UPDATE ON applications
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Views for common queries
CREATE VIEW cluster_summary AS
SELECT 
    c.id,
    c.name,
    c.environment,
    c.cluster_type,
    c.status,
    c.node_count,
    COUNT(DISTINCT a.id) as app_count,
    COUNT(DISTINCT CASE WHEN a.status = 'running' THEN a.id END) as running_apps,
    COALESCE(SUM(cost.amount), 0) as total_cost_last_30d,
    c.cost_budget,
    c.updated_at
FROM clusters c
LEFT JOIN applications a ON c.id = a.cluster_id
LEFT JOIN costs cost ON c.id = cost.cluster_id 
    AND cost.billing_period_start >= NOW() - INTERVAL '30 days'
GROUP BY c.id, c.name, c.environment, c.cluster_type, c.status, c.node_count, c.cost_budget, c.updated_at;

-- Sample data
INSERT INTO clusters (name, environment, cluster_type, region, node_count, cost_budget) VALUES
('local-dev', 'local', 'local', null, 1, 100),
('staging-aks', 'staging', 'aks', 'eastus', 3, 1000),
('prod-gke', 'production', 'gke', 'us-central1', 5, 5000);

INSERT INTO applications (cluster_id, name, namespace, version, status) 
SELECT c.id, app.name, app.namespace, app.version, 'running'
FROM clusters c,
(VALUES 
    ('crossplane', 'crossplane-system', '1.14.0'),
    ('argocd', 'argocd', '5.46.0'),
    ('prometheus', 'monitoring', '51.0.0'),
    ('loki', 'monitoring', '2.9.10')
) AS app(name, namespace, version)
WHERE c.name IN ('local-dev', 'staging-aks', 'prod-gke');