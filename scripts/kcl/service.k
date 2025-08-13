import k8s.api.core.v1 as core
import k8s.apimachinery.pkg.apis.meta.v1 as metav1

# Service configuration schema
schema ServiceConfig:
    name: str
    namespace?: str = "default"
    port?: int = 80
    targetPort?: int = 8080
    serviceType?: str = "ClusterIP"
    selector?: {str: str} = {}

# Service configuration
config: ServiceConfig = {
    name = "my-app"
    namespace = "default"
    port = 80
    targetPort = 80
    serviceType = "ClusterIP"
    selector = {
        app = "my-app"
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
                port = config.port
                targetPort = config.targetPort
                protocol = "TCP"
            }
        ]
        selector = config.selector
    }
}

# Output the service
service