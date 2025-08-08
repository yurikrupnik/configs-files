# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a dotfiles and configuration management repository containing:
- **Shell configurations**: Nu shell scripts with custom functions for development workflow
- **Kubernetes operator**: Rust-based operator for managing installations in clusters
- **Development tools**: Configuration for devbox, starship, zsh, and various CLI tools
- **Automation scripts**: Setup and initialization scripts for development environments

## Key Components

### Kubernetes Operator (`cluster/`)
A Rust-based Kubernetes operator that manages installations via various command executors:
- **Main binary**: `cluster/src/main.rs` - CLI with subcommands for running operator, installing CRDs, and validation
- **CRD definitions**: Custom Resource Definitions for Installation resources
- **Controller logic**: Handles Installation resource lifecycle in Kubernetes clusters

### Nu Shell Configuration (`nu/`)
Custom Nu shell configuration with extensive function library:
- **Main config**: `nu/.config/nu/config.nu` - Sources other configuration files
- **Functions**: `nu/.config/nu/functions.nu` - Custom commands for development workflow
- **Services**: `nu/.config/nu/services.nu` - Service management functions
- **Environment**: `nu/.config/nu/env.nu` - Environment variable configuration

### Development Environment (`devbox/`)
Devbox configuration for consistent development environments:
- **Global packages**: Includes kubectl, kind, helm, rust toolchain, and various CLI tools
- **Environment variables**: Pre-configured for GCloud, Kubernetes, and development tools

## Common Commands

### Kubernetes Operator Development
```bash
# Build and test the operator
cd cluster
make build
make test
make fmt
make clippy

# Run operator locally
make run-local

# Deploy to cluster
make dev-setup      # Build, install CRDs and RBAC
make deploy         # Full deployment
make status         # Check deployment status
```

### Nu Shell Functions
These functions are available when Nu shell is configured:
```nu
# Kubernetes management
knd <namespace>     # Switch kubectl namespace
ad                  # Show kubectl contexts
ku                  # Unset kubectl context
kc                  # Create kind cluster with Istio

# Git shortcuts
gs                  # Git status
ga [file]          # Git add
gc <message>       # Git commit
gp                 # Git push

# Development workflow
sys-update         # Update brew packages and Rust
nx-run <task>      # Run Nx task on all projects
nx-runa <task>     # Run Nx task on affected projects

# Navigation
projects           # Navigate to ~/projects
configs            # Navigate to ~/configs-files

# System management
sysinfo            # Show formatted system information
dps                # Docker ps with formatting
dclean             # Clean Docker system
psg <pattern>      # Search processes
```

### Environment Setup
```bash
# Initialize entire development environment
./init.sh

# Setup Nu shell configuration
./scripts/setup-nu.sh

# Test Nu functions
nu ./scripts/test-nu-functions.nu
```

## Architecture Notes

### Operator Pattern
The Kubernetes operator follows standard controller pattern:
- **CRD**: Defines Installation custom resources
- **Controller**: Watches for Installation resources and reconciles desired state
- **Executor**: Handles different command execution strategies (cargo, go-task, just, nu)

### Configuration Management
- **Stow-based**: Uses GNU stow for symlink management of dotfiles
- **Modular**: Separate configuration files for different tools
- **Environment-specific**: Devbox provides isolated, reproducible environments

### Nu Shell Integration
- **Function library**: Extensive custom functions for development workflow
- **Environment aware**: Integrates with kubectl, docker, git, and other tools
- **Cross-platform**: Designed to work across different operating systems

## Development Workflow

1. **Environment Setup**: Use `init.sh` to install dependencies and configure environment
2. **Configuration**: Use stow to symlink configuration files
3. **Kubernetes Development**: Use Makefile targets for operator development
4. **Shell Workflow**: Use Nu shell functions for daily development tasks

## Security Guidelines

### Secret Management
- **Never commit secrets**: Use .gitignore patterns to prevent accidental commits
- **Temporary secrets**: Store in `tmp/secrets/` for automatic cleanup
- **Service account keys**: Use `gcloud auth application-default login` instead of JSON files
- **File permissions**: Use `secure-file` function to set 600 permissions on sensitive files

### Secret Storage Options
1. **External authentication**: `gcloud auth application-default login`
2. **Environment variables**: For runtime secrets
3. **Encrypted storage**: Use `sops` or `age` for encrypted secrets in repository
4. **Secret managers**: Google Secret Manager, HashiCorp Vault, etc.

### Security Functions
```nu
load-secrets     # Check and load secrets securely
cleanup-secrets  # Clean temporary secret files
clean-tmp       # Clean all temporary files
secure-file <path> # Set secure permissions on files
```

### Security Checklist
- [ ] No hardcoded secrets in code
- [ ] Service account keys rotated if exposed
- [ ] Temporary files cleaned regularly
- [ ] Proper file permissions on sensitive files
- [ ] Use workload identity in Kubernetes when possible

## Testing

### Operator Testing
```bash
cd cluster
make test              # Run all tests
make validate-examples # Validate example YAML files
```

### Configuration Testing
```bash
# Test Nu functions
nu ./scripts/test-nu-functions.nu

# Test stow configuration
stow --no-folding -nv zsh  # Dry run
```

## Enhanced Application Management

The repository now supports comprehensive application management across any scale:

### Core Capabilities
- **Multi-provider clusters**: Kind, K3d, Minikube, GKE, EKS, AKS support
- **Full observability stack**: Prometheus, Grafana, Loki, Jaeger, OpenTelemetry
- **Secure secrets management**: External Secrets Operator with multi-cloud support
- **GitOps workflows**: FluxCD and ArgoCD integration
- **Cloud provider abstraction**: GCP, AWS, Azure unified interface

### Enhanced Claude Hooks
The Claude settings now include intelligent hooks that:
- **Auto-load secrets** before cluster operations
- **Optimize parallel execution** for builds and deployments  
- **Clean up resources** after operations
- **Validate configurations** on code changes
- **Provide contextual feedback** on errors

### New Scripts

#### Cluster Management (`scripts/cluster-setup.nu`)
- `main cluster create` - Create clusters with full observability
- `main cluster destroy` - Clean cluster teardown
- `main cluster status` - Health monitoring

#### Cloud Providers (`scripts/cloud-providers.nu`)  
- `main provider setup <provider>` - Configure cloud credentials
- `main provider managed-cluster <provider>` - Create managed clusters
- `main provider cleanup <provider>` - Resource cleanup

#### Secrets Management (`scripts/secrets-management.nu`)
- `main secrets create/get/sync` - Multi-provider secret operations
- `main secrets backup/restore` - Encrypted backup with age
- `main secrets list` - Cross-provider secret inventory

#### Application Management (`scripts/app-management.nu`)
- `main app deploy/upgrade/rollback` - Application lifecycle
- `main app status/logs/describe` - Monitoring and debugging
- `main app scale/restart` - Runtime operations

#### Testing (`tests/integration-tests.nu`)
- `main test all` - Comprehensive integration tests
- `main test benchmark` - Performance benchmarks
- `main test validate` - Configuration validation

### Kubernetes-First Architecture
- **Primary platform**: Kubernetes for all workloads
- **Local development**: Automatic Kind cluster creation if none exists
- **Cloud integration**: Seamless transition from local to cloud clusters
- **Observability by default**: Full monitoring, logging, and tracing stack
- **Security first**: External secrets, encrypted backups, secure file handling

### Usage Examples
```bash
# Quick start - creates cluster with full stack
nu scripts/cluster-setup.nu cluster create

# Deploy application with observability
nu scripts/app-management.nu app deploy myapp --namespace production

# Sync secrets across providers  
nu scripts/secrets-management.nu secrets sync --provider all

# Run comprehensive tests
nu tests/integration-tests.nu test all
``` 