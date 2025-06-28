# Production environment configuration
import ..base

productionCluster: base.ClusterConfig = {
    name = "production"
    environment = {
        name = "production"
        type = "gke"
        # or eks/aks
        region = "us-central1"
        zone = "us-central1-a"
        nodeCount = 3
        nodeSize = "medium"
    }
    applications = base.defaultApps
    cost = {
        budget = 5000
        alertThreshold = 90
        currency = "USD"
    }
    monitoring = {
        uptime = True
        metrics = True
        logs = True
    }
}
