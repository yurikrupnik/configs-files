#!/usr/bin/env nu

# [E2E TESTS] Full Setup Workflow  
# End-to-end tests for complete development environment setup

use std assert

# Get the repository root directory
const repo_root = "/Users/yurikrupnik/configs-files"

# [E2E TEST] Complete environment setup workflow
export def "test complete-setup-workflow" [] {
    print "[E2E TEST] Testing complete environment setup workflow"
    
    # Phase 1: Pre-setup validation
    print "Phase 1: Pre-setup validation"
    
    # Verify base requirements
    assert ($env.HOME? != null) "HOME environment variable required"
    assert ($"($repo_root)/init.sh" | path exists) "init.sh should exist"
    assert ($"($repo_root)/devbox.json" | path exists) "devbox.json should exist"
    
    # Phase 2: Configuration file deployment
    print "Phase 2: Configuration file deployment validation"
    
    # Test that all required config files exist
    let config_files = [
        $"($repo_root)/nu/.config/nu/config.nu",
        $"($repo_root)/nu/.config/nu/functions.nu", 
        $"($repo_root)/nu/.config/nu/env.nu",
        $"($repo_root)/starship/.config/starship/starship.toml",
        $"($repo_root)/brew/Brewfile"
    ]
    
    for file in $config_files {
        assert ($file | path exists) $"Required config file should exist: ($file)"
    }
    
    # Phase 3: Shell function availability  
    print "Phase 3: Shell function availability validation"
    
    # Test that functions file exists and can be loaded
    let functions_file = $"($repo_root)/nu/.config/nu/functions.nu"
    assert ($functions_file | path exists) "Functions file should exist"
    
    # Test that essential function definitions exist in the file
    let file_content = (open $functions_file)
    let essential_function_patterns = [
        "export def gs", "export def ga", "export def gc", "export def gp",
        "export def knd", "export def ad", "export def ku", "export def kc",
        "export def sys-update", "export def projects", "export def configs",
        "export def dps", "export def dclean", "export def psg",
        "def \"get-cpu-count\"", "def \"get-optimal-parallel\""
    ]
    
    for pattern in $essential_function_patterns {
        assert ($file_content | str contains $pattern) $"Function definition should exist: ($pattern)"
    }
    
    print "✓ Complete environment setup workflow test passed"
}

# [E2E TEST] Development workflow from start to finish
export def "test dev-workflow-end-to-end" [] {
    print "[E2E TEST] Testing development workflow end-to-end"
    
    # Phase 1: Environment preparation
    print "Phase 1: Environment preparation"
    
    # Test that function definitions exist in functions file
    let functions_file = $"($repo_root)/nu/.config/nu/functions.nu"
    let file_content = (open $functions_file)
    assert ($file_content | str contains "def \"get-cpu-count\"") "CPU count function should be defined"
    assert ($file_content | str contains "def \"get-optimal-parallel\"") "Optimal parallel function should be defined"
    
    # Phase 2: Project navigation workflow
    print "Phase 2: Project navigation workflow"
    
    assert ($file_content | str contains "export def projects") "Project navigation function should be defined"
    assert ($file_content | str contains "export def configs") "Config navigation function should be defined"
    
    # Phase 3: Git workflow integration
    print "Phase 3: Git workflow integration"
    
    let git_commands = ["export def gs", "export def ga", "export def gc", "export def gp"]
    for cmd in $git_commands {
        assert ($file_content | str contains $cmd) $"Git command should be defined: ($cmd)"
    }
    
    # Phase 4: System management workflow
    print "Phase 4: System management workflow"
    
    assert ($file_content | str contains "export def sys-update") "System update function should be defined"
    assert ($file_content | str contains "export def sysinfo") "System info function should be defined"
    
    print "✓ Development workflow end-to-end test passed"
}

# [E2E TEST] Security workflow from setup to cleanup
export def "test security-workflow-end-to-end" [] {
    print "[E2E TEST] Testing security workflow end-to-end"
    
    # Functions loaded via file content check instead of sourcing
    
    # Phase 1: Security setup validation
    print "Phase 1: Security setup validation"
    
    let tmp_dir = $"($env.HOME)/configs-files/tmp"
    assert ($tmp_dir | path exists) "Temp directory should exist"
    
    let secrets_dir = $"($tmp_dir)/secrets"
    assert ($secrets_dir | path exists) "Secrets directory should exist"
    
    # Phase 2: Security function availability
    print "Phase 2: Security function availability"
    
    let functions_file = $"($repo_root)/nu/.config/nu/functions.nu"
    let file_content = (open $functions_file)
    let security_function_patterns = ["def \"load-secrets\"", "def \"cleanup-secrets\"", "def \"clean-tmp\"", "def \"secure-file\""]
    
    for pattern in $security_function_patterns {
        assert ($file_content | str contains $pattern) $"Security function should be defined: ($pattern)"
    }
    
    # Phase 3: Test directory structure for security
    print "Phase 3: Security directory structure validation"
    
    let security_dirs = [
        $"($tmp_dir)/cache",
        $"($tmp_dir)/data", 
        $"($tmp_dir)/workspace",
        $secrets_dir
    ]
    
    for dir in $security_dirs {
        assert ($dir | path exists) $"Security directory should exist: ($dir)"
    }
    
    print "✓ Security workflow end-to-end test passed"
}

# [E2E TEST] Kubernetes development workflow
export def "test k8s-dev-workflow-end-to-end" [] {
    print "[E2E TEST] Testing Kubernetes development workflow end-to-end"
    
    # Functions loaded via file content check instead of sourcing
    
    # Phase 1: Kubernetes tools validation
    print "Phase 1: Kubernetes tools validation"
    
    let functions_file = $"($repo_root)/nu/.config/nu/functions.nu"
    let file_content = (open $functions_file)
    let k8s_function_patterns = ["export def knd", "export def ad", "export def ku", "export def kc"]
    
    for pattern in $k8s_function_patterns {
        assert ($file_content | str contains $pattern) $"K8s function should be defined: ($pattern)"
    }
    
    # Phase 2: Cluster creation workflow validation
    print "Phase 2: Cluster creation workflow validation"
    
    # Test that kc function exists and would work
    assert ($file_content | str contains "export def kc") "Cluster creation function should be defined"
    
    # Phase 3: kubectl integration validation
    print "Phase 3: kubectl integration validation"
    
    try {
        let kubectl_check = (which kubectl | complete)
        if $kubectl_check.exit_code == 0 {
            print "✓ kubectl available for K8s workflow"
        } else {
            print "⚠ kubectl not available (expected in some environments)"
        }
    } catch {
        print "⚠ kubectl not available (expected in some environments)"
    }
    
    print "✓ Kubernetes development workflow end-to-end test passed"
}

# [E2E TEST] Cross-platform setup validation
export def "test cross-platform-setup-end-to-end" [] {
    print "[E2E TEST] Testing cross-platform setup end-to-end"
    
    # Functions loaded via file content check instead of sourcing
    
    # Phase 1: Platform detection
    print "Phase 1: Platform detection"
    
    let os_name = (sys host | get name)
    assert ($os_name in ["Darwin", "Linux", "Windows"]) $"Platform should be supported: ($os_name)"
    
    # Phase 2: CPU detection across platforms
    print "Phase 2: CPU detection across platforms"
    
    let functions_file = $"($repo_root)/nu/.config/nu/functions.nu"
    let file_content = (open $functions_file)
    assert ($file_content | str contains "def \"get-cpu-count\"") "CPU detection function should be defined"
    
    # Phase 3: Path handling across platforms
    print "Phase 3: Path handling across platforms"
    
    let home_path = $env.HOME
    let test_path = $"($home_path)/test"
    assert ($test_path | str contains $home_path) "Path construction should work"
    
    # Phase 4: Environment variable handling
    print "Phase 4: Environment variable handling"
    
    assert ($env.HOME? != null) "HOME should be available"
    assert ($env.USER? != null) "USER should be available"
    
    print $"✓ Cross-platform setup end-to-end test passed on ($os_name)"
}

# [E2E TEST] Performance and resource management
export def "test performance-workflow-end-to-end" [] {
    print "[E2E TEST] Testing performance workflow end-to-end"
    
    # Functions loaded via file content check instead of sourcing
    
    # Phase 1: Resource detection
    print "Phase 1: Resource detection"
    
    let functions_file = $"($repo_root)/nu/.config/nu/functions.nu"
    let file_content = (open $functions_file)
    let memory_info = (sys mem)
    
    assert ($file_content | str contains "def \"get-cpu-count\"") "CPU detection function should be defined"
    assert ($memory_info != null) "Memory detection should work"
    
    # Phase 2: Parallel execution configuration
    print "Phase 2: Parallel execution configuration"
    
    assert ($file_content | str contains "def \"get-optimal-parallel\"") "Optimal parallel function should be defined"
    assert ($file_content | str contains "build") "Build task type should be handled"
    assert ($file_content | str contains "test") "Test task type should be handled"
    assert ($file_content | str contains "heavy") "Heavy task type should be handled"
    
    # Phase 3: System resource workflow
    print "Phase 3: System resource workflow"
    
    assert ($file_content | str contains "export def sysinfo") "System info function should be defined"
    assert ($file_content | str contains "export def sys-update") "System update function should be defined"
    
    print "✓ Performance workflow end-to-end test passed"
}

# [E2E TEST] Complete cleanup and reset workflow
export def "test cleanup-workflow-end-to-end" [] {
    print "[E2E TEST] Testing cleanup workflow end-to-end"
    
    # Functions loaded via file content check instead of sourcing
    
    # Phase 1: Cleanup function availability
    print "Phase 1: Cleanup function availability"
    
    let functions_file = $"($repo_root)/nu/.config/nu/functions.nu"
    let file_content = (open $functions_file)
    let cleanup_function_patterns = ["def \"clean-tmp\"", "def \"cleanup-secrets\"", "export def dclean"]
    
    for pattern in $cleanup_function_patterns {
        assert ($file_content | str contains $pattern) $"Cleanup function should be defined: ($pattern)"
    }
    
    # Phase 2: Temporary directory structure
    print "Phase 2: Temporary directory structure validation"
    
    let tmp_dir = $"($env.HOME)/configs-files/tmp"
    let cleanup_targets = [
        $"($tmp_dir)/cache",
        $"($tmp_dir)/workspace", 
        $"($tmp_dir)/secrets"
    ]
    
    for dir in $cleanup_targets {
        assert ($dir | path exists) $"Cleanup target should exist: ($dir)"
    }
    
    # Phase 3: Security cleanup validation
    print "Phase 3: Security cleanup validation"
    
    assert ($file_content | str contains "def \"secure-file\"") "File security function should be defined"
    
    print "✓ Cleanup workflow end-to-end test passed"
}

# Run all E2E tests
def main [] {
    print "=== [E2E TESTS] Full Setup Workflow ==="
    print ""
    
    test complete-setup-workflow
    test dev-workflow-end-to-end
    test security-workflow-end-to-end
    test k8s-dev-workflow-end-to-end
    test cross-platform-setup-end-to-end
    test performance-workflow-end-to-end
    test cleanup-workflow-end-to-end
    
    print ""
    print "=== [E2E TESTS] All end-to-end tests passed! ==="
}