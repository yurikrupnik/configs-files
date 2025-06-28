# Base KCL configuration for cluster management
import k8s.api.core.v1 as corev1
import k8s.api.apps.v1 as appsv1

# Environment configuration
schema Environment:
    name: str
    # local, aks, eks, gke
    $type: str
    region?: str
    zone?: str
    nodeCount: int = 3
    nodeSize: str = "medium"

# Application configuration
schema Application:
    name: str
    namespace: str = "default"
    enabled: bool = True
    version?: str
    values?: {str:}

# Cost configuration
schema CostConfig:
    budget: int
    alertThreshold: int = 80
    currency: str = "USD"

# Monitoring configuration
schema MonitoringConfig:
    uptime: bool = True
    metrics: bool = True
    logs: bool = True

# Cluster configuration
schema ClusterConfig:
    name: str
    environment: Environment
    applications: [Application]
    cost: CostConfig
    monitoring: MonitoringConfig

# Default applications
defaultApps: [Application] = [
    {
        name = "crossplane"
        namespace = "crossplane-system"
        enabled = True
        values = {
            args = ["--enable-composition-functions"]
        }
    }
    {
        name = "argocd"
        namespace = "argocd"
        enabled = True
        values = {
            server = {
                service = {
                    $type = "LoadBalancer"
                }
            }
        }
    }
    {
        name = "prometheus"
        namespace = "monitoring"
        enabled = True
    }
    {
        name = "loki"
        namespace = "monitoring"
        enabled = True
    }
    {
        name = "external-secrets"
        namespace = "external-secrets"
        enabled = True
    }
    {
        name = "flux"
        namespace = "flux-system"
        enabled = True
    }
]
