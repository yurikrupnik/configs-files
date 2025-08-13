// InfluxDB Flux schema for time series traces and metrics

// Create buckets for different data types
// Run these commands in InfluxDB CLI or UI

// Traces bucket - for OpenTelemetry traces
// influx bucket create --name traces --retention 30d --org myorg

// Metrics bucket - for cluster metrics  
// influx bucket create --name metrics --retention 90d --org myorg

// Logs bucket - for application logs
// influx bucket create --name logs --retention 7d --org myorg

// Cost bucket - for cost tracking
// influx bucket create --name costs --retention 365d --org myorg

// Sample data structure for traces
/*
Trace data points:
_measurement: "traces"
_field: "duration_ms" | "status_code" | "error_count"
tags:
  - cluster_id: string
  - cluster_name: string  
  - environment: "local" | "staging" | "production"
  - service_name: string
  - operation_name: string
  - trace_id: string
  - span_id: string
  - parent_span_id: string (optional)
  - status: "success" | "error" | "timeout"
  - user_id: string (optional)
*/

// Sample data structure for metrics
/*
Cluster metrics:
_measurement: "cluster_metrics"
_field: "cpu_usage" | "memory_usage" | "disk_usage" | "network_io"
tags:
  - cluster_id: string
  - cluster_name: string
  - environment: string
  - node_name: string
  - metric_type: "gauge" | "counter"

Application metrics:
_measurement: "app_metrics"  
_field: "request_count" | "response_time" | "error_rate"
tags:
  - cluster_id: string
  - app_name: string
  - namespace: string
  - version: string
  - endpoint: string (optional)
*/

// Sample data structure for costs
/*
Cost data:
_measurement: "costs"
_field: "amount"
tags:
  - cluster_id: string
  - cluster_name: string
  - environment: string
  - cost_type: "compute" | "storage" | "network" | "total"
  - currency: "USD" | "EUR" | etc
  - provider: "aws" | "azure" | "gcp" | "local"
  - billing_period: "2024-01"
*/

// Common queries

// Get average response time by service in last hour
avg_response_time = from(bucket: "traces")
  |> range(start: -1h)
  |> filter(fn: (r) => r._measurement == "traces")
  |> filter(fn: (r) => r._field == "duration_ms")
  |> group(columns: ["service_name"])
  |> mean()

// Get error rate by cluster in last 24h
error_rate = from(bucket: "traces")
  |> range(start: -24h)
  |> filter(fn: (r) => r._measurement == "traces")
  |> filter(fn: (r) => r._field == "status_code")
  |> group(columns: ["cluster_name"])
  |> map(fn: (r) => ({
      _time: r._time,
      cluster_name: r.cluster_name,
      is_error: if r._value >= 400 then 1.0 else 0.0
    }))
  |> aggregateWindow(every: 1h, fn: mean, column: "is_error")

// Get cluster resource utilization
cluster_resources = from(bucket: "metrics")
  |> range(start: -1h)
  |> filter(fn: (r) => r._measurement == "cluster_metrics")
  |> filter(fn: (r) => r._field == "cpu_usage" or r._field == "memory_usage")
  |> group(columns: ["cluster_name", "_field"])
  |> aggregateWindow(every: 5m, fn: mean)

// Get daily costs by environment
daily_costs = from(bucket: "costs")
  |> range(start: -30d)
  |> filter(fn: (r) => r._measurement == "costs")
  |> filter(fn: (r) => r._field == "amount")
  |> group(columns: ["environment"])
  |> aggregateWindow(every: 1d, fn: sum)

// Get uptime percentage by cluster
uptime_percentage = from(bucket: "traces")
  |> range(start: -7d)
  |> filter(fn: (r) => r._measurement == "uptime_checks")
  |> filter(fn: (r) => r._field == "status")
  |> group(columns: ["cluster_name"])
  |> map(fn: (r) => ({
      _time: r._time,
      cluster_name: r.cluster_name,
      is_up: if r._value == "up" then 1.0 else 0.0
    }))
  |> aggregateWindow(every: 1h, fn: mean, column: "is_up")
  |> map(fn: (r) => ({
      _time: r._time,
      cluster_name: r.cluster_name,
      uptime_percent: r.is_up * 100.0
    }))