# KCL Configuration Files

This directory contains KCL (KCL Configuration Language) files for generating Kubernetes manifests.

## Available Templates

### 1. `deployment.k`
Basic Kubernetes Deployment configuration with:
- Configurable app name, image, replicas
- Environment variables
- Resource requests and limits
- Health checks

**Usage:**
```bash
nu scripts/app-management.nu app kcl-build-app my-app --kcl-file scripts/kcl/deployment.k --apply
```

### 2. `service.k`
Kubernetes Service configuration with:
- Configurable service type (ClusterIP, NodePort, LoadBalancer)
- Port mapping
- Label selectors

**Usage:**
```bash
nu scripts/app-management.nu app kcl-build-app my-service --kcl-file scripts/kcl/service.k --apply
```

### 3. `complete-app.k`
Complete application stack including:
- Deployment with health checks
- Service
- Optional Ingress with TLS support
- Comprehensive configuration schema

**Usage:**
```bash
nu scripts/app-management.nu app kcl-build-app full-app --kcl-file scripts/kcl/complete-app.k --apply
```

## Customizing Configurations

Each KCL file contains a `config` section at the top that can be modified:

```kcl
config: AppConfig = {
    name = "my-custom-app"
    namespace = "production"
    image = "my-app:v1.2.3"
    replicas = 3
    port = 8080
    // ... other settings
}
```

## Testing

Generate manifests without applying:
```bash
nu scripts/app-management.nu app kcl-build-app test-app --kcl-file scripts/kcl/complete-app.k
```

Dry run validation:
```bash
nu scripts/app-management.nu app kcl-build-app test-app --kcl-file scripts/kcl/complete-app.k --apply --dry-run
```

## Output

Generated YAML manifests are saved to `./output/<app-name>.yaml` by default.