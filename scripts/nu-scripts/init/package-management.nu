# Package Management Module
# Handles Homebrew installation and package management

use std log
source system-setup.nu

# Setup Homebrew
export def setup-homebrew [dry_run: bool = false] {
    log info "🍺 Setting up Homebrew..."
    
    if (command-exists "brew") {
        log info "✅ Homebrew is already installed"
        
        if $dry_run {
            log info "🔍 DRY RUN: Would update Homebrew"
        } else {
            log info "🔄 Updating Homebrew..."
            brew update
        }
        return
    }
    
    if $dry_run {
        log info "🔍 DRY RUN: Would install Homebrew"
        return
    }
    
    log info "📦 Installing Homebrew..."
    try {
        bash -c (http get "https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh")
        
        # Add Homebrew to PATH for Apple Silicon Macs
        let brew_path = if (sys host | get arch) == "aarch64" {
            "/opt/homebrew/bin/brew"
        } else {
            "/usr/local/bin/brew" 
        }
        
        if ($brew_path | path exists) {
            $env.PATH = ($env.PATH | prepend ($brew_path | path dirname))
            log info "✅ Homebrew installed and added to PATH"
        } else {
            log error "❌ Homebrew installation failed"
            exit 1
        }
    } catch { |e|
        log error $"❌ Failed to install Homebrew: ($e.msg)"
        exit 1
    }
}

# Install packages from Brewfile
export def install-brew-packages [brewfile_path: string, dry_run: bool = false] {
    log info $"📦 Installing packages from ($brewfile_path)..."
    
    if not ($brewfile_path | path exists) {
        log error $"❌ Brewfile not found at: ($brewfile_path)"
        exit 1
    }
    
    if not (command-exists "brew") {
        log error "❌ Homebrew is not installed or not in PATH"
        exit 1
    }
    
    if $dry_run {
        log info "🔍 DRY RUN: Would install packages from Brewfile"
        let packages = (open $brewfile_path | lines | where ($it | str starts-with "brew ") | each { |line| 
            $line | str replace 'brew "' '' | str replace '"' ''
        })
        log info $"Would install ($packages | length) brew packages:"
        $packages | each { |pkg| log info $"  - ($pkg)" }
        
        let casks = (open $brewfile_path | lines | where ($it | str starts-with "cask ") | each { |line|
            $line | str replace 'cask "' '' | str replace '"' ''
        })
        log info $"Would install ($casks | length) cask packages:"
        $casks | each { |pkg| log info $"  - ($pkg)" }
        return
    }
    
    try {
        brew bundle --file $brewfile_path
        log info "✅ Packages installed successfully"
    } catch { |e|
        log error $"❌ Failed to install packages: ($e.msg)"
        log info "💡 You can continue manually with: brew bundle --file ($brewfile_path)"
        exit 1
    }
}

# Update Homebrew and packages
export def update-homebrew [dry_run: bool = false] {
    if not (command-exists "brew") {
        log warning "⚠️  Homebrew not found, skipping update"
        return
    }
    
    if $dry_run {
        log info "🔍 DRY RUN: Would update Homebrew and packages"
        return
    }
    
    log info "🔄 Updating Homebrew..."
    try {
        brew update
        brew upgrade
        brew cleanup
        log info "✅ Homebrew updated successfully"
    } catch { |e|
        log warning $"⚠️  Homebrew update failed: ($e.msg)"
    }
}

# List installed packages
export def list-brew-packages [] {
    if not (command-exists "brew") {
        return []
    }
    
    let formulas = (brew list --formula | lines | each { |name| {type: "formula", name: $name} })
    let casks = (brew list --cask | lines | each { |name| {type: "cask", name: $name} })
    
    $formulas | append $casks
}

# Check for outdated packages
export def check-outdated-packages [] {
    if not (command-exists "brew") {
        return []
    }
    
    let outdated_formulas = (brew outdated --formula | lines | each { |line|
        let parts = ($line | split row " ")
        {type: "formula", name: ($parts | first), current: ($parts | get 1? | default "unknown"), latest: ($parts | get 2? | default "unknown")}
    })
    
    let outdated_casks = (brew outdated --cask | lines | each { |line|
        let parts = ($line | split row " ") 
        {type: "cask", name: ($parts | first), current: ($parts | get 1? | default "unknown"), latest: ($parts | get 2? | default "unknown")}
    })
    
    $outdated_formulas | append $outdated_casks
}