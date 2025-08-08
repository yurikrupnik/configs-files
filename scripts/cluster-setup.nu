#!/usr/bin/env nu

def "main cluster create" [
    --provider: string = "kind"
   # --observability: bool = true
    #--secrets: bool = true
    --gitops: string = "flux"
    #--registry: bool = false
#   --gpu: bool = false
] {
    print $"🚀 Creating ($provider) cluster with full observability stack..."
    
    match $provider {
        "kind" => { cluster_create_kind --observability $observability --secrets $secrets --gitops $gitops --registry $registry }
        "k3d" => { cluster_create_k3d --observability $observability --secrets $secrets --gitops $gitops --registry $registry }
        "minikube" => { cluster_create_minikube --observability $observability --secrets $secrets --gitops $gitops --gpu $gpu }
        _ => { error make { msg: $"Unsupported provider: ($provider)" } }
    }
}

def cluster_create_kind [
    --observability: bool
    --secrets: bool
    --gitops: string
    --registry: bool
] {
    let cluster_name = "dev-cluster"
    
    let config = http get "https://raw.githubusercontent.com/yurikrupnik/gitops/main/cluster/cluster.yaml"
    
    let temp_file = $"/tmp/kind-config-($env.USER).yaml"
    $config | save $temp_file
    
    print "📦 Creating Kind cluster..."
    kind create cluster --name $cluster_name --config $temp_file
    rm $temp_file
    
    kubectl cluster-info --context $"kind-($cluster_name)"
    kubectl wait --for=condition=Ready nodes --all --timeout=300s
    
   # if $registry {
   #     setup_local_registry $cluster_name
   # }
    
    install_gateway_api
    
    if $gitops == "flux" {
        install_flux
    } else if $gitops == "argo" {
        install_argocd
    }
    
    if $observability {
        install_observability_stack $gitops
    }
    
    if $secrets {
        install_external_secrets $gitops
    }
    
    print_cluster_info $cluster_name $observability $secrets $gitops

}

def cluster_create_k3d [
    --observability: bool
    --secrets: bool
    --gitops: string
    --registry: bool
] {
    let cluster_name = "dev-cluster"
    
    print "📦 Creating K3d cluster..."
    
    let registry_args = if $registry {
        ["--registry-create" "registry.localhost:5000"]
    } else {
        []
    }
    
    k3d cluster create $cluster_name ...$registry_args --agents 2 --servers 1 --port "8080:80@loadbalancer" --port "8443:443@loadbalancer"
    
    kubectl cluster-info
    kubectl wait --for=condition=Ready nodes --all --timeout=300s
    
    if $observability {
        install_observability_stack $gitops
    }
    
    if $secrets {
        install_external_secrets $gitops
    }
    
    print_cluster_info $cluster_name $observability $secrets $gitops
}

def cluster_create_minikube [
    --observability: bool
    --secrets: bool
    --gitops: string
    --gpu: bool
] {
    let cluster_name = "dev-cluster"
    
    print "📦 Creating Minikube cluster..."
    
    let gpu_args = if $gpu {
        ["--driver=docker" "--gpus=all"]
    } else {
        ["--driver=docker"]
    }
    
    minikube start --profile $cluster_name ...$gpu_args --nodes=3 --memory=8192 --cpus=4
    
    minikube addons enable ingress --profile $cluster_name
    minikube addons enable metrics-server --profile $cluster_name
    
    if $gpu {
        minikube addons enable nvidia-gpu-device-plugin --profile $cluster_name
    }
    
    kubectl cluster-info
    kubectl wait --for=condition=Ready nodes --all --timeout=300s
    
    if $observability {
        install_observability_stack $gitops
    }
    
    if $secrets {
        install_external_secrets $gitops
    }
    
    print_cluster_info $cluster_name $observability $secrets $gitops
}

def setup_local_registry [cluster_name: string] {
    print "🏪 Setting up local container registry..."
    
    let registry_name = "kind-registry"
    let registry_port = "5001"
    
    if not (docker ps --filter $"name=($registry_name)" --format "{{.Names}}" | str contains $registry_name) {
        docker run -d --restart=always -p $"($registry_port):5000" --name $registry_name registry:2
        
        docker network connect "kind" $registry_name
        
        kubectl apply -f - <<< $"
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: \"localhost:($registry_port)\"
    help: \"https://kind.sigs.k8s.io/docs/user/local-registry/\"
"
    }
    
    print $"✅ Local registry available at localhost:($registry_port)"
}

def install_gateway_api [] {
    print "🌐 Installing Gateway API..."
    kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.3.0/standard-install.yaml
    kubectl wait --for=condition=Established crd/gateways.gateway.networking.k8s.io --timeout=60s
}

def install_flux [] {
    print "🔄 Installing FluxCD..."
    
    kubectl apply -f https://github.com/fluxcd/flux2/releases/latest/download/install.yaml
    
    kubectl -n flux-system wait deployment source-controller --for=condition=Available --timeout=300s
    kubectl -n flux-system wait deployment kustomize-controller --for=condition=Available --timeout=300s
    kubectl -n flux-system wait deployment helm-controller --for=condition=Available --timeout=300s
    kubectl -n flux-system wait deployment notification-controller --for=condition=Available --timeout=300s
    kubectl -n flux-system wait deployment image-automation-controller --for=condition=Available --timeout=300s
    kubectl -n flux-system wait deployment image-reflector-controller --for=condition=Available --timeout=300s
    
    print "✅ FluxCD installed successfully"
}

def install_argocd [] {
    print "🔄 Installing ArgoCD..."
    
    kubectl create namespace argocd
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    
    kubectl -n argocd wait deployment argocd-server --for=condition=Available --timeout=300s
    
    let argo_password = (kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 --decode)
    print $"🔑 ArgoCD admin password: ($argo_password)"
    print "   Access: kubectl port-forward -n argocd svc/argocd-server 8080:443"
}

def install_observability_stack [gitops: string] {
    print "📊 Installing observability stack..."
    
    if $gitops == "flux" {
        install_obs_flux
    } else if $gitops == "argo" {
        install_obs_argo
    } else {
        install_obs_direct
    }
}

def install_obs_flux [] {
    let helm_repos = $"
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: prometheus-community
  namespace: flux-system
spec:
  interval: 10m
  url: https://prometheus-community.github.io/helm-charts
---
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: grafana
  namespace: flux-system
spec:
  interval: 10m
  url: https://grafana.github.io/helm-charts
---
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: jaegertracing
  namespace: flux-system
spec:
  interval: 10m
  url: https://jaegertracing.github.io/helm-charts
---
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: open-telemetry
  namespace: flux-system
spec:
  interval: 10m
  url: https://open-telemetry.github.io/opentelemetry-helm-charts
"
    
    let helm_releases = $"
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: prometheus-stack
  namespace: flux-system
spec:
  interval: 10m
  chart:
    spec:
      chart: kube-prometheus-stack
      sourceRef:
        kind: HelmRepository
        name: prometheus-community
  targetNamespace: monitoring
  install:
    createNamespace: true
  values:
    grafana:
      enabled: true
      adminPassword: admin123
      persistence:
        enabled: true
        size: 10Gi
      dashboardProviders:
        dashboardproviders.yaml:
          apiVersion: 1
          providers:
          - name: 'default'
            orgId: 1
            folder: ''
            type: file
            disableDeletion: false
            editable: true
            options:
              path: /var/lib/grafana/dashboards/default
      dashboards:
        default:
          kubernetes-cluster:
            gnetId: 7249
            revision: 1
            datasource: Prometheus
          kubernetes-pods:
            gnetId: 6417
            revision: 1
            datasource: Prometheus
    prometheus:
      prometheusSpec:
        retention: 30d
        storageSpec:
          volumeClaimTemplate:
            spec:
              storageClassName: standard
              accessModes: [\"ReadWriteOnce\"]
              resources:
                requests:
                  storage: 50Gi
---
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: loki-stack
  namespace: flux-system
spec:
  interval: 10m
  chart:
    spec:
      chart: loki-stack
      sourceRef:
        kind: HelmRepository
        name: grafana
  targetNamespace: loki
  install:
    createNamespace: true
  values:
    loki:
      enabled: true
      persistence:
        enabled: true
        size: 10Gi
    promtail:
      enabled: true
    grafana:
      enabled: false
    prometheus:
      enabled: false
---
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: jaeger
  namespace: flux-system
spec:
  interval: 10m
  chart:
    spec:
      chart: jaeger
      sourceRef:
        kind: HelmRepository
        name: jaegertracing
  targetNamespace: tracing
  install:
    createNamespace: true
  values:
    provisionDataStore:
      cassandra: false
      elasticsearch: true
    elasticsearch:
      minimumMasterNodes: 1
      replicas: 1
      esJavaOpts: \"-Xmx512m -Xms512m\"
      resources:
        requests:
          cpu: 100m
          memory: 1Gi
        limits:
          cpu: 1000m
          memory: 1.5Gi
---
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: opentelemetry-collector
  namespace: flux-system
spec:
  interval: 10m
  chart:
    spec:
      chart: opentelemetry-collector
      sourceRef:
        kind: HelmRepository
        name: open-telemetry
  targetNamespace: observability
  install:
    createNamespace: true
  values:
    mode: daemonset
    config:
      receivers:
        otlp:
          protocols:
            grpc:
              endpoint: 0.0.0.0:4317
            http:
              endpoint: 0.0.0.0:4318
        prometheus:
          config:
            scrape_configs:
            - job_name: 'kubernetes-pods'
              kubernetes_sd_configs:
              - role: pod
      processors:
        batch: {}
        memory_limiter:
          limit_mib: 512
      exporters:
        prometheus:
          endpoint: \"0.0.0.0:8889\"
        jaeger:
          endpoint: jaeger-collector.tracing.svc.cluster.local:14250
          tls:
            insecure: true
        loki:
          endpoint: http://loki.loki.svc.cluster.local:3100/loki/api/v1/push
      service:
        pipelines:
          traces:
            receivers: [otlp]
            processors: [memory_limiter, batch]
            exporters: [jaeger]
          metrics:
            receivers: [otlp, prometheus]
            processors: [memory_limiter, batch]
            exporters: [prometheus]
          logs:
            receivers: [otlp]
            processors: [memory_limiter, batch]
            exporters: [loki]
"
    
    print "Applying observability Helm repositories..."
    $helm_repos | kubectl apply -f -
    
    print "Applying observability Helm releases..."
    $helm_releases | kubectl apply -f -
    
    print "✅ Observability stack deployment started via FluxCD"
}

def install_obs_direct [] {
    print "Installing observability stack directly..."
    
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo add grafana https://grafana.github.io/helm-charts
    helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
    helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
    helm repo update
    
    kubectl create namespace monitoring
    kubectl create namespace loki
    kubectl create namespace tracing
    kubectl create namespace observability
    
    print "Installing Prometheus + Grafana..."
    helm install prometheus-stack prometheus-community/kube-prometheus-stack --namespace monitoring --wait --set grafana.adminPassword=admin123
    
    print "Installing Loki..."
    helm install loki-stack grafana/loki-stack --namespace loki --wait --set grafana.enabled=false --set prometheus.enabled=false
    
    print "Installing Jaeger..."
    helm install jaeger jaegertracing/jaeger --namespace tracing --wait
    
    print "Installing OpenTelemetry Collector..."
    helm install otel-collector open-telemetry/opentelemetry-collector --namespace observability --wait
    
    print "✅ Observability stack installed directly"
}

def install_external_secrets [gitops: string] {
    print "🔐 Installing External Secrets Operator..."
    
    if $gitops == "flux" {
        install_secrets_flux
    } else {
        install_secrets_direct
    }
}

def install_secrets_flux [] {
    let helm_repo = $"
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: external-secrets
  namespace: flux-system
spec:
  interval: 10m
  url: https://charts.external-secrets.io
"
    
    let helm_release = $"
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: external-secrets
  namespace: flux-system
spec:
  interval: 10m
  chart:
    spec:
      chart: external-secrets
      sourceRef:
        kind: HelmRepository
        name: external-secrets
  targetNamespace: external-secrets
  install:
    createNamespace: true
  values:
    installCRDs: true
    replicaCount: 2
    resources:
      limits:
        cpu: 200m
        memory: 256Mi
      requests:
        cpu: 100m
        memory: 128Mi
"
    
    $helm_repo | kubectl apply -f -
    $helm_release | kubectl apply -f -
    
    print "✅ External Secrets Operator deployment started via FluxCD"
}

def install_secrets_direct [] {
    helm repo add external-secrets https://charts.external-secrets.io
    helm repo update
    
    helm install external-secrets external-secrets/external-secrets --namespace external-secrets --create-namespace --wait
    
    print "✅ External Secrets Operator installed directly"
}

def print_cluster_info [cluster_name: string, observability: bool, secrets: bool, gitops: string] {
    print $"\n🎉 Cluster '($cluster_name)' setup complete!"
    print "\n📋 Installed components:"
    print "  • Kubernetes cluster (multi-node)"
    print "  • Gateway API"
    
    if $gitops == "flux" {
        print "  • FluxCD (GitOps)"
    } else if $gitops == "argo" {
        print "  • ArgoCD (GitOps)"
    }
    
    if $observability {
        print "  • Prometheus + Grafana (monitoring)"
        print "  • Loki + Promtail (logging)"
        print "  • Jaeger (tracing)"
        print "  • OpenTelemetry Collector"
    }
    
    if $secrets {
        print "  • External Secrets Operator"
    }
    
    print "\n🌐 Access dashboards:"
    if $observability {
        print "  • Grafana: kubectl port-forward -n monitoring svc/prometheus-stack-grafana 3000:80"
        print "  • Prometheus: kubectl port-forward -n monitoring svc/prometheus-stack-kube-prom-prometheus 9090:9090"
        print "  • Jaeger: kubectl port-forward -n tracing svc/jaeger-query 16686:16686"
    }
    
    print "\n🔍 Monitor deployments:"
    print "  • kubectl get pods -A"
    if $gitops == "flux" {
        print "  • kubectl get helmreleases -A"
        print "  • flux get all"
    } else if $gitops == "argo" {
        print "  • kubectl get applications -n argocd"
    }
    
    if $secrets {
        print "  • kubectl get externalsecrets -A"
    }
}

def "main cluster destroy" [cluster_name: string = "dev-cluster"] {
    print $"🗑️  Destroying cluster '($cluster_name)'..."
    
    do --ignore-errors { kind delete cluster --name $cluster_name }
    do --ignore-errors { k3d cluster delete $cluster_name }
    do --ignore-errors { minikube delete --profile $cluster_name }
    
    do --ignore-errors { docker rm -f kind-registry }
    
    print "✅ Cluster destroyed"
}

def "main cluster status" [] {
    print "🔍 Cluster status:"
    kubectl get nodes
    kubectl get pods -A | head -20
}