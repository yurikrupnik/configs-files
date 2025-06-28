#!/usr/bin/env nu

# macOS Environment Initialization Script
# This script sets up a complete development environment on a fresh macOS system

use std log

# Configuration
const BREW_BUNDLE_PATH = "brew/Brewfile"
const NUSHELL_CONFIG_DIR = ".config/nu"

# Source initialization modules
source scripts/nu-scripts/init/system-setup.nu
source scripts/nu-scripts/init/package-management.nu  
source scripts/nu-scripts/init/development-tools.nu
source scripts/nu-scripts/init/configuration.nu
source scripts/nu-scripts/init/validation.nu

# Main initialization function
def main [
    --skip-brew        # Skip Homebrew installation
    --skip-rust        # Skip Rust toolchain installation
    --skip-config      # Skip configuration files setup
    --skip-dev-tools   # Skip development tools installation
    --dry-run          # Show what would be done without executing
    --verbose          # Enable verbose logging
] {
    
    # Setup logging
    if $verbose {
        $env.LOG_LEVEL = "DEBUG"
    } else {
        $env.LOG_LEVEL = "INFO"
    }
    
    log info "🚀 Starting macOS environment initialization..."
    
    if $dry_run {
        log info "🔍 DRY RUN MODE - No changes will be made"
    }
    
    # Phase 1: System Requirements Check
    log info "📋 Phase 1: Checking system requirements..."
    system-check $dry_run
    
    # Phase 2: Package Management Setup
    if not $skip_brew {
        log info "🍺 Phase 2: Setting up package management..."
        setup-homebrew $dry_run
        install-brew-packages $BREW_BUNDLE_PATH $dry_run
    } else {
        log info "⏭️  Skipping Homebrew setup"
    }
    
    # Phase 3: Development Tools
    if not $skip_dev_tools {
        log info "🔧 Phase 3: Installing development tools..."
        
        if not $skip_rust {
            setup-rust-toolchain $dry_run
            install-rust-tools $dry_run
        } else {
            log info "⏭️  Skipping Rust toolchain"
        }
        
        setup-krew $dry_run
        setup-devbox $dry_run
    } else {
        log info "⏭️  Skipping development tools"
    }
    
    # Phase 4: Configuration Files
    if not $skip_config {
        log info "⚙️  Phase 4: Setting up configuration files..."
        setup-configurations $dry_run
    } else {
        log info "⏭️  Skipping configuration setup"
    }
    
    # Phase 5: Validation
    log info "✅ Phase 5: Validating installation..."
    let validation_results = validate-installation
    
    if ($validation_results | where success == false | is-empty) {
        log info "🎉 Environment initialization completed successfully!"
        print-completion-summary
    } else {
        log error "❌ Some components failed validation:"
        $validation_results | where success == false | each { |item|
            log error $"  - ($item.component): ($item.message)"
        }
        exit 1
    }
}

# Print completion summary
def print-completion-summary [] {
    print ""
    print "🎯 Environment Setup Complete!"
    print "=============================="
    print ""
    print "✅ Homebrew and packages installed"
    print "✅ Rust toolchain and tools installed"  
    print "✅ Kubernetes tools (kubectl, krew) installed"
    print "✅ Configuration files (zsh, starship, zed) applied"
    print "✅ Development tools installed"
    print ""
    print "🔄 Next Steps:"
    print "  1. Restart your terminal or run: source ~/.zshrc"
    print "  2. Verify installations with: nu init.nu --validate-only"
    print "  3. Customize configurations in ~/.config/"
    print ""
    print "📖 Run 'help commands' to see available Nu shell commands"
}

# Validation-only mode
def "main --validate-only" [] {
    log info "🔍 Running validation checks only..."
    let results = validate-installation
    
    print "Validation Results:"
    print "=================="
    
    $results | each { |item|
        let status = if $item.success { "✅" } else { "❌" }
        print $"($status) ($item.component): ($item.message)"
    }
    
    let failed = ($results | where success == false | length)
    if $failed > 0 {
        print $"\n❌ ($failed) components failed validation"
        exit 1
    } else {
        print "\n🎉 All components validated successfully!"
    }
}

# Show help
def "main --help" [] {
    print ""
    print "macOS Environment Initialization Script"
    print "======================================"
    print ""
    print "USAGE:"
    print "  nu init.nu [OPTIONS]"
    print ""
    print "OPTIONS:"
    print "  --skip-brew         Skip Homebrew installation"
    print "  --skip-rust         Skip Rust toolchain installation"  
    print "  --skip-config       Skip configuration files setup"
    print "  --skip-dev-tools    Skip development tools installation"
    print "  --dry-run           Show what would be done without executing"
    print "  --verbose           Enable verbose logging"
    print "  --validate-only     Only run validation checks" 
    print "  --help              Show this help message"
    print ""
    print "EXAMPLES:"
    print "  nu init.nu                          # Full installation"
    print "  nu init.nu --dry-run                # Preview what will be installed"
    print "  nu init.nu --skip-brew --skip-rust  # Install only configs and dev tools"
    print "  nu init.nu --validate-only          # Check current installation status"
    print ""
}