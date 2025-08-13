import k8s.api.apps.v1 as apps
import k8s.api.core.v1 as core
import k8s.api.networking.v1 as networking
import k8s.apimachinery.pkg.apis.meta.v1 as metav1

# Complete application configuration schema
schema AppConfig:
    name: str
    namespace?: str = "default"
    image: str
    replicas?: int = 1
    port?: int = 8080
    serviceType?: str = "ClusterIP"
    env?: {str: str} = {}
    resources?: {
        requests?: {str: str}
        limits?: {str: str}
    }
    ingress?: {
        enabled?: bool = False
        host?: str
        path?: str = "/"
        tls?: bool = False
    }

# App configuration - can be overridden via CLI or environment
config: AppConfig = {
    name = "sample-app"
    namespace = "default"
    image = "nginx:latest"
    replicas = 2
    port = 80
    serviceType = "ClusterIP"
    env = {
        ENV = "production"
        LOG_LEVEL = "info"
    }
    resources = {
        requests = {
            cpu = "100m"
            memory = "128Mi"
        }
        limits = {
            cpu = "500m"
            memory = "512Mi"
        }
    }
    ingress = {
        enabled = True
        host = "sample-app.local"
        path = "/"
        tls = False
    }
}

# Generate Deployment
deployment = apps.Deployment {
    apiVersion = "apps/v1"
    kind = "Deployment"
    metadata = metav1.ObjectMeta {
        name = config.name
        namespace = config.namespace
        labels = {
            app = config.name
            version = "v1"
        }
    }
    spec = apps.DeploymentSpec {
        replicas = config.replicas
        selector = metav1.LabelSelector {
            matchLabels = {
                app = config.name
            }
        }
        template = core.PodTemplateSpec {
            metadata = metav1.ObjectMeta {
                labels = {
                    app = config.name
                    version = "v1"
                }
            }
            spec = core.PodSpec {
                containers = [
                    core.Container {
                        name = config.name
                        image = config.image
                        ports = [
                            core.ContainerPort {
                                containerPort = config.port
                                name = "http"
                            }
                        ]
                        env = [
                            core.EnvVar {
                                name = k
                                value = v
                            } for k, v in config.env
                        ] if config.env
                        resources = core.ResourceRequirements {
                            requests = config.resources.requests
                            limits = config.resources.limits
                        } if config.resources
                        livenessProbe = core.Probe {
                            httpGet = core.HTTPGetAction {
                                path = "/health"
                                port = config.port
                            }
                            initialDelaySeconds = 30
                            periodSeconds = 10
                        }
                        readinessProbe = core.Probe {
                            httpGet = core.HTTPGetAction {
                                path = "/ready"
                                port = config.port
                            }
                            initialDelaySeconds = 5
                            periodSeconds = 5
                        }
                    }
                ]
            }
        }
    }
}

# Generate Service
service = core.Service {
    apiVersion = "v1"
    kind = "Service"
    metadata = metav1.ObjectMeta {
        name = config.name
        namespace = config.namespace
        labels = {
            app = config.name
        }
    }
    spec = core.ServiceSpec {
        type = config.serviceType
        ports = [
            core.ServicePort {
                port = 80
                targetPort = config.port
                protocol = "TCP"
                name = "http"
            }
        ]
        selector = {
            app = config.name
        }
    }
}

# Generate Ingress (conditional)
ingress = networking.Ingress {
    apiVersion = "networking.k8s.io/v1"
    kind = "Ingress"
    metadata = metav1.ObjectMeta {
        name = config.name
        namespace = config.namespace
        labels = {
            app = config.name
        }
        annotations = {
            "kubernetes.io/ingress.class" = "nginx"
            "nginx.ingress.kubernetes.io/rewrite-target" = "/"
        }
    }
    spec = networking.IngressSpec {
        tls = [
            networking.IngressTLS {
                hosts = [config.ingress.host]
                secretName = "${config.name}-tls"
            }
        ] if config.ingress?.tls
        rules = [
            networking.IngressRule {
                host = config.ingress.host
                http = networking.HTTPIngressRuleValue {
                    paths = [
                        networking.HTTPIngressPath {
                            path = config.ingress.path
                            pathType = "Prefix"
                            backend = networking.IngressBackend {
                                service = networking.IngressServiceBackend {
                                    name = config.name
                                    port = networking.ServiceBackendPort {
                                        number = 80
                                    }
                                }
                            }
                        }
                    ]
                }
            }
        ]
    }
} if config.ingress?.enabled

# Output all resources
manifests = [deployment, service]
manifests += [ingress] if config.ingress?.enabled

manifests