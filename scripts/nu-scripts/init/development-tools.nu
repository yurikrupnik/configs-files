# Development Tools Module
# Handles installation of development tools and environments

use std log
source system-setup.nu

# Setup Rust toolchain
export def setup-rust-toolchain [dry_run: bool = false] {
    log info "🦀 Setting up Rust toolchain..."
    
    if (command-exists "rustup") {
        log info "✅ Rustup is already installed"
        
        if $dry_run {
            log info "🔍 DRY RUN: Would update Rust toolchain"
        } else {
            log info "🔄 Updating Rust toolchain..."
            rustup update
        }
        return
    }
    
    if $dry_run {
        log info "🔍 DRY RUN: Would install Rust toolchain"
        return
    }
    
    log info "📦 Installing Rust toolchain..."
    try {
        bash -c (http get "https://sh.rustup.rs") -s -- -y
        
        # Source the Rust environment
        let cargo_env = $"($env.HOME)/.cargo/env"
        if ($cargo_env | path exists) {
            # Update PATH to include cargo bin
            $env.PATH = ($env.PATH | prepend $"($env.HOME)/.cargo/bin")
            log info "✅ Rust toolchain installed successfully"
        } else {
            log warning "⚠️  Rust installed but environment file not found"
        }
    } catch { |e|
        log error $"❌ Failed to install Rust: ($e.msg)"
        exit 1
    }
}

# Install Rust development tools
export def install-rust-tools [dry_run: bool = false] {
    log info "🔧 Installing Rust development tools..."
    
    if not (command-exists "cargo") {
        log error "❌ Cargo not found. Please install Rust first."
        exit 1
    }
    
    let rust_tools = [
        "cargo-binstall",
        "cargo-generate", 
        "wasm-pack",
        "cargo-leptos",
        "sqlx-cli", 
        "cargo-expand",
        "create-tauri-app",
        "protobuf-codegen",
        "cargo-run-script",
        "trunk",
        "salvo-cli",
        "cargo-watch", 
        "cargo-component",
        "cargo-make"
    ]
    
    if $dry_run {
        log info "🔍 DRY RUN: Would install Rust tools:"
        $rust_tools | each { |tool| log info $"  - ($tool)" }
        log info "🔍 DRY RUN: Would add wasm32-unknown-unknown target"
        return
    }
    
    # Install cargo-binstall first for faster subsequent installs
    log info "📦 Installing cargo-binstall..."
    try {
        cargo install cargo-binstall
    } catch { |e|
        log warning $"⚠️  Failed to install cargo-binstall: ($e.msg)"
        log info "📦 Falling back to regular cargo install..."
    }
    
    # Install other tools
    for tool in ($rust_tools | skip 1) {
        log info $"📦 Installing ($tool)..."
        try {
            if (command-exists "cargo-binstall") {
                cargo binstall $tool --no-confirm
            } else {
                cargo install $tool
            }
        } catch { |e|
            log warning $"⚠️  Failed to install ($tool): ($e.msg)"
        }
    }
    
    # Add WASM target
    log info "🎯 Adding wasm32-unknown-unknown target..."
    try {
        rustup target add wasm32-unknown-unknown
        log info "✅ Rust tools installed successfully"
    } catch { |e|
        log warning $"⚠️  Failed to add WASM target: ($e.msg)"
    }
}

# Setup kubectl krew plugin manager
export def setup-krew [dry_run: bool = false] {
    log info "⚙️  Setting up kubectl krew..."
    
    if (command-exists "kubectl-krew") {
        log info "✅ kubectl krew is already installed"
        return
    }
    
    if not (command-exists "kubectl") {
        log warning "⚠️  kubectl not found, skipping krew installation"
        return
    }
    
    if $dry_run {
        log info "🔍 DRY RUN: Would install kubectl krew and plugins"
        return
    }
    
    log info "📦 Installing kubectl krew..."
    try {
        # Create temporary directory
        let temp_dir = (mktemp -d)
        cd $temp_dir
        
        # Download and install krew
        let host_info = (sys host)
        let os = ($host_info.name | str downcase)
        let arch = ($host_info.arch | str replace "x86_64" "amd64" | str replace "arm64" "arm64" | str replace "aarch64" "arm64")
        let krew_archive = $"krew-($os)_($arch)"
        
        http get $"https://github.com/kubernetes-sigs/krew/releases/latest/download/($krew_archive).tar.gz" | save $"($krew_archive).tar.gz"
        tar -zxf $"($krew_archive).tar.gz"
        
        ^$"./($krew_archive)" install krew
        
        # Install additional plugins
        kubectl krew index add kubectl-kcl https://github.com/kcl-lang/kubectl-kcl
        kubectl krew install kubectl-kcl/kcl
        
        log info "✅ kubectl krew installed successfully"
    } catch { |e|
        log warning $"⚠️  Failed to install kubectl krew: ($e.msg)"
    }
}

# Setup Devbox
export def setup-devbox [dry_run: bool = false] {
    log info "📦 Setting up Devbox..."
    
    if (command-exists "devbox") {
        log info "✅ Devbox is already installed"
        return
    }
    
    if $dry_run {
        log info "🔍 DRY RUN: Would install Devbox"
        return
    }
    
    log info "📦 Installing Devbox..."
    try {
        bash -c (http get "https://get.jetify.com/devbox")
        log info "✅ Devbox installed successfully"
    } catch { |e|
        log warning $"⚠️  Failed to install Devbox: ($e.msg)"
    }
}

# Setup Node.js version manager (if not using Homebrew node)
export def setup-node-version-manager [dry_run: bool = false] {
    if (command-exists "node") {
        log info "✅ Node.js is already available"
        return
    }
    
    log info "📦 Setting up Node.js..."
    
    if $dry_run {
        log info "🔍 DRY RUN: Would setup Node.js version manager"
        return
    }
    
    # This is handled by Homebrew in our Brewfile, so we just verify
    if not (command-exists "node") {
        log warning "⚠️  Node.js not found. Make sure it's included in your Brewfile"
    }
}

# Verify development tools installation
export def verify-dev-tools [] {
    let tools = [
        {name: "rust", command: "rustc", version_flag: "--version"},
        {name: "cargo", command: "cargo", version_flag: "--version"},
        {name: "node", command: "node", version_flag: "--version"},
        {name: "npm", command: "npm", version_flag: "--version"}, 
        {name: "pnpm", command: "pnpm", version_flag: "--version"},
        {name: "kubectl", command: "kubectl", version_flag: "version --client"},
        {name: "helm", command: "helm", version_flag: "version --short"},
        {name: "docker", command: "docker", version_flag: "--version"},
        {name: "git", command: "git", version_flag: "--version"}
    ]
    
    $tools | each { |tool|
        let installed = (command-exists $tool.command)
        let version = if $installed {
            try {
                (^$tool.command ($tool.version_flag | split row " ") | str trim)
            } catch {
                "unknown"
            }
        } else {
            "not installed"
        }
        
        {
            tool: $tool.name,
            installed: $installed,
            version: $version
        }
    }
}