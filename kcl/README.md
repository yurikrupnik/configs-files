# KCL Configuration Management

This directory contains [KCL (Configuration Language)](https://kcl-lang.io/) configurations for managing cloud-native infrastructure across multiple environments. KCL provides type-safe configuration with schema validation, making it ideal for managing complex Kubernetes deployments.

## 🏗️ Architecture

The configuration is organized into a hierarchical structure:

```
kcl/
├── base.k                    # Core schemas and configurations
├── environments/             # Environment-specific configurations
│   ├── local.k              # Local development environment
│   ├── staging.k            # Staging environment (AKS)
│   └── production.k         # Production environment (GKE)
├── main.k                   # Main entry point with all environments
├── test.k                   # Validation and testing
├── kcl.mod                  # KCL module configuration
└── README.md               # This file
```

## 📋 Schemas

### Environment Schema
Defines infrastructure characteristics for each environment:

- **name**: Environment identifier
- **type**: Infrastructure type (`local`, `aks`, `eks`, `gke`)
- **region/zone**: Geographic location (optional for local)
- **nodeCount**: Number of worker nodes
- **nodeSize**: Node size specification (`small`, `medium`, `large`)

### Application Schema
Defines applications deployed to each environment:

- **name**: Application identifier
- **namespace**: Kubernetes namespace
- **enabled**: Deployment flag
- **version**: Application version (optional)
- **values**: Helm values or configuration (optional)

### Cost Configuration
Defines budget and cost monitoring:

- **budget**: Maximum budget in USD
- **alertThreshold**: Alert percentage (0-100)
- **currency**: Budget currency

### Monitoring Configuration
Defines observability settings:

- **uptime**: Enable uptime monitoring
- **metrics**: Enable metrics collection
- **logs**: Enable log aggregation

## 🚀 Quick Start

### Prerequisites

Install KCL:
```bash
# macOS
brew install kcl

# Or download from https://kcl-lang.io/docs/installation/
```

### Initialize the Project

The project is already initialized, but if starting fresh:
```bash
cd kcl
kcl mod init
kcl mod add k8s  # Add Kubernetes schemas
```

### Run Configurations

Test individual environments:
```bash
# Local development environment
kcl run environments/local.k

# Staging environment
kcl run environments/staging.k

# Production environment
kcl run environments/production.k

# All environments with summary
kcl run main.k

# Run validation tests
kcl run test.k
```

### Generate YAML Output

Generate Kubernetes-compatible YAML:
```bash
# Output local environment as YAML
kcl run environments/local.k --format yaml

# Save to file
kcl run environments/local.k --format yaml > local-config.yaml
```

## 🔧 Default Applications

Each environment includes these core applications:

| Application | Namespace | Purpose |
|-------------|-----------|---------|
| **Crossplane** | `crossplane-system` | Infrastructure as Code |
| **ArgoCD** | `argocd` | GitOps CD |
| **Prometheus** | `monitoring` | Metrics collection |
| **Loki** | `monitoring` | Log aggregation |
| **External Secrets** | `external-secrets` | Secret management |
| **Flux** | `flux-system` | GitOps alternative |

## 🌍 Environment Details

### Local Environment
- **Purpose**: Development and testing
- **Infrastructure**: Kind cluster (1 node)
- **Budget**: $100/month
- **Applications**: All 6 core applications
- **Use Case**: Local development, experimentation

### Staging Environment
- **Purpose**: Pre-production testing
- **Infrastructure**: Azure AKS (3 nodes, eastus)
- **Budget**: $1,000/month
- **Applications**: All 6 core applications
- **Use Case**: Integration testing, UAT

### Production Environment
- **Purpose**: Live production workloads
- **Infrastructure**: Google GKE (5 nodes, us-central1)
- **Budget**: $5,000/month
- **Applications**: All 6 core applications
- **Use Case**: Production services, high availability

## ✅ Validation and Testing

The `test.k` file provides comprehensive validation:

```bash
kcl run test.k
```

**Test Coverage:**
- Schema validation for all types
- Environment-specific constraints
- Budget and resource validation
- Application consistency checks
- Node count and sizing validation

**Sample Test Results:**
```yaml
validation_results:
  test_cluster_valid: true
  local_env_valid: true
  staging_env_valid: true
  production_env_valid: true
  # ... all validations
```

## 🔄 Integration with Dev Flow

### 1. Cluster Creation
Use KCL configurations with the existing Nu shell scripts:

```bash
# In the main project directory
source scripts/nu-scripts/main.nu

# Create cluster based on KCL config
cluster create local --config kcl/environments/local.k
```

### 2. ArgoCD Application Generation
Generate ArgoCD applications from KCL configs:

```bash
# Generate ArgoCD app manifests
kcl run main.k | yq '.clusters.local.applications[]' > argocd-apps.yaml
```

### 3. Cost Monitoring
Extract cost configurations for monitoring setup:

```bash
# Get cost thresholds for alerting
kcl run environments/production.k | yq '.productionCluster.cost'
```

### 4. CI/CD Pipeline Integration
```yaml
# .github/workflows/kcl-validation.yml
name: KCL Validation
on: [push, pull_request]
jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install KCL
        run: curl -fsSL https://kcl-lang.io/install.sh | bash
      - name: Validate Configs
        run: |
          cd kcl
          kcl run test.k
          kcl run main.k --format yaml > output.yaml
```

## 📝 Customization

### Adding New Environments

1. Create new environment file:
```bash
cp environments/local.k environments/new-env.k
```

2. Update configuration:
```kcl
# environments/new-env.k
import ..base

newEnvironmentCluster: base.ClusterConfig = {
    name = "new-environment"
    environment = {
        name = "new-env"
        type = "eks"  # or aks, gke
        region = "us-west-2"
        nodeCount = 4
        nodeSize = "medium"
    }
    applications = base.defaultApps
    cost = {
        budget = 2000
        alertThreshold = 85
        currency = "USD"
    }
    monitoring = {
        uptime = True
        metrics = True
        logs = True
    }
}
```

3. Add to main.k:
```kcl
import environments.new-env
# ... in clusters object
new_env = new-env.newEnvironmentCluster
```

### Adding New Applications

1. Update `base.k`:
```kcl
defaultApps: [Application] = [
    # ... existing apps
    {
        name = "new-app"
        namespace = "new-namespace"
        enabled = True
        values = {
            # app-specific configuration
        }
    }
]
```

### Customizing Per Environment

Override applications for specific environments:
```kcl
# In environment file
localCluster: base.ClusterConfig = {
    # ... other config
    applications = base.defaultApps + [
        {
            name = "development-tools"
            namespace = "dev-tools"
            enabled = True
        }
    ]
}
```

## 🔗 Integration Points

### With Nu Shell Scripts
```bash
# Extract environment type for cluster creation
ENV_TYPE=$(kcl run environments/local.k | yq '.localCluster.environment.type')
cluster create local --type $ENV_TYPE
```

### With Crossplane
```bash
# Generate Crossplane provider configs
kcl run main.k | yq '.clusters[].environment | select(.type != "local")'
```

### With ArgoCD
```bash
# Generate ArgoCD application manifests
kcl run main.k --format yaml | yq '.clusters[].applications[]'
```

## 🐛 Troubleshooting

### Common Issues

1. **Import Errors**
```bash
error: CannotFindModule
```
**Solution**: Ensure you're running from the `kcl/` directory and all import paths are correct.

2. **Schema Validation Errors**
```bash
error: TypeError
```
**Solution**: Check that all required fields are provided and types match the schema.

3. **YAML Output Issues**
```bash
# Use explicit format flag
kcl run main.k --format yaml
```

### Debugging

Enable verbose output:
```bash
kcl run main.k --verbose
```

Check syntax:
```bash
kcl fmt base.k  # Format and check syntax
```

## 📊 Metrics and Monitoring

The KCL configurations provide built-in cost and resource tracking:

**Total Infrastructure Cost**: $6,100/month across all environments
**Total Applications**: 18 (6 per environment)
**Total Compute Nodes**: 9 (1 + 3 + 5)

**Budget Allocation**:
- Local: $100 (1.6%)
- Staging: $1,000 (16.4%)
- Production: $5,000 (82.0%)

## 🤝 Contributing

1. Validate changes:
```bash
kcl run test.k
```

2. Format code:
```bash
kcl fmt *.k environments/*.k
```

3. Update documentation if adding new schemas or environments

4. Test integration with Nu shell scripts

## 📚 Resources

- [KCL Official Documentation](https://kcl-lang.io/)
- [KCL Schema Guide](https://kcl-lang.io/docs/reference/lang/tour)
- [Kubernetes Package](https://artifacthub.io/packages/kcl/kcl-lang/k8s)
- [KCL Examples](https://github.com/kcl-lang/examples)

## 📄 License

This configuration is part of the configs-files project and follows the same MIT license.