# Cluster CLI

A Rust CLI application for managing Kubernetes clusters and executing Nu scripts with streaming output and observability features.

## Features

- **Cluster Management**: Create, delete, list, and monitor clusters across different environments
- **Nu Script Integration**: Execute Nu scripts with streaming output
- **Multi-Environment Support**: Local (Kind), Azure (AKS), AWS (EKS), and Google Cloud (GKE)
- **Cost Management**: Track and alert on cluster costs
- **Real-time Monitoring**: Watch cluster status with continuous updates
- **GitOps Integration**: Uses Crossplane for declarative cluster management

## Installation

```bash
cargo build --release
```

## Usage

### Cluster Management

```bash
# Create a local cluster
./target/release/cluster-cli cluster create -e local -c local

# Create a staging cluster on AKS
./target/release/cluster-cli cluster create -e staging -c aks

# List all clusters
./target/release/cluster-cli cluster list

# Check cluster status
./target/release/cluster-cli cluster status -e local

# Delete a cluster
./target/release/cluster-cli cluster delete -e local
```

### Script Execution

```bash
# List available Nu scripts
./target/release/cluster-cli script list

# Execute a Nu script
./target/release/cluster-cli script run atlas.nu

# Show script documentation
./target/release/cluster-cli script doc services.nu
```

### Monitoring

```bash
# Monitor cluster once
./target/release/cluster-cli monitor -e local

# Continuous monitoring (watch mode)
./target/release/cluster-cli monitor -e local --watch
```

### Cost Management

```bash
# Show costs for all environments
./target/release/cluster-cli cost show

# Show costs for specific environment
./target/release/cluster-cli cost show -e production

# Set budget alert
./target/release/cluster-cli cost alert -e staging -b 1000 -t 80
```

## Architecture

- **KCL Configurations**: Declarative cluster definitions in `kcl/`
- **Crossplane**: GitOps-based package management in `crossplane/`
- **React Dashboard**: Web UI for cluster visualization in `cluster-manager/`
- **Nu Scripts**: Automation scripts in `nu/.config/nu/`

## Environment Support

1. **Local**: Kind clusters for development
2. **Staging**: AKS clusters for testing
3. **Production**: GKE clusters for live workloads

Each environment has specific cost budgets and monitoring configurations.