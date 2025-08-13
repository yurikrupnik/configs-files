# Nu Scripts Organization

This directory contains Nu shell scripts organized by theme for better maintainability and discoverability.

## Directory Structure

```
nu-scripts/
├── core/                    # Core entry points and utilities
│   ├── main.nu             # Main entry point with all commands
│   └── services.nu         # Service status checking
├── infrastructure/         # Infrastructure management
│   ├── cluster.nu          # Kubernetes cluster management (kind)
│   └── crossplane.nu       # Infrastructure as code with Crossplane
├── config-management/      # Configuration management
│   └── kcl.nu             # KCL configuration language tools
├── gitops/                 # GitOps and deployment
│   └── argocd.nu          # ArgoCD GitOps management
└── monitoring/             # Monitoring and observability
    ├── loki.nu            # Loki logging stack
    └── tracer.nu          # Command tracing utilities
```

## Usage

### Load All Commands
```nu
source core/main.nu
help commands
```

### Load Individual Modules
```nu
# Infrastructure management
source infrastructure/cluster.nu
source infrastructure/crossplane.nu

# Configuration management  
source config-management/kcl.nu

# GitOps
source gitops/argocd.nu

# Monitoring
source monitoring/loki.nu
source monitoring/tracer.nu
```

## Themes

### 🏗️ Infrastructure
- **cluster.nu**: Kind cluster creation, deletion, management
- **crossplane.nu**: Infrastructure as code, provider management

### ⚙️ Configuration Management  
- **kcl.nu**: Type-safe configuration management with KCL

### 🚀 GitOps & Deployment
- **argocd.nu**: GitOps deployment with ArgoCD

### 📊 Monitoring & Observability
- **loki.nu**: Log aggregation and querying
- **tracer.nu**: Command execution tracing and monitoring

### 🔧 Core & Utilities
- **main.nu**: Entry point that loads all modules and provides help
- **services.nu**: Service status checking utilities

## Examples

```nu
# Create a full-stack cluster
cluster create dev --full-stack

# Install and configure ArgoCD
argocd install --insecure
argocd app create my-app https://github.com/user/repo.git manifests/

# Set up monitoring
loki install --namespace monitoring
loki install-promtail

# Work with KCL configurations
kcl validate
kcl infrastructure-summary
kcl create-cluster local --dry-run
```

## Dependencies

Scripts have internal dependencies:
- Infrastructure scripts depend on monitoring/tracer.nu
- GitOps scripts depend on monitoring/tracer.nu  
- Core/main.nu sources all other modules

These dependencies are automatically handled when sourcing main.nu.