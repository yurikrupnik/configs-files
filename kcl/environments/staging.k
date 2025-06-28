# Staging environment configuration
import ..base

stagingCluster: base.ClusterConfig = {
    name = "staging"
    environment = {
        name = "staging"
        # or eks/gke
        $type = "aks"
        region = "eastus"
        nodeCount = 3
        nodeSize = "medium"
    }
    applications = base.defaultApps
    cost = {
        budget = 1000
        alertThreshold = 80
        currency = "USD"
    }
    monitoring = {
        uptime = True
        metrics = True
        logs = True
    }
}
