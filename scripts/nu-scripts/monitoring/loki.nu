# Loki logging stack management commands for Nu shell
# Provides functions to install, manage, and monitor Loki

use tracer.nu *

# Install Loki using Helm chart
def "loki install" [
    --namespace(-n): string = "loki-system"
    --version(-v): string = "6.29.1"
    --values(-f): string
    --storage-class(-s): string = "standard"
    --retention(-r): string = "336h"
] {
    trace-command $"loki install --namespace=($namespace)" {
        print $"🚀 Installing Loki in namespace: ($namespace)"
        
        # Create namespace if it doesn't exist
        let ns_exists = (kubectl get namespace $namespace | complete | get exit_code) == 0
        if not $ns_exists {
            print $"📦 Creating namespace: ($namespace)"
            kubectl create namespace $namespace
        }
        
        # Add Grafana Helm repository
        print "📋 Adding Grafana Helm repository"
        helm repo add grafana https://grafana.github.io/helm-charts
        helm repo update
        
        # Prepare Loki values
        let loki_values = if ($values | is-empty) {
            $"
deploymentMode: SingleBinary
loki:
  auth_enabled: false
  commonConfig:
    replication_factor: 1
  storage:
    type: 'filesystem'
  schemaConfig:
    configs:
    - from: \"2024-01-01\"
      store: tsdb
      index:
        prefix: loki_index_
        period: 24h
      object_store: filesystem
      schema: v13
  limits_config:
    retention_period: ($retention)
    
singleBinary:
  replicas: 1
  persistence:
    enabled: true
    storageClass: ($storage_class)
    size: 10Gi
    
read:
  replicas: 0
write:
  replicas: 0
backend:
  replicas: 0
  
test:
  enabled: false
lokiCanary:
  enabled: false
gateway:
  enabled: false
"
        } else {
            open $values
        }
        
        # Write values to temporary file
        let values_file = "/tmp/loki-values.yaml"
        $loki_values | save -f $values_file
        
        # Install Loki
        print $"🔧 Installing Loki version ($version)"
        helm upgrade --install loki grafana/loki --version $version --namespace $namespace --values $values_file --wait --timeout 10m
        
        # Clean up temporary file
        rm $values_file
        
        print "✅ Loki installation completed"
    }
}

# Uninstall Loki
def "loki uninstall" [
    --namespace(-n): string = "loki-system"
    --purge(-p)
] {
    trace-command $"loki uninstall --namespace=($namespace)" {
        print $"🗑️  Uninstalling Loki from namespace: ($namespace)"
        
        # Uninstall Helm release
        helm uninstall loki --namespace $namespace
        
        if $purge {
            print "🧹 Purging namespace and PVCs"
            kubectl delete namespace $namespace --ignore-not-found
            kubectl delete pvc -l app.kubernetes.io/name=loki --all-namespaces --ignore-not-found
        }
        
        print "✅ Loki uninstallation completed"
    }
}

# Get Loki status
def "loki status" [
    --namespace(-n): string = "loki-system"
] {
    trace-command $"loki status --namespace=($namespace)" {
        print $"📊 Loki status in namespace: ($namespace)"
        
        # Check namespace
        let ns_status = (kubectl get namespace $namespace -o json | from json | get status.phase)
        print $"Namespace: ($namespace) - ($ns_status)"
        
        # Check Loki pods
        print "🏗️  Loki Pods:"
        kubectl get pods -n $namespace -l app.kubernetes.io/name=loki
        
        # Check services
        print "🌐 Loki Services:"
        kubectl get services -n $namespace -l app.kubernetes.io/name=loki
        
        # Check PVCs
        print "💾 Persistent Volume Claims:"
        kubectl get pvc -n $namespace -l app.kubernetes.io/name=loki
        
        # Check Helm release
        print "📦 Helm Release:"
        helm list -n $namespace | grep loki
    }
}

# Port forward to Loki for local access
def "loki port-forward" [
    --namespace(-n): string = "loki-system"
    --port(-p): int = 3100
] {
    trace-command $"loki port-forward --port=($port)" {
        print $"🔗 Port forwarding Loki on port ($port)"
        print $"Access Loki at: http://localhost:($port)"
        print "Press Ctrl+C to stop port forwarding"
        
        kubectl port-forward -n $namespace service/loki $"($port):3100"
    }
}

# Query Loki logs
def "loki query" [
    query: string
    --namespace(-n): string = "loki-system"
    --limit(-l): int = 100
    --since(-s): string = "1h"
] {
    trace-command $"loki query ($query)" {
        print $"🔍 Querying Loki logs: ($query)"
        
        # Use logcli if available, otherwise provide kubectl port-forward instructions
        let logcli_available = (which logcli | length) > 0
        
        if $logcli_available {
            logcli query --addr=http://localhost:3100 --limit=$limit --since=$since $query
        } else {
            print "⚠️  logcli not found. Install it or use port-forward:"
            print $"kubectl port-forward -n ($namespace) service/loki 3100:3100"
            print $"Then query: curl 'http://localhost:3100/loki/api/v1/query_range?query=($query)'"
        }
    }
}

# Install Promtail (Loki log collector)
def "loki install-promtail" [
    --namespace(-n): string = "loki-system"
    --loki-url(-u): string = "http://loki:3100/loki/api/v1/push"
] {
    trace-command $"loki install-promtail" {
        print "🚀 Installing Promtail log collector"
        
        let promtail_values = $"
config:
  clients:
    - url: ($loki_url)
  positions:
    filename: /tmp/positions.yaml
  scrape_configs:
    - job_name: kubernetes-pods
      kubernetes_sd_configs:
        - role: pod
      pipeline_stages:
        - cri: {}
      relabel_configs:
        - action: replace
          source_labels:
          - __meta_kubernetes_pod_node_name
          target_label: node_name
        - action: replace
          source_labels:
          - __meta_kubernetes_namespace
          target_label: namespace
        - action: replace
          source_labels:
          - __meta_kubernetes_pod_name
          target_label: pod
        - action: replace
          source_labels:
          - __meta_kubernetes_pod_container_name
          target_label: container
        - action: replace
          replacement: /var/log/pods/*$1/*.log
          separator: /
          source_labels:
          - __meta_kubernetes_pod_uid
          - __meta_kubernetes_pod_container_name
          target_label: __path__

daemonset:
  enabled: true
"
        
        # Write values to temporary file
        let values_file = "/tmp/promtail-values.yaml"
        $promtail_values | save -f $values_file
        
        # Install Promtail
        helm upgrade --install promtail grafana/promtail --namespace $namespace --values $values_file --wait
        
        # Clean up temporary file
        rm $values_file
        
        print "✅ Promtail installation completed"
    }
}

# Get Loki configuration
def "loki config" [
    --namespace(-n): string = "loki-system"
] {
    trace-command $"loki config" {
        print "📋 Loki Configuration:"
        kubectl get configmap -n $namespace -l app.kubernetes.io/name=loki -o yaml
    }
}

# Show Loki logs
def "loki logs" [
    --namespace(-n): string = "loki-system"
    --follow(-f)
    --lines(-l): int = 100
] {
    trace-command $"loki logs" {
        let follow_flag = if $follow { "--follow" } else { "" }
        
        print $"📋 Loki container logs (latest ($lines) lines):"
        
        if $follow {
            kubectl logs -n $namespace -l app.kubernetes.io/name=loki --follow --tail=$lines
        } else {
            kubectl logs -n $namespace -l app.kubernetes.io/name=loki --tail=$lines
        }
    }
}