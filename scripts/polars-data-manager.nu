#!/usr/bin/env nu

use polars as pl

def "main polars k8s-resources" [
    --namespace: string = ""
    --resource-type: string = "all"
    --output-format: string = "json"
] {
    let resources = match $resource_type {
        "pods" => { kubectl get pods -o json | from json }
        "services" => { kubectl get services -o json | from json }
        "deployments" => { kubectl get deployments -o json | from json }
        "configmaps" => { kubectl get configmaps -o json | from json }
        "secrets" => { kubectl get secrets -o json | from json }
        "all" => { 
            let pods = kubectl get pods -o json | from json
            let services = kubectl get services -o json | from json
            let deployments = kubectl get deployments -o json | from json
            $pods | merge $services | merge $deployments
        }
        _ => { error make { msg: $"Unsupported resource type: ($resource_type)" } }
    }
    
    let df = $resources.items 
        | each { |item| 
            {
                name: $item.metadata.name,
                namespace: $item.metadata.namespace,
                kind: $item.kind,
                status: ($item | get status? | default "unknown"),
                created: $item.metadata.creationTimestamp,
                labels: ($item.metadata.labels? | default {} | to json),
                annotations: ($item.metadata.annotations? | default {} | to json)
            }
        }
        | into df
    
    match $output_format {
        "json" => { $df | to json }
        "csv" => { $df | to csv }
        "parquet" => { $df | to parquet "k8s-resources.parquet"; "Data saved to k8s-resources.parquet" }
        "table" => { $df }
        _ => { $df }
    }
}

def "main polars analyze-resource-health" [
    --window: string = "1h"
    --namespace: string = ""
] {
    let events = kubectl get events --sort-by=.metadata.creationTimestamp -o json | from json
    
    let df = $events.items
        | each { |event|
            {
                timestamp: $event.metadata.creationTimestamp,
                namespace: $event.metadata.namespace,
                kind: $event.involvedObject.kind,
                name: $event.involvedObject.name,
                reason: $event.reason,
                message: $event.message,
                type: $event.type,
                count: $event.count
            }
        }
        | into df
        | pl col timestamp | str.to_datetime "%Y-%m-%dT%H:%M:%SZ"
    
    let health_summary = $df 
        | group_by [namespace, kind, name]
        | summarize [
            (pl col count | sum | alias "total_events"),
            (pl col type | filter (pl col type | str.contains "Warning") | len | alias "warning_count"),
            (pl col type | filter (pl col type | str.contains "Normal") | len | alias "normal_count"),
            (pl col timestamp | max | alias "last_event")
        ]
        | with_columns [
            ((pl col warning_count) / (pl col total_events) * 100 | alias "warning_percentage")
        ]
        | sort warning_percentage --descending
    
    $health_summary
}

def "main polars resource-usage-trends" [
    --namespace: string = ""
    --duration: string = "24h"
] {
    print "📊 Collecting resource usage metrics..."
    
    let metrics_query = $'sum by (pod, namespace) (rate(container_cpu_usage_seconds_total{{namespace=~"($namespace).*"}}[5m]))'
    let cpu_metrics = curl -s $"http://prometheus:9090/api/v1/query?query=($metrics_query)" | from json
    
    let memory_query = $'sum by (pod, namespace) (container_memory_usage_bytes{{namespace=~"($namespace).*"}})'
    let memory_metrics = curl -s $"http://prometheus:9090/api/v1/query?query=($memory_query)" | from json
    
    let cpu_df = $cpu_metrics.data.result
        | each { |metric|
            {
                pod: $metric.metric.pod,
                namespace: $metric.metric.namespace,
                cpu_usage: ($metric.value.1 | into float),
                timestamp: (date now)
            }
        }
        | into df
    
    let memory_df = $memory_metrics.data.result
        | each { |metric|
            {
                pod: $metric.metric.pod,
                namespace: $metric.metric.namespace,
                memory_usage: ($metric.value.1 | into int),
                timestamp: (date now)
            }
        }
        | into df
    
    let combined_df = $cpu_df 
        | join $memory_df [pod, namespace] "inner"
        | with_columns [
            (pl col memory_usage / 1024 / 1024 | alias "memory_mb")
        ]
    
    $combined_df
}

def "main polars config-drift-detection" [
    baseline_file: string
    --namespace: string = "default"
] {
    if not ($baseline_file | path exists) {
        error make { msg: $"Baseline file not found: ($baseline_file)" }
    }
    
    print "🔍 Detecting configuration drift..."
    
    let baseline = open $baseline_file | from json | into df
    let current = main polars k8s-resources --namespace $namespace --resource-type "all" --output-format "json" | from json | into df
    
    let drift_analysis = $baseline
        | join $current [name, namespace] "outer"
        | with_columns [
            (when (pl col labels != pl col labels_right) 
                .then (lit "labels_changed")
                .when (pl col status != pl col status_right)
                .then (lit "status_changed") 
                .when (pl col created != pl col created_right)
                .then (lit "recreated")
                .otherwise (lit "no_change")
                | alias "drift_type")
        ]
        | filter (pl col drift_type | str.contains "changed|recreated")
    
    $drift_analysis
}

def "main polars secret-rotation-tracker" [
    --namespace: string = "default"
    --days-threshold: int = 30
] {
    let secrets = kubectl get secrets -n $namespace -o json | from json
    
    let df = $secrets.items
        | each { |secret|
            {
                name: $secret.metadata.name,
                namespace: $secret.metadata.namespace,
                type: $secret.type,
                created: $secret.metadata.creationTimestamp,
                data_keys: ($secret.data | columns | str join ","),
                age_days: ((date now) - ($secret.metadata.creationTimestamp | into datetime) | format duration | split row "days" | first | into int)
            }
        }
        | into df
        | filter (pl col age_days > $days_threshold)
        | sort age_days --descending
    
    print $"🔐 Found (($df | length)) secrets older than ($days_threshold) days"
    $df
}

def "main polars generate-compliance-report" [
    --namespace: string = "default"
    --output-file: string = "compliance-report.json"
] {
    print "📋 Generating compliance report..."
    
    let pods_df = main polars k8s-resources --namespace $namespace --resource-type "pods" --output-format "json" | from json | into df
    let secrets_df = main polars secret-rotation-tracker --namespace $namespace
    let events_df = main polars analyze-resource-health --namespace $namespace
    
    let compliance_data = {
        timestamp: (date now),
        namespace: $namespace,
        pod_count: ($pods_df | length),
        secret_count: ($secrets_df | length),
        warning_events: ($events_df | get warning_count | math sum),
        high_risk_pods: ($pods_df | filter (get status | str contains "Failed|Error") | length),
        old_secrets: ($secrets_df | length)
    }
    
    $compliance_data | to json | save $output_file
    print $"✅ Compliance report saved to ($output_file)"
}

def "main polars create-dashboard-data" [
    --namespace: string = "default"
    --output-dir: string = "./dashboard-data"
] {
    print "📊 Creating dashboard data files..."
    
    mkdir $output_dir
    
    let resources = main polars k8s-resources --namespace $namespace
    let health = main polars analyze-resource-health --namespace $namespace  
    let usage = main polars resource-usage-trends --namespace $namespace
    let secrets = main polars secret-rotation-tracker --namespace $namespace
    
    $resources | to json | save $"($output_dir)/resources.json"
    $health | to json | save $"($output_dir)/health.json"
    $usage | to json | save $"($output_dir)/usage.json"
    $secrets | to json | save $"($output_dir)/secrets.json"
    
    let summary = {
        last_updated: (date now),
        total_resources: ($resources | length),
        warning_percentage: ($health | get warning_percentage | math avg),
        avg_cpu_usage: ($usage | get cpu_usage | math avg),
        old_secrets_count: ($secrets | length)
    }
    
    $summary | to json | save $"($output_dir)/summary.json"
    
    print $"✅ Dashboard data saved to ($output_dir)/"
}

def "main polars help" [] {
    print "🐻‍❄️ Polars-Enhanced Data Management Commands:"
    print ""
    print "📊 Resource Analysis:"
    print "  k8s-resources              - Collect and analyze Kubernetes resources"
    print "  analyze-resource-health    - Health analysis with event correlation"
    print "  resource-usage-trends      - CPU/Memory usage trends from Prometheus"
    print "  config-drift-detection     - Compare current vs baseline configuration"
    print ""
    print "🔐 Security & Compliance:"
    print "  secret-rotation-tracker    - Track secret age and rotation needs"
    print "  generate-compliance-report - Generate compliance summary"
    print ""
    print "📈 Dashboard & Reporting:"
    print "  create-dashboard-data      - Generate data for monitoring dashboards"
    print ""
    print "⚙️  Options:"
    print "  --namespace <name>         - Target namespace filter"
    print "  --output-format <format>   - Output format (json|csv|parquet|table)"
    print "  --window <duration>        - Time window for analysis"
    print "  --days-threshold <days>    - Age threshold for alerts"
}