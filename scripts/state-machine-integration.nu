#!/usr/bin/env nu

def "main state start-manager" [
    --config-file: string = "./k8s-state-manager/config.json"
    --background: bool = false
] {
    print "🚀 Starting K8s State Manager..."
    
    let config = if ($config_file | path exists) {
        open $config_file
    } else {
        {
            watcher: {
                namespaces: ["default", "kube-system"],
                resourceTypes: ["pods", "services", "deployments", "configmaps", "secrets"],
                reconnectInterval: 5000
            },
            emitter: {
                websocketPort: 8080,
                enableMetrics: true,
                filterCriteria: {
                    criticality: "medium"
                }
            },
            polars: {
                dataDir: "./data",
                retentionDays: 7,
                analysisInterval: 300
            }
        }
    }
    
    $config | to json | save $config_file
    
    cd k8s-state-manager
    
    if $background {
        print "📡 Starting state manager in background..."
        bash -c "bun run src/index.ts > ../logs/state-manager.log 2>&1 &"
        sleep 2sec
        print "✅ State manager started in background (check logs/state-manager.log)"
    } else {
        bun run src/index.ts
    }
}

def "main state status" [] {
    print "📊 K8s State Manager Status:"
    
    try {
        let ws_response = curl -s "http://localhost:8080/health" | from json
        print $"  Connection: ✅ Connected"
        print $"  WebSocket clients: ($ws_response.clients)"
        print $"  Resources tracked: ($ws_response.resources)"
    } catch {
        print "  Connection: ❌ Disconnected"
    }
    
    if ("./data" | path exists) {
        let data_files = ls ./data | length
        print $"  Data files: ($data_files)"
        
        let latest_summary = ls ./data/summary-*.json 
            | sort-by modified 
            | last 
            | get name?
        
        if ($latest_summary | is-not-empty) {
            let summary = open $latest_summary
            print $"  Last analysis: ($summary.timestamp)"
            print $"  Resource health: ($summary.health.healthy)✅ ($summary.health.unhealthy)❌ ($summary.health.unknown)❓"
        }
    }
}

def "main state query-resources" [
    --namespace: string = ""
    --kind: string = ""
    --state: string = ""
    --output-format: string = "table"
] {
    print "🔍 Querying K8s resources..."
    
    # Use the polars data manager to query resources
    let resources = nu scripts/polars-data-manager.nu polars k8s-resources 
        --namespace $namespace 
        --resource-type (if $kind == "" { "all" } else { $kind })
        --output-format "json"
    
    let filtered = $resources
        | from json
        | if ($state != "") { where status == $state } else { $in }
        | if ($namespace != "") { where namespace == $namespace } else { $in }
        | if ($kind != "") { where kind == $kind } else { $in }
    
    match $output_format {
        "json" => { $filtered | to json }
        "csv" => { $filtered | to csv }
        "table" => { $filtered }
        _ => { $filtered }
    }
}

def "main state analyze-trends" [
    --window: string = "1h"
    --namespace: string = ""
    --save-report: bool = false
] {
    print $"📈 Analyzing resource trends for window: ($window)"
    
    let health_analysis = nu scripts/polars-data-manager.nu polars analyze-resource-health 
        --window $window 
        --namespace $namespace
    
    let usage_trends = nu scripts/polars-data-manager.nu polars resource-usage-trends
        --namespace $namespace
        --duration $window
    
    let analysis_report = {
        timestamp: (date now),
        window: $window,
        namespace: $namespace,
        health_summary: $health_analysis,
        usage_trends: $usage_trends,
        insights: (generate_insights $health_analysis $usage_trends)
    }
    
    if $save_report {
        let report_file = $"analysis-report-(date now | format date '%Y%m%d-%H%M%S').json"
        $analysis_report | to json | save $report_file
        print $"📄 Report saved to: ($report_file)"
    }
    
    $analysis_report
}

def generate_insights [health_data usage_data] {
    let insights = []
    
    # Check for high warning rates
    let high_warning_resources = $health_data 
        | where warning_percentage > 50
        | length
    
    if $high_warning_resources > 0 {
        $insights = ($insights | append {
            type: "warning",
            message: $"($high_warning_resources) resources have high warning rates (>50%)",
            severity: "medium",
            action: "Investigate resource issues and review logs"
        })
    }
    
    # Check for resource usage spikes
    let high_cpu_pods = $usage_data 
        | where cpu_usage > 0.8
        | length
    
    if $high_cpu_pods > 0 {
        $insights = ($insights | append {
            type: "performance",
            message: $"($high_cpu_pods) pods have high CPU usage (>80%)",
            severity: "high", 
            action: "Consider scaling or optimizing high CPU pods"
        })
    }
    
    $insights
}

def "main state watch-events" [
    --filter-severity: string = "warning"
    --resource-type: string = ""
    --namespace: string = ""
] {
    print $"👀 Watching K8s events (filter: ($filter_severity))..."
    
    # Connect to WebSocket for real-time events
    let ws_command = $"websocat ws://localhost:8080/k8s-events"
    
    print "📡 Connecting to event stream..."
    print "Use Ctrl+C to stop watching"
    print "---"
    
    bash -c $ws_command | lines | each { |line|
        try {
            let event = $line | from json
            
            if $event.type == "event" {
                let event_data = $event.data
                
                # Apply filters
                let should_display = (
                    ($filter_severity == "" or $event_data.severity == $filter_severity) and
                    ($resource_type == "" or $event_data.resource.kind == $resource_type) and
                    ($namespace == "" or $event_data.resource.namespace == $namespace)
                )
                
                if $should_display {
                    let severity_icon = match $event_data.severity {
                        "info" => "ℹ️",
                        "warning" => "⚠️",
                        "error" => "❌",
                        "critical" => "🚨",
                        _ => "📝"
                    }
                    
                    let timestamp = $event_data.timestamp | into datetime | format date '%H:%M:%S'
                    print $"($timestamp) ($severity_icon) ($event_data.resource.kind)/($event_data.resource.name) - ($event_data.type)"
                    
                    if $event_data.payload.previousState? != null {
                        print $"  State: ($event_data.payload.previousState) → ($event_data.payload.currentState)"
                    }
                }
            }
        } catch {
            # Skip invalid JSON lines
        }
    }
}

def "main state emit-custom-event" [
    event_type: string
    message: string
    --severity: string = "info"
    --resource-name: string = ""
    --resource-kind: string = ""
    --namespace: string = "default"
] {
    let event = {
        id: $"custom_(random uuid)",
        timestamp: (date now | to text),
        type: $event_type,
        severity: $severity,
        resource: (if $resource_name != "" {
            {
                kind: $resource_kind,
                name: $resource_name,
                namespace: $namespace
            }
        } else { null }),
        payload: {
            message: $message,
            source: "nu-script"
        },
        metadata: {
            source: "custom-event",
            cluster: (kubectl config current-context)
        }
    }
    
    # Send to state manager via webhook or file
    $event | to json | save $"./data/custom-events-(date now | format date '%Y%m%d').jsonl" --append
    
    print $"📤 Custom event emitted: ($event_type) - ($message)"
}

def "main state create-dashboard" [
    output_dir: string = "./dashboard"
    --refresh-interval: int = 30
] {
    print "📊 Creating K8s state dashboard..."
    
    mkdir $output_dir
    
    # Generate dashboard data
    nu scripts/polars-data-manager.nu polars create-dashboard-data --output-dir $output_dir
    
    # Create HTML dashboard
    let dashboard_html = $"
<!DOCTYPE html>
<html>
<head>
    <title>K8s State Dashboard</title>
    <meta charset='utf-8'>
    <meta http-equiv='refresh' content='($refresh_interval)'>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; }
        .card { background: white; padding: 20px; margin: 10px 0; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .metric { display: inline-block; margin: 10px 20px; text-align: center; }
        .metric-value { font-size: 2em; font-weight: bold; }
        .metric-label { font-size: 0.9em; color: #666; }
        .healthy { color: #28a745; }
        .warning { color: #ffc107; }
        .error { color: #dc3545; }
        .resource-list { max-height: 300px; overflow-y: auto; }
        table { width: 100%; border-collapse: collapse; }
        th, td { padding: 8px; text-align: left; border-bottom: 1px solid #ddd; }
    </style>
</head>
<body>
    <div class='container'>
        <h1>🎛️ K8s State Dashboard</h1>
        <p>Last updated: <span id='timestamp'></span></p>
        
        <div class='card'>
            <h2>📊 Resource Health</h2>
            <div id='health-metrics'></div>
        </div>
        
        <div class='card'>
            <h2>📋 Resources</h2>
            <div id='resources-table'></div>
        </div>
        
        <div class='card'>
            <h2>📈 Recent Events</h2>
            <div id='events-list'></div>
        </div>
    </div>
    
    <script>
        async function loadDashboardData() {
            try {
                const summary = await fetch('./summary.json').then(r => r.json());
                const resources = await fetch('./resources.json').then(r => r.json());
                const health = await fetch('./health.json').then(r => r.json());
                
                document.getElementById('timestamp').textContent = new Date().toLocaleString();
                
                // Health metrics
                const healthHtml = `
                    <div class='metric'>
                        <div class='metric-value healthy'>\${summary.total_resources || 0}</div>
                        <div class='metric-label'>Total Resources</div>
                    </div>
                    <div class='metric'>
                        <div class='metric-value healthy'>\${(summary.warning_percentage || 0).toFixed(1)}%</div>
                        <div class='metric-label'>Warning Rate</div>
                    </div>
                    <div class='metric'>
                        <div class='metric-value'>\${summary.avg_cpu_usage || 0}</div>
                        <div class='metric-label'>Avg CPU Usage</div>
                    </div>
                `;
                document.getElementById('health-metrics').innerHTML = healthHtml;
                
                // Resources table
                let resourcesHtml = '<table><tr><th>Name</th><th>Kind</th><th>Namespace</th><th>Status</th></tr>';
                (resources || []).slice(0, 20).forEach(resource => {
                    resourcesHtml += `<tr>
                        <td>\${resource.name}</td>
                        <td>\${resource.kind}</td>
                        <td>\${resource.namespace}</td>
                        <td>\${resource.status}</td>
                    </tr>`;
                });
                resourcesHtml += '</table>';
                document.getElementById('resources-table').innerHTML = resourcesHtml;
                
            } catch (error) {
                console.error('Failed to load dashboard data:', error);
            }
        }
        
        // WebSocket connection for real-time updates
        try {
            const ws = new WebSocket('ws://localhost:8080/k8s-events');
            ws.onmessage = function(event) {
                const data = JSON.parse(event.data);
                if (data.type === 'event') {
                    console.log('Real-time event:', data.data);
                }
            };
        } catch (error) {
            console.log('WebSocket not available, using polling');
        }
        
        loadDashboardData();
        setInterval(loadDashboardData, ($refresh_interval * 1000));
    </script>
</body>
</html>
"
    
    $dashboard_html | save $"($output_dir)/index.html"
    
    print $"✅ Dashboard created at: ($output_dir)/index.html"
    print $"🌐 Open: file://($env.PWD)/($output_dir)/index.html"
}

def "main state backup-data" [
    backup_path: string = "./backups"
    --include-state: bool = true
    --include-events: bool = true  
    --compress: bool = true
] {
    print "💾 Backing up K8s state data..."
    
    mkdir $backup_path
    let timestamp = date now | format date '%Y%m%d-%H%M%S'
    let backup_dir = $"($backup_path)/state-backup-($timestamp)"
    mkdir $backup_dir
    
    if $include_state {
        # Export current state from state machine
        try {
            curl -s "http://localhost:8080/export" | from json | to json | save $"($backup_dir)/state.json"
            print "  ✅ State data backed up"
        } catch {
            print "  ⚠️  Could not backup live state (state manager not running)"
        }
    }
    
    if $include_events and ("./data" | path exists) {
        # Copy event data files  
        cp -r ./data $"($backup_dir)/data"
        print "  ✅ Event data backed up"
    }
    
    # Backup configuration
    if ("./k8s-state-manager/config.json" | path exists) {
        cp ./k8s-state-manager/config.json $"($backup_dir)/config.json"
    }
    
    if $compress {
        cd $backup_path
        tar czf $"state-backup-($timestamp).tar.gz" $"state-backup-($timestamp)"
        rm -rf $"state-backup-($timestamp)"
        print $"  🗜️  Backup compressed to: ($backup_path)/state-backup-($timestamp).tar.gz"
    }
    
    print $"✅ Backup completed: ($backup_dir)"
}

def "main state help" [] {
    print "🎛️ K8s State Machine Integration Commands:"
    print ""
    print "🚀 Management:"
    print "  start-manager              - Start the K8s state manager"
    print "  status                     - Show state manager status"
    print "  backup-data                - Backup state and event data"
    print ""
    print "🔍 Querying & Analysis:"
    print "  query-resources            - Query resources with filters"
    print "  analyze-trends             - Analyze resource trends and health"
    print "  watch-events               - Watch real-time K8s events"
    print ""
    print "📊 Visualization:"
    print "  create-dashboard           - Generate HTML dashboard"
    print ""
    print "🔧 Custom Events:"
    print "  emit-custom-event          - Emit custom events to the system"
    print ""
    print "⚙️ Options:"
    print "  --namespace <name>         - Filter by namespace"
    print "  --kind <type>             - Filter by resource kind"
    print "  --state <state>           - Filter by resource state"
    print "  --severity <level>        - Filter by event severity"
    print "  --background              - Run in background mode"
    print "  --save-report             - Save analysis results"
    print ""
    print "🌐 WebSocket endpoint: ws://localhost:8080/k8s-events"
    print "📊 Dashboard: Create with 'create-dashboard' command"
}