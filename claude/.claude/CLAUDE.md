- Always use the latest SDK updates with context7 and use the internet to make sure as review.
- Always use bun instead of npm or pnpm
- Always prefer a Rust application to be created over another language, choose other languages only when it is more suitable for the task.
- Always prefer nu scripts over shell scripts.

- Don't add comments. At all. Unless something is VERY convoluted or looks confusing. THIS IS CRUCIAL.
- Whenever you encounter new things about the system or my general preferences that would be useful for you to remember, make a suggestion to add notes to your config files.
- After creating PRs, offer to open them with the 'open' command.
  When creating prs that has a corresponding issue, remember to add "close #123" so it closes as well.

## Repository Structure (dotconfig)

### Git Repository
- Main repo: https://github.com/yurikrupnik/dotconfig.git
- Branch structure: main (base), feature branches

### Core Components

**Rust CLI Application**
- Main binary: `dotconfig` (src/main.rs)
- Operator binary: `operator` (src/operator.rs)
- Kubernetes operator for resource management
- Uses: clap, tokio, kube, tracing, serde

**KCL Modules** (scripts/kcl/)
- `manager/` - Main configuration manager
  - Package: oci://docker.io/yurikrupnik/kcl-manager
  - Dependencies: external-secrets, k8s, stam, crossplane
- `stam/` - Shared utilities module
  - Package: oci://docker.io/yurikrupnik/kcl-stam (v0.0.7)
  - Dependencies: k8s, external-secrets
  - Published to OCI registry

**Nushell Scripts** (scripts/nu/)
- `index.nu` - Main entry point for dev workflows
- `local-dev/` - Local development utilities (cluster, gen-dotenv, grafana)
- `setup-local-machine/` - Machine setup scripts
- `shared/` - Shared utilities
- `tests/` - Test files

### Development Tools
- Just commands for task automation
- Cargo workspace with optimized release profile
- Docker compose for local development
- Tilt for Kubernetes development
- Cross-compilation support via Cross.toml
