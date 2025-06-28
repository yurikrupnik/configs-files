# System Setup Module
# Handles system requirements checking and basic setup

use std log

# Check system requirements
export def system-check [dry_run: bool = false] {
    log info "🔍 Checking system requirements..."
    
    # Check if running on macOS
    let os = (sys host | get name)
    if $os != "Darwin" {
        log error $"❌ This script is designed for macOS, but detected: ($os)"
        exit 1
    }
    
    log info "✅ Running on macOS"
    
    # Check if curl is available
    if not (which curl | is-not-empty) {
        log error "❌ curl is required but not found. Please install Xcode Command Line Tools:"
        log error "   xcode-select --install"
        exit 1
    }
    
    log info "✅ curl is available"
    
    # Check available disk space (minimum 5GB)
    let df_output = (^df -h / | lines | last | split row -r '\s+' | get 3)
    log info $"✅ Available disk space: ($df_output)"
    
    # Check internet connectivity
    log info "🌐 Checking internet connectivity..."
    if $dry_run {
        log info "🔍 DRY RUN: Would check internet connectivity"
    } else {
        try {
            http get --max-time 5sec https://github.com | ignore
            log info "✅ Internet connectivity verified"
        } catch {
            log error "❌ No internet connection. Please check your network settings."
            exit 1
        }
    }
    
    log info "✅ System requirements check completed"
}

# Check if a command exists
export def command-exists [command: string] {
    (which $command | is-not-empty)
}

# Get system information  
export def get-system-info [] {
    let host_info = (sys host)
    let cpu_info = (sys cpu | first)
    
    {
        os: $host_info.name,
        version: $host_info.os_version,
        arch: $host_info.arch,
        cpu: $cpu_info.brand,
        cores: ($cpu_info.cpu_usage | length),
        memory: ($host_info.total_memory / 1024 / 1024 / 1024 | math round | $"($in)GB")
    }
}

# Print system information
export def print-system-info [] {
    let info = get-system-info
    
    print "🖥️  System Information:"
    print $"   OS: ($info.os) ($info.version)"
    print $"   Architecture: ($info.arch)"
    print $"   CPU: ($info.cpu)"
    print $"   Cores: ($info.cores)"
    print $"   Memory: ($info.memory)"
    print ""
}