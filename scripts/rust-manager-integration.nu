#!/usr/bin/env nu

def "main rust start-manager" [
    --config-file: string = "./k8s-manager-rust/config.toml"
    --tui: bool = false
    --api: bool = true
    --background: bool = false
    --data-dir: string = "./data"
    --log-level: string = "info"
] {
    print "🦀 Starting Rust K8s Manager..."
    
    cd k8s-manager-rust
    
    let args = [
        "--config" $config_file
        "--log-level" $log_level
        "--data-dir" $data_dir
    ] ++ (if $tui { ["--tui"] } else { [] })
      ++ (if $api { ["--api"] } else { [] })
    
    if $background {
        print "📡 Starting manager in background..."
        bash -c $"cargo run --bin manager -- ($args | str join ' ') > ../logs/rust-manager.log 2>&1 &"
        sleep 2sec
        print "✅ Rust manager started in background (check logs/rust-manager.log)"
    } else {
        cargo run --bin manager -- ...$args
    }
}

def "main rust tui" [
    --config-file: string = "./k8s-manager-rust/config.toml"
    --log-level: string = "info"
] {
    print "🎛️ Starting Rust K8s Manager TUI..."
    
    cd k8s-manager-rust
    cargo run --bin tui -- --config $config_file --log-level $log_level
}

def "main rust api" [
    --config-file: string = "./k8s-manager-rust/config.toml" 
    --host: string = "0.0.0.0"
    --port: int = 8080
    --log-level: string = "info"
] {
    print "🌐 Starting Rust K8s Manager API..."
    
    cd k8s-manager-rust
    cargo run --bin api -- --config $config_file --host $host --port $port --log-level $log_level
}

def "main rust status" [] {
    print "📊 Rust K8s Manager Status:"
    
    try {
        let health = http get "http://localhost:8080/health"
        print $"  API Status: ✅ ($health.status) - v($health.version)"
        print $"  Last Health Check: ($health.timestamp)"
    } catch {
        print "  API Status: ❌ Not responding"
    }
    
    try {
        let status = http get "http://localhost:8080/status"
        print $"  Connected: ($status.connected)"
        print $"  Resources: ($status.resources_count)"
        print $"  Events: ($status.events_count)"
        if ($status.last_update != null) {
            print $"  Last Update: ($status.last_update)"
        }
    } catch {
        print "  Detailed status unavailable"
    }
    
    if ("./data" | path exists) {
        let data_files = ls ./data | where type == file | length
        print $"  Data Files: ($data_files)"
    }
}

def "main rust query-resources" [
    --namespace: string = ""
    --kind: string = ""
    --state: string = ""
    --limit: int = 50
    --output-format: string = "table"
] {
    print "🔍 Querying resources via Rust API..."
    
    let params = {
        namespace: (if $namespace == "" { null } else { $namespace }),
        kind: (if $kind == "" { null } else { $kind }),
        state: (if $state == "" { null } else { $state }),
        limit: $limit
    } | items { |k, v| if $v != null { $"($k)=($v)" } else { null } } 
      | compact
      | str join "&"
    
    let url = if ($params | is-empty) { 
        "http://localhost:8080/resources"
    } else { 
        $"http://localhost:8080/resources?($params)"
    }
    
    try {
        let response = http get $url
        let resources = $response.resources
        
        match $output_format {
            "json" => { $resources | to json }
            "csv" => {
                $resources 
                | each { |r| {
                    name: $r.resource.name,
                    kind: $r.resource.kind,
                    namespace: ($r.resource.namespace | default "default"),
                    state: $r.current_state,
                    age: (format_age $r.last_updated),
                    events: $r.event_count
                }}
                | to csv
            }
            "table" => {
                $resources 
                | each { |r| {
                    name: $r.resource.name,
                    kind: $r.resource.kind,
                    namespace: ($r.resource.namespace | default "default"),
                    state: $r.current_state,
                    age: (format_age $r.last_updated),
                    events: $r.event_count
                }}
            }
            _ => { $resources }
        }
    } catch {
        error make { msg: "Failed to query resources. Is the API server running?" }
    }
}

def "main rust get-events" [
    --limit: int = 100
    --since: string = ""
    --severity: string = ""
    --output-format: string = "table"
] {
    print "📝 Getting events via Rust API..."
    
    let params = {
        limit: $limit,
        since: (if $since == "" { null } else { $since }),
        severity: (if $severity == "" { null } else { $severity })
    } | items { |k, v| if $v != null { $"($k)=($v)" } else { null } }
      | compact
      | str join "&"
    
    let url = if ($params | is-empty) {
        "http://localhost:8080/events"
    } else {
        $"http://localhost:8080/events?($params)"
    }
    
    try {
        let response = http get $url
        let events = $response.events
        
        match $output_format {
            "json" => { $events | to json }
            "table" => {
                $events
                | each { |e| {
                    timestamp: ($e.timestamp | into datetime | format date '%H:%M:%S'),
                    severity: (format_severity $e.event_type.severity),
                    resource: $"($e.resource.kind)/($e.resource.name)",
                    namespace: ($e.resource.namespace | default "default"),
                    state: $"($e.previous_state | default 'None') → ($e.current_state)",
                    message: ($e.message | default "")
                }}
            }
            _ => { $events }
        }
    } catch {
        error make { msg: "Failed to get events. Is the API server running?" }
    }
}

def "main rust analyze-health" [
    --save-report: bool = false
    --output-file: string = ""
] {
    print "📊 Analyzing cluster health via Rust API..."
    
    try {
        let analysis = http get "http://localhost:8080/analysis/health"
        
        print $"🔍 Health Analysis Results:"
        print $"  Timestamp: ($analysis.timestamp)"
        print $"  Insights Found: ($analysis.insights | length)"
        print ""
        
        for insight in $analysis.insights {
            let severity_icon = match $insight.severity {
                "critical" => "🚨",
                "warning" => "⚠️",
                "error" => "❌",
                _ => "ℹ️"
            }
            
            print $"($severity_icon) ($insight.insight_type | str upcase): ($insight.message)"
            if ($insight.recommendation != null) {
                print $"   💡 Recommendation: ($insight.recommendation)"
            }
            print ""
        }
        
        if $save_report {
            let filename = if ($output_file != "") {
                $output_file
            } else {
                $"health-analysis-(date now | format date '%Y%m%d-%H%M%S').json"
            }
            
            $analysis | to json | save $filename
            print $"📄 Report saved to: ($filename)"
        }
        
        $analysis
    } catch {
        error make { msg: "Failed to analyze health. Is the API server running?" }
    }
}

def "main rust analyze-trends" [
    --save-report: bool = false
    --output-file: string = ""
] {
    print "📈 Analyzing resource trends via Rust API..."
    
    try {
        let analysis = http get "http://localhost:8080/analysis/trends"
        
        print $"📊 Trend Analysis Results:"
        print $"  Timestamp: ($analysis.timestamp)"
        print $"  Insights Found: ($analysis.insights | length)"
        
        for insight in $analysis.insights {
            print $"• ($insight.message)"
        }
        
        if $save_report {
            let filename = if ($output_file != "") {
                $output_file
            } else {
                $"trend-analysis-(date now | format date '%Y%m%d-%H%M%S').json"
            }
            
            $analysis | to json | save $filename
            print $"📄 Report saved to: ($filename)"
        }
        
        $analysis
    } catch {
        error make { msg: "Failed to analyze trends. Is the API server running?" }
    }
}

def "main rust get-metrics" [] {
    print "📊 Getting cluster metrics via Rust API..."
    
    try {
        let metrics = http get "http://localhost:8080/metrics"
        
        print $"🎛️ Cluster Metrics:"
        print $"  Total Resources: ($metrics.total_resources)"
        print $"  Healthy: ($metrics.healthy_resources) ✅"
        print $"  Unhealthy: ($metrics.unhealthy_resources) ❌"
        print $"  Unknown: ($metrics.unknown_resources) ❓"
        print $"  Total Events: ($metrics.total_events)"
        print $"  Events (Last Hour): ($metrics.events_last_hour)"
        print $"  Last Updated: ($metrics.last_updated)"
        
        $metrics
    } catch {
        error make { msg: "Failed to get metrics. Is the API server running?" }
    }
}

def "main rust export-state" [
    output_file: string = ""
] {
    print "💾 Exporting cluster state via Rust API..."
    
    try {
        let state = http get "http://localhost:8080/state/export"
        
        let filename = if ($output_file != "") {
            $output_file
        } else {
            $"cluster-state-(date now | format date '%Y%m%d-%H%M%S').json"
        }
        
        $state | to json | save $filename
        print $"✅ State exported to: ($filename)"
        
        $state
    } catch {
        error make { msg: "Failed to export state. Is the API server running?" }
    }
}

def "main rust clear-events" [] {
    print "🗑️ Clearing event history via Rust API..."
    
    try {
        http delete "http://localhost:8080/events"
        print "✅ Event history cleared"
    } catch {
        error make { msg: "Failed to clear events. Is the API server running?" }
    }
}

def "main rust compliance-report" [
    --save-report: bool = false
    --output-file: string = ""
] {
    print "📋 Generating compliance report via Rust API..."
    
    try {
        let report = http get "http://localhost:8080/analysis/compliance"
        
        print $"📋 Compliance Report:"
        print $"  Timestamp: ($report.timestamp)"
        print $"  Issues Found: ($report.insights | length)"
        print ""
        
        for insight in $report.insights {
            let severity_icon = match $insight.severity {
                "critical" => "🚨",
                "warning" => "⚠️",
                "error" => "❌",
                _ => "ℹ️"
            }
            
            print $"($severity_icon) ($insight.message)"
            if ($insight.recommendation != null) {
                print $"   💡 ($insight.recommendation)"
            }
        }
        
        if $save_report {
            let filename = if ($output_file != "") {
                $output_file
            } else {
                $"compliance-report-(date now | format date '%Y%m%d-%H%M%S').json"
            }
            
            $report | to json | save $filename
            print $"📄 Report saved to: ($filename)"
        }
        
        $report
    } catch {
        error make { msg: "Failed to generate compliance report. Is the API server running?" }
    }
}

def "main rust build" [
    --release: bool = false
] {
    print "🔨 Building Rust K8s Manager..."
    
    cd k8s-manager-rust
    
    if $release {
        print "🚀 Building release version..."
        cargo build --release
    } else {
        print "🛠️ Building debug version..."
        cargo build
    }
    
    print "✅ Build complete"
}

def "main rust test" [] {
    print "🧪 Running Rust tests..."
    
    cd k8s-manager-rust
    cargo test
}

def "main rust ws-client" [
    --url: string = "ws://localhost:8080/ws"
    --subscribe-namespaces: list<string> = []
    --subscribe-types: list<string> = []
] {
    print $"📡 Connecting to WebSocket: ($url)"
    
    let subscription = {
        type: "subscribe",
        data: {
            namespaces: $subscribe_namespaces,
            resource_types: $subscribe_types
        }
    } | to json
    
    print "Use websocat to connect (install: cargo install websocat)"
    print $"websocat ($url)"
    print $"Then send: ($subscription)"
}

def format_age [timestamp: string] {
    let now = date now
    let age = $now - ($timestamp | into datetime)
    
    let total_seconds = $age | format duration | split row ":" | get 2 | into int
    
    if $total_seconds < 60 {
        $"($total_seconds)s"
    } else if $total_seconds < 3600 {
        $"($total_seconds / 60)m"
    } else if $total_seconds < 86400 {
        $"($total_seconds / 3600)h"
    } else {
        $"($total_seconds / 86400)d"
    }
}

def format_severity [severity: string] {
    match $severity {
        "critical" => "🚨 CRITICAL",
        "error" => "❌ ERROR",
        "warning" => "⚠️ WARNING",
        "info" => "ℹ️ INFO",
        _ => $"📝 ($severity)"
    }
}

def "main rust help" [] {
    print "🦀 Rust K8s Manager Integration Commands:"
    print ""
    print "🚀 Management:"
    print "  start-manager              - Start the complete manager (TUI + API)"
    print "  tui                        - Start TUI only"
    print "  api                        - Start API server only"
    print "  status                     - Check manager status"
    print ""
    print "🔍 Querying & Analysis:"
    print "  query-resources            - Query resources via API"
    print "  get-events                 - Get events via API"
    print "  analyze-health             - Run health analysis"
    print "  analyze-trends             - Run trend analysis"
    print "  compliance-report          - Generate compliance report"
    print "  get-metrics                - Get cluster metrics"
    print ""
    print "💾 Data Management:"
    print "  export-state               - Export current cluster state"
    print "  clear-events               - Clear event history"
    print ""
    print "🛠️ Development:"
    print "  build                      - Build the Rust application"
    print "  test                       - Run Rust tests"
    print ""
    print "📡 WebSocket:"
    print "  ws-client                  - Connect to WebSocket for real-time updates"
    print ""
    print "⚙️ Options:"
    print "  --namespace <name>         - Filter by namespace"
    print "  --kind <type>             - Filter by resource kind"
    print "  --state <state>           - Filter by resource state"
    print "  --severity <level>        - Filter by event severity"
    print "  --background              - Run in background mode"
    print "  --save-report             - Save analysis results"
    print "  --release                 - Build release version"
    print ""
    print "🌐 API Endpoints:"
    print "  Health: http://localhost:8080/health"
    print "  Status: http://localhost:8080/status"
    print "  Resources: http://localhost:8080/resources"
    print "  Events: http://localhost:8080/events"
    print "  WebSocket: ws://localhost:8080/ws"
}