# Configuration Module
# Handles dotfiles and configuration setup

use std log
source system-setup.nu

# Setup configuration files using stow
export def setup-configurations [dry_run: bool = false] {
    log info "⚙️  Setting up configuration files..."
    
    if not (command-exists "stow") {
        log error "❌ GNU Stow is required but not found. Please install it first:"
        log error "   brew install stow"
        exit 1
    }
    
    # Backup existing .zshenv if it exists
    let zshenv_path = $"($env.HOME)/.zshenv"
    if ($zshenv_path | path exists) {
        let backup_path = $"($zshenv_path).bak"
        
        if $dry_run {
            log info $"🔍 DRY RUN: Would backup ($zshenv_path) to ($backup_path)"
        } else {
            log info $"📄 Backing up existing .zshenv to ($backup_path)"
            cp $zshenv_path $backup_path
            rm $zshenv_path
        }
    }
    
    # Configuration packages to stow
    let config_packages = ["zsh", "starship", "zed"]
    
    for package in $config_packages {
        if $dry_run {
            log info $"🔍 DRY RUN: Would stow ($package) configuration"
        } else {
            log info $"📄 Setting up ($package) configuration..."
            try {
                stow $package
                log info $"✅ ($package) configuration applied"
            } catch { |e|
                log warning $"⚠️  Failed to apply ($package) configuration: ($e.msg)"
            }
        }
    }
    
    # Setup Nu shell configuration if it doesn't exist
    setup-nushell-config $dry_run
    
    log info "✅ Configuration setup completed"
}

# Setup Nu shell configuration
export def setup-nushell-config [dry_run: bool = false] {
    let nu_config_dir = $"($env.HOME)/.config/nu"
    
    if not ($nu_config_dir | path exists) {
        if $dry_run {
            log info $"🔍 DRY RUN: Would create Nu config directory at ($nu_config_dir)"
        } else {
            log info $"📁 Creating Nu config directory at ($nu_config_dir)"
            mkdir $nu_config_dir
        }
    }
    
    # Create basic config.nu if it doesn't exist
    let config_file = $"($nu_config_dir)/config.nu"
    if not ($config_file | path exists) {
        let config_content = $"# Nushell Configuration
# This file is used to configure nushell

# Source custom scripts
source ~/.config/nu/custom-commands.nu

# Configure starship prompt
$env.STARSHIP_SHELL = \"nu\"
$env.STARSHIP_SESSION_KEY = (random chars -l 16)
$env.PROMPT_MULTILINE_INDICATOR = (^starship prompt --continuation)

# The prompt function
def create_left_prompt [] {
    ^starship prompt --cmd-duration $env.CMD_DURATION_MS $'--status=($env.LAST_EXIT_CODE)'
}

# Use starship as prompt
$env.PROMPT_COMMAND = { || create_left_prompt }
$env.PROMPT_COMMAND_RIGHT = \"\"

# Configure completions
$env.config = {
  show_banner: false
  completions: {
    case_sensitive: false
    quick: true    
    partial: true    
    algorithm: \"prefix\"    
  }
}
"
        
        if $dry_run {
            log info $"🔍 DRY RUN: Would create Nu config file at ($config_file)"
        } else {
            log info $"📄 Creating Nu config file at ($config_file)"
            $config_content | save $config_file
        }
    }
    
    # Create custom commands file
    let custom_commands_file = $"($nu_config_dir)/custom-commands.nu"
    if not ($custom_commands_file | path exists) {
        let custom_content = $"# Custom Nu Shell Commands
# Add your custom commands and aliases here

# Quick navigation aliases
alias ll = ls -la
alias la = ls -a
alias l = ls

# Git aliases  
alias gs = git status
alias ga = git add
alias gc = git commit
alias gp = git push
alias gl = git pull

# Development aliases
alias k = kubectl
alias d = docker
alias dc = docker-compose

# Load main Nu scripts if available
# Note: You can manually source scripts/nu-scripts/core/main.nu if needed
"
        
        if $dry_run {
            log info $"🔍 DRY RUN: Would create custom commands file at ($custom_commands_file)"
        } else {
            log info $"📄 Creating custom commands file at ($custom_commands_file)"
            $custom_content | save $custom_commands_file
        }
    }
}

# Setup environment variables
export def setup-environment-variables [dry_run: bool = false] {
    log info "🌍 Setting up environment variables..."
    
    let env_vars = {
        "EDITOR": "code",
        "BROWSER": "open",
        "LANG": "en_US.UTF-8", 
        "LC_ALL": "en_US.UTF-8"
    }
    
    if $dry_run {
        log info "🔍 DRY RUN: Would set environment variables:"
        $env_vars | transpose key value | each { |row|
            log info $"  ($row.key)=($row.value)"
        }
        return
    }
    
    # These are typically set in shell configuration files
    # which are handled by stow
    log info "✅ Environment variables will be set via shell configuration"
}

# Verify configuration setup
export def verify-configurations [] {
    let configs = [
        {name: "zsh", path: $"($env.HOME)/.zshrc"},
        {name: "starship", path: $"($env.HOME)/.config/starship.toml"},
        {name: "zed", path: $"($env.HOME)/.config/zed"},
        {name: "nushell", path: $"($env.HOME)/.config/nu/config.nu"}
    ]
    
    $configs | each { |config|
        let exists = ($config.path | path exists)
        {
            configuration: $config.name,
            path: $config.path,
            exists: $exists,
            status: (if $exists { "✅ Found" } else { "❌ Missing" })
        }
    }
}

# Reset configurations (for testing)
export def reset-configurations [--confirm = false] {
    if not $confirm {
        log warning "⚠️  This will remove all stowed configurations. Use --confirm to proceed."
        return
    }
    
    log warning "🗑️  Removing stowed configurations..."
    
    let config_packages = ["zsh", "starship", "zed"]
    
    for package in $config_packages {
        try {
            stow -D $package
            log info $"🗑️  Removed ($package) configuration"
        } catch { |e|
            log warning $"⚠️  Failed to remove ($package): ($e.msg)"
        }
    }
}