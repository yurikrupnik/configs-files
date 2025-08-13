# Main KCL file for cluster configuration management
import base
import environments.local
import environments.staging
import environments.production

# Export all cluster configurations
clusters = {
    local = local.localCluster
    staging = staging.stagingCluster
    production = production.productionCluster
}
# Summary information
summary = {
    total_environments = len(clusters)
    environments = [name for name, _ in clusters]
    total_applications = sum([len(env.applications) for _, env in clusters])
    total_budget = sum([env.cost.budget for _, env in clusters])
    cluster_info = {name: {
        $type = env.environment.$type
        nodes = env.environment.nodeCount
        enabled_apps = len([app for app in env.applications if app.enabled])
        budget = env.cost.budget
    } for name, env in clusters}
}
# Export for use
{
    clusters = clusters
    summary = summary
}
