# Validation Module
# Handles validation and testing of the installation

use std log
source system-setup.nu
source development-tools.nu
source configuration.nu

# Main validation function
export def validate-installation [] {
    log info "🔍 Running installation validation..."
    
    let validations = [
        (validate-system-requirements),
        (validate-package-management),
        (validate-development-tools),
        (validate-configurations),
        (validate-environment)
    ]
    
    $validations | flatten
}

# Validate system requirements
export def validate-system-requirements [] {
    [
        {
            component: "Operating System",
            success: ((sys host | get name) == "Darwin"),
            message: (if ((sys host | get name) == "Darwin") { "macOS detected" } else { "Not running on macOS" })
        },
        {
            component: "curl",
            success: (command-exists "curl"),
            message: (if (command-exists "curl") { "curl is available" } else { "curl not found" })
        },
        {
            component: "Internet Connectivity", 
            success: (test-internet-connectivity),
            message: (if (test-internet-connectivity) { "Internet connection working" } else { "No internet connection" })
        }
    ]
}

# Validate package management
export def validate-package-management [] {
    let brew_installed = (command-exists "brew")
    let brew_info = if $brew_installed {
        try {
            (brew --version | lines | first)
        } catch {
            "Version unknown"
        }
    } else {
        "Not installed"
    }
    
    [
        {
            component: "Homebrew",
            success: $brew_installed,
            message: $brew_info
        }
    ]
}

# Validate development tools
export def validate-development-tools [] {
    let dev_tools = verify-dev-tools
    
    $dev_tools | each { |tool|
        {
            component: $"Development Tool: ($tool.tool)",
            success: $tool.installed,
            message: (if $tool.installed { $tool.version } else { "Not installed" })
        }
    }
}

# Validate configurations
export def validate-configurations [] {
    let configs = verify-configurations
    
    $configs | each { |config|
        {
            component: $"Configuration: ($config.configuration)",
            success: $config.exists,
            message: (if $config.exists { $"Found at ($config.path)" } else { $"Missing: ($config.path)" })
        }
    }
}

# Validate environment
export def validate-environment [] {
    # Simplified environment validation
    
    [
        {
            component: "Shell Environment",
            success: true,
            message: $"Running ($env.SHELL | path basename)"
        },
        {
            component: "PATH Configuration",
            success: (validate-path-configuration),
            message: (if (validate-path-configuration) { "PATH includes expected directories" } else { "PATH missing expected directories" })
        },
        {
            component: "Nu Shell Scripts",
            success: (validate-nu-scripts),
            message: (if (validate-nu-scripts) { "Nu scripts accessible" } else { "Nu scripts not found or not accessible" })
        }
    ]
}

# Test internet connectivity
export def test-internet-connectivity [] {
    try {
        http get --max-time 5sec https://github.com | ignore
        true
    } catch {
        false
    }
}

# Validate PATH configuration
export def validate-path-configuration [] {
    let required_paths = [
        "/usr/local/bin",
        "/opt/homebrew/bin",  # For Apple Silicon Macs
        $"($env.HOME)/.cargo/bin"
    ]
    
    let current_path = ($env.PATH | str join ":")
    
    $required_paths | all { |path|
        ($current_path | str contains $path) or not ($path | path exists)
    }
}

# Validate Nu scripts  
export def validate-nu-scripts [] {
    let main_script = "scripts/nu-scripts/core/main.nu"
    ($main_script | path exists)
}

# Run specific validation
export def validate-component [component: string] {
    match $component {
        "system" => { validate-system-requirements },
        "packages" => { validate-package-management },
        "dev-tools" => { validate-development-tools },
        "config" => { validate-configurations },
        "environment" => { validate-environment },
        _ => { 
            log error $"Unknown component: ($component)"
            []
        }
    }
}

# Generate validation report
export def generate-validation-report [output_file?: string] {
    let results = validate-installation
    let timestamp = (date now | format date "%Y-%m-%d %H:%M:%S")
    
    print "# Installation Validation Report"
    print $"Generated: ($timestamp)"
    print ""
    print "## Summary"
    print $"Total Components Checked: (($results | length))"
    print $"Successful: (($results | where success == true | length))"
    print $"Failed: (($results | where success == false | length))"
    print ""
    print "## Detailed Results"
    
    $results | each { |item|
        let status = if $item.success { "PASS" } else { "FAIL" }
        print $"### ($item.component): ($status)"
        print $"($item.message)"
        print ""
    }
    
    print "## Next Steps"
    if (($results | where success == false | length) > 0) {
        print "Some components failed validation. Please review the failed items above and re-run the installation."
    } else {
        print "All components validated successfully! Your environment is ready for development."
    }
}

# Quick health check
export def quick-health-check [] {
    log info "Running quick health check..."
    
    let critical_tools = ["brew", "git", "curl"]
    mut issues = []
    
    for tool in $critical_tools {
        if not (command-exists $tool) {
            $issues = ($issues | append $"($tool) not found")
        }
    }
    
    if ($issues | is-empty) {
        log info "✅ Quick health check passed - all critical tools available"
    } else {
        log warning "⚠️  Quick health check found issues:"
        $issues | each { |issue| log warning $"  ($issue)" }
    }
}

# Benchmark installation performance
export def benchmark-tools [] {
    log info "⏱️  Benchmarking tool performance..."
    
    let tools = ["brew", "git", "node", "cargo", "kubectl"]
    
    $tools | each { |tool|
        if (command-exists $tool) {
            let start_time = (date now)
            try {
                ^$tool --version | ignore
                let end_time = (date now)
                let duration = (($end_time - $start_time) / 1000 / 1000) # Convert to milliseconds
                
                {
                    tool: $tool,
                    available: true,
                    response_time_ms: $duration
                }
            } catch {
                {
                    tool: $tool,
                    available: false,
                    response_time_ms: null
                }
            }
        } else {
            {
                tool: $tool,
                available: false,
                response_time_ms: null
            }
        }
    }
}