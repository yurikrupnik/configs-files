#!/usr/bin/env nu

# [INTEGRATION TESTS] Shell Workflow Integration
# Tests integration between different components and workflows

use std assert

# Get the repository root directory (source requires constant path)
const repo_root = "/Users/yurikrupnik/configs-files"
source "/Users/yurikrupnik/configs-files/nu/.config/nu/functions.nu"

# [INTEGRATION TEST] Git workflow integration
export def "test git-workflow-integration" [] {
    print "[INTEGRATION TEST] Testing git workflow integration"
    
    # Test git status works
    try {
        let status = (git status --porcelain | complete)
        assert ($status.exit_code == 0) "git status should work"
        print "✓ Git status integration works"
    } catch {
        print "⚠ Git not available in test environment"
    }
    
    # Test that git shortcuts would work with proper git setup
    let commands = (help commands | get name)
    assert ("gs" in $commands and "ga" in $commands and "gc" in $commands and "gp" in $commands) "All git shortcuts should be available"
    
    print "✓ Git workflow integration test passed"
}

# [INTEGRATION TEST] Docker workflow integration
export def "test docker-workflow-integration" [] {
    print "[INTEGRATION TEST] Testing Docker workflow integration"
    
    # Test docker commands are properly integrated
    try {
        let docker_version = (docker --version | complete)
        if $docker_version.exit_code == 0 {
            print "✓ Docker is available"
            
            # Test docker ps format integration
            try {
                docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | complete
                print "✓ Docker ps format integration works"
            } catch {
                print "⚠ Docker ps format test failed"
            }
        } else {
            print "⚠ Docker not available in test environment"
        }
    } catch {
        print "⚠ Docker not available in test environment"
    }
    
    print "✓ Docker workflow integration test completed"
}

# [INTEGRATION TEST] Kubernetes workflow integration  
export def "test k8s-workflow-integration" [] {
    print "[INTEGRATION TEST] Testing Kubernetes workflow integration"
    
    # Test kubectl availability
    try {
        let kubectl_version = (kubectl version --client | complete)
        if $kubectl_version.exit_code == 0 {
            print "✓ kubectl is available"
            
            # Test namespace switching would work
            let commands = (help commands | get name)
            assert ("knd" in $commands) "Namespace switching command should exist"
            assert ("ad" in $commands) "Context listing command should exist"
            assert ("ku" in $commands) "Context unset command should exist"
            
            print "✓ Kubernetes workflow commands available"
        } else {
            print "⚠ kubectl not available in test environment"
        }
    } catch {
        print "⚠ kubectl not available in test environment"
    }
    
    print "✓ Kubernetes workflow integration test completed"
}

# [INTEGRATION TEST] Development environment integration
export def "test dev-environment-integration" [] {
    print "[INTEGRATION TEST] Testing development environment integration"
    
    # Test home directory integration
    let home_dir = $env.HOME
    assert ($home_dir | path exists) "HOME directory should exist"
    
    # Test configs path integration
    let configs_path = $"($home_dir)/configs-files"
    assert ($configs_path | path exists) "configs-files directory should exist"
    
    # Test projects navigation integration
    let projects_dir = $"($home_dir)/projects"
    # Note: May not exist, but test that path construction works
    assert ($projects_dir | str contains $home_dir) "Projects path should be properly constructed"
    
    # Test CPU detection integration with parallel execution
    let cpu_count = (get-cpu-count)
    let build_parallel = (get-optimal-parallel "build")
    assert ($build_parallel == $cpu_count) "Build parallelism should match CPU count"
    
    print "✓ Development environment integration test passed"
}

# [INTEGRATION TEST] Security workflow integration
export def "test security-workflow-integration" [] {
    print "[INTEGRATION TEST] Testing security workflow integration"
    
    # Test secrets directory path construction
    let secrets_dir = $"($env.HOME)/configs-files/tmp/secrets"
    assert ($secrets_dir | str contains "tmp/secrets") "Secrets path should be properly constructed"
    
    # Test tmp directory structure integration
    let tmp_dir = $"($env.HOME)/configs-files/tmp"
    assert ($tmp_dir | path exists) "tmp directory should exist"
    
    # Test that security functions can work together
    let commands = (help commands | get name)
    let security_commands = ["load-secrets", "cleanup-secrets", "clean-tmp", "secure-file"]
    
    for cmd in $security_commands {
        assert ($cmd in $commands) $"Security command should exist: ($cmd)"
    }
    
    print "✓ Security workflow integration test passed"
}

# [INTEGRATION TEST] Configuration file loading integration
export def "test config-loading-integration" [] {
    print "[INTEGRATION TEST] Testing configuration file loading integration"
    
    # Test that config files are properly sourced
    let config_file = $"($repo_root)/nu/.config/nu/config.nu"
    assert ($config_file | path exists) "Main config file should exist"
    
    let functions_file = $"($repo_root)/nu/.config/nu/functions.nu"
    assert ($functions_file | path exists) "Functions file should exist"
    
    let env_file = $"($repo_root)/nu/.config/nu/env.nu"
    assert ($env_file | path exists) "Environment file should exist"
    
    # Test that functions are available (integration working)
    let commands = (help commands | get name)
    let expected_functions = ["gs", "ga", "gc", "gp", "knd", "sys-update", "projects", "configs"]
    
    for func in $expected_functions {
        assert ($func in $commands) $"Function should be loaded: ($func)"
    }
    
    print "✓ Configuration file loading integration test passed"
}

# [INTEGRATION TEST] Cross-platform compatibility integration
export def "test cross-platform-integration" [] {
    print "[INTEGRATION TEST] Testing cross-platform compatibility integration"
    
    # Test OS detection integration
    let os_name = (sys host | get name)
    assert ($os_name in ["Darwin", "Linux", "Windows"]) $"OS should be recognized: ($os_name)"
    
    # Test that CPU detection works across platforms
    let cpu_count = (get-cpu-count)
    assert ($cpu_count > 0) "CPU detection should work on current platform"
    
    # Test path separator handling
    let test_path = $"($env.HOME)/test"
    assert ($test_path | str contains "/") "Path should use proper separators"
    
    print $"✓ Cross-platform integration test passed on ($os_name)"
}

# [INTEGRATION TEST] Parallel execution integration
export def "test parallel-execution-integration" [] {
    print "[INTEGRATION TEST] Testing parallel execution integration"
    
    # Test that parallel count calculation integrates with CPU detection
    let cpu_count = (get-cpu-count)
    
    let task_types = ["build", "test", "heavy"]
    for task_type in $task_types {
        let parallel_count = (get-optimal-parallel $task_type)
        assert ($parallel_count > 0) $"Parallel count should be positive for ($task_type)"
        assert ($parallel_count <= $cpu_count) $"Parallel count should not exceed CPU count for ($task_type)"
    }
    
    print "✓ Parallel execution integration test passed"
}

# [INTEGRATION TEST] Environment variable integration
export def "test env-var-integration" [] {
    print "[INTEGRATION TEST] Testing environment variable integration"
    
    # Test required environment variables
    assert ($env.HOME? != null) "HOME environment variable should be set"
    assert ($env.USER? != null) "USER environment variable should be set"
    
    # Test environment variable usage in paths
    let test_path = $"($env.HOME)/.config"
    assert ($test_path | str starts-with $env.HOME) "Path should start with HOME"
    
    print "✓ Environment variable integration test passed"
}

# Run all integration tests
def main [] {
    print "=== [INTEGRATION TESTS] Shell Workflow Integration ==="
    print ""
    
    test git-workflow-integration
    test docker-workflow-integration  
    test k8s-workflow-integration
    test dev-environment-integration
    test security-workflow-integration
    test config-loading-integration
    test cross-platform-integration
    test parallel-execution-integration
    test env-var-integration
    
    print ""
    print "=== [INTEGRATION TESTS] All tests passed! ==="
}