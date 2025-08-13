import k8s.api.apps.v1 as apps
import k8s.api.core.v1 as core
import k8s.apimachinery.pkg.apis.meta.v1 as metav1

# Configuration schema
schema AppConfig:
    #da: metav1.Deployment
    name: str
    namespace?: str = "default"
    image: str
    replicas?: int = 1
    port?: int = 8080
    env?: {str: str} = {}
    resources?: {
        requests?: {str: str}
        limits?: {str: str}
    }

# App configuration
config: AppConfig = {
    name = "my-app"
    namespace = "default"
    image = "nginx:latest"
    replicas = 2
    port = 80
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
                    }
                ]
            }
        }
    }
}

# Output the deployment
deployment