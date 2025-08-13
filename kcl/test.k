# Test script for KCL configurations
import base
import environments.local
import environments.staging
import environments.production

# Test basic schema functionality
test_environment = base.Environment {
    name = "test"
    $type = "local"
    nodeCount = 2
    nodeSize = "small"
}

test_application = base.Application {
    name = "test-app"
    namespace = "test-namespace"
    enabled = True
    version = "1.0.0"
}

test_cost = base.CostConfig {
    budget = 500
    alertThreshold = 75
    currency = "EUR"
}

test_monitoring = base.MonitoringConfig {
    uptime = True
    metrics = False
    logs = True
}
# Test complete cluster configuration
test_cluster = base.ClusterConfig {
    name = "test-cluster"
    environment = test_environment
    applications = [test_application]
    cost = test_cost
    monitoring = test_monitoring
}
# Environment validation
environments = {
    local = local.localCluster
    staging = staging.stagingCluster
    production = production.productionCluster
}
# Basic validation checks
validation_results = {
    # Schema tests
    test_cluster_valid = test_cluster.name == "test-cluster"
    test_environment_valid = test_environment.name == "test"
    test_application_valid = test_application.name == "test-app"
    # Environment tests
    local_env_valid = environments.local.environment.$type == "local"
    staging_env_valid = environments.staging.environment.$type == "aks"
    production_env_valid = environments.production.environment.$type == "gke"
    # Budget tests
    local_budget_valid = environments.local.cost.budget == 100
    staging_budget_valid = environments.staging.cost.budget == 1000
    production_budget_valid = environments.production.cost.budget == 5000
    # Application count tests
    local_apps_valid = len(environments.local.applications) == 6
    staging_apps_valid = len(environments.staging.applications) == 6
    production_apps_valid = len(environments.production.applications) == 6
    # Node count tests
    local_nodes_valid = environments.local.environment.nodeCount == 1
    staging_nodes_valid = environments.staging.environment.nodeCount == 3
    production_nodes_valid = environments.production.environment.nodeCount == 5
}
# Test summary
{
    total_environments = len(environments)
    test_cluster = test_cluster
    validation_results = validation_results
    environments_summary = {
        local = {
            name = environments.local.name
            $type = environments.local.environment.$type
            budget = environments.local.cost.budget
            apps = len(environments.local.applications)
        }
        staging = {
            name = environments.staging.name
            $type = environments.staging.environment.$type
            budget = environments.staging.cost.budget
            apps = len(environments.staging.applications)
        }
        production = {
            name = environments.production.name
            $type = environments.production.environment.$type
            budget = environments.production.cost.budget
            apps = len(environments.production.applications)
        }
    }
}
