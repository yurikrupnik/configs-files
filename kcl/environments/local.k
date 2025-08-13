# Local environment configuration
import ..base

localCluster: base.ClusterConfig = {
    name = "local-dev"
    environment = {
        name = "local"
        $type = "local"
        nodeCount = 1
        nodeSize = "small"
    }
    applications = base.defaultApps
    cost = {
        budget = 100
        alertThreshold = 50
        currency = "USD"
    }
    monitoring = {
        uptime = True
        metrics = True
        logs = True
    }
}
