# FluxCD HelmRelease configuration schema
schema HelmReleaseConfig:
    name: str
    namespace?: str = "flux-system"
    chart: str
    version?: str = "*"
    repository: str
    repositoryNamespace?: str = "flux-system" 
    repositoryName: str
    targetNamespace?: str
    values?: {str: any} = {}
    dependsOn?: [str] = []

# HelmRepository configuration schema  
schema HelmRepositoryConfig:
    name: str
    namespace?: str = "flux-system"
    url: str
    interval?: str = "5m"

# Generate HelmRepository
helmRepository = lambda repo: HelmRepositoryConfig -> any {
    {
        apiVersion = "source.toolkit.fluxcd.io/v1beta2"
        kind = "HelmRepository"
        metadata = {
            name = repo.name
            namespace = repo.namespace
        }
        spec = {
            interval = repo.interval
            url = repo.url
        }
    }
}

# Generate HelmRelease
helmRelease = lambda release: HelmReleaseConfig -> any {
    {
        apiVersion = "helm.toolkit.fluxcd.io/v2beta1" 
        kind = "HelmRelease"
        metadata = {
            name = release.name
            namespace = release.namespace
        }
        spec = {
            interval = "15m"
            chart = {
                spec = {
                    chart = release.chart
                    version = release.version
                    sourceRef = {
                        kind = "HelmRepository"
                        name = release.repositoryName
                        namespace = release.repositoryNamespace
                    }
                }
            }
            targetNamespace = release.targetNamespace if release.targetNamespace else release.namespace
            values = release.values if release.values else {}
            dependsOn = [
                {
                    name = dep
                } for dep in release.dependsOn
            ] if release.dependsOn else []
        }
    }
}

# Common dependency configurations
kedaConfig: HelmReleaseConfig = {
    name = "keda"
    namespace = "flux-system"
    chart = "keda"
    version = "2.14.2"
    repository = "https://kedacore.github.io/charts"
    repositoryName = "keda"
    targetNamespace = "keda-system"
    values = {
        crds = {
            install = True
        }
    }
}

prometheusConfig: HelmReleaseConfig = {
    name = "prometheus"
    namespace = "flux-system" 
    chart = "kube-prometheus-stack"
    version = "76.3.0"
    repository = "https://prometheus-community.github.io/helm-charts"
    repositoryName = "prometheus-community"
    targetNamespace = "monitoring"
    values = {
        grafana = {
            enabled = True
            ingress = {
                enabled = True
            }
        }
        prometheus = {
            prometheusSpec = {
                retention = "15d"
            }
        }
    }
}

chaosConfig: HelmReleaseConfig = {
    name = "chaos-mesh"
    namespace = "flux-system"
    chart = "chaos-mesh"  
    version = "2.6.3"
    repository = "https://charts.chaos-mesh.org"
    repositoryName = "chaos-mesh"
    targetNamespace = "chaos-system"
    values = {
        chaosDaemon = {
            runtime = "containerd"
            socketPath = "/run/containerd/containerd.sock"
        }
    }
}

lokiConfig: HelmReleaseConfig = {
    name = "loki"
    namespace = "flux-system"
    chart = "loki-stack" 
    version = "2.10.2"
    repository = "https://grafana.github.io/helm-charts"
    repositoryName = "grafana"
    targetNamespace = "monitoring"
    dependsOn = ["prometheus"]
    values = {
        grafana = {
            enabled = False
        }
        loki = {
            persistence = {
                enabled = True
                size = "10Gi"
            }
        }
    }
}

externalSecretsConfig: HelmReleaseConfig = {
    name = "external-secrets"
    namespace = "flux-system"
    chart = "external-secrets"
    version = "0.9.19"  
    repository = "https://charts.external-secrets.io"
    repositoryName = "external-secrets"
    targetNamespace = "external-secrets-system"
    values = {
        installCRDs = True
        webhook = {
            port = 9443
        }
    }
}

crossplaneConfig: HelmReleaseConfig = {
    name = "crossplane"
    namespace = "flux-system"
    chart = "crossplane"
    version = "1.16.0"
    repository = "https://charts.crossplane.io/stable"
    repositoryName = "crossplane"
    targetNamespace = "crossplane-system"
    values = {
        args = ["--enable-composition-revisions"]
    }
}

# Repository configurations
repositories = [
    {
        name = "keda"
        namespace = "flux-system" 
        url = "https://kedacore.github.io/charts"
        interval = "5m"
    },
    {
        name = "prometheus-community"
        namespace = "flux-system"
        url = "https://prometheus-community.github.io/helm-charts" 
        interval = "5m"
    },
    {
        name = "chaos-mesh"
        namespace = "flux-system"
        url = "https://charts.chaos-mesh.org"
        interval = "5m"
    },
    {
        name = "grafana"
        namespace = "flux-system"
        url = "https://grafana.github.io/helm-charts"
        interval = "5m"
    },
    {
        name = "external-secrets"
        namespace = "flux-system" 
        url = "https://charts.external-secrets.io"
        interval = "5m"
    },
    {
        name = "crossplane"
        namespace = "flux-system"
        url = "https://charts.crossplane.io/stable"
        interval = "5m"
    }
]

# Generate all resources
allRepositories = [helmRepository(repo) for repo in repositories]
allReleases = [
    helmRelease(kedaConfig),
    helmRelease(prometheusConfig), 
    helmRelease(chaosConfig),
    helmRelease(lokiConfig),
    helmRelease(externalSecretsConfig),
    helmRelease(crossplaneConfig)
]

# Export configurations for individual use
kedaRelease = helmRelease(kedaConfig)
prometheusRelease = helmRelease(prometheusConfig)
chaosRelease = helmRelease(chaosConfig)
lokiRelease = helmRelease(lokiConfig)
externalSecretsRelease = helmRelease(externalSecretsConfig)
crossplaneRelease = helmRelease(crossplaneConfig)