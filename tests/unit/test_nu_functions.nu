#!/usr/bin/env nu

# [UNIT TESTS] Nu Shell Functions Test Suite
# Tests individual function behavior in isolation

use std assert

# Source the functions to test
source ../../nu/.config/nu/functions.nu

# [UNIT TEST] get-cpu-count function
export def "test get-cpu-count" [] {
    print "[UNIT TEST] Testing get-cpu-count function"
    
    let cpu_count = (get-cpu-count)
    
    assert ($cpu_count > 0) "CPU count should be greater than 0"
    assert ($cpu_count <= 256) "CPU count should be reasonable (<=256)"
    assert (($cpu_count | describe) == "int") "CPU count should be an integer"
    
    print $"✓ get-cpu-count returned valid value: ($cpu_count)"
}

# [UNIT TEST] get-optimal-parallel function
export def "test get-optimal-parallel" [] {
    print "[UNIT TEST] Testing get-optimal-parallel function"
    
    let build_parallel = (get-optimal-parallel "build")
    let test_parallel = (get-optimal-parallel "test") 
    let heavy_parallel = (get-optimal-parallel "heavy")
    let default_parallel = (get-optimal-parallel "unknown")
    
    assert ($build_parallel > 0) "Build parallel count should be positive"
    assert ($test_parallel > 0) "Test parallel count should be positive"
    assert ($heavy_parallel > 0) "Heavy parallel count should be positive"
    assert ($default_parallel > 0) "Default parallel count should be positive"
    
    # Test relative sizing
    assert ($test_parallel <= $build_parallel) "Test parallel should be <= build parallel"
    assert ($heavy_parallel <= $build_parallel) "Heavy parallel should be <= build parallel"
    
    print $"✓ get-optimal-parallel build: ($build_parallel), test: ($test_parallel), heavy: ($heavy_parallel)"
}

# [UNIT TEST] Security functions existence
export def "test security-functions-exist" [] {
    print "[UNIT TEST] Testing security functions exist"
    
    let commands = (help commands | get name)
    
    assert ("load-secrets" in $commands) "load-secrets command should exist"
    assert ("cleanup-secrets" in $commands) "cleanup-secrets command should exist"
    assert ("clean-tmp" in $commands) "clean-tmp command should exist"
    assert ("secure-file" in $commands) "secure-file command should exist"
    
    print "✓ All security functions exist"
}

# [UNIT TEST] Git command shortcuts exist
export def "test git-shortcuts-exist" [] {
    print "[UNIT TEST] Testing git shortcuts exist"
    
    let commands = (help commands | get name)
    
    assert ("gs" in $commands) "gs (git status) command should exist"
    assert ("ga" in $commands) "ga (git add) command should exist" 
    assert ("gc" in $commands) "gc (git commit) command should exist"
    assert ("gp" in $commands) "gp (git push) command should exist"
    
    print "✓ All git shortcuts exist"
}

# [UNIT TEST] Kubernetes shortcuts exist
export def "test k8s-shortcuts-exist" [] {
    print "[UNIT TEST] Testing Kubernetes shortcuts exist"
    
    let commands = (help commands | get name)
    
    assert ("knd" in $commands) "knd (kubectl namespace) command should exist"
    assert ("ad" in $commands) "ad (show contexts) command should exist"
    assert ("ku" in $commands) "ku (unset context) command should exist"
    assert ("kc" in $commands) "kc (create cluster) command should exist"
    
    print "✓ All Kubernetes shortcuts exist"
}

# [UNIT TEST] Development workflow functions exist
export def "test dev-workflow-functions-exist" [] {
    print "[UNIT TEST] Testing development workflow functions exist"
    
    let commands = (help commands | get name)
    
    assert ("sys-update" in $commands) "sys-update command should exist"
    assert ("nx-run" in $commands) "nx-run command should exist"
    assert ("nx-runa" in $commands) "nx-runa command should exist"
    assert ("projects" in $commands) "projects command should exist"
    assert ("configs" in $commands) "configs command should exist"
    
    print "✓ All development workflow functions exist"
}

# [UNIT TEST] Docker helper functions exist
export def "test docker-helpers-exist" [] {
    print "[UNIT TEST] Testing Docker helper functions exist"
    
    let commands = (help commands | get name)
    
    assert ("dps" in $commands) "dps (docker ps) command should exist"
    assert ("dclean" in $commands) "dclean (docker clean) command should exist"
    assert ("psg" in $commands) "psg (process grep) command should exist"
    
    print "✓ All Docker helper functions exist"
}

# Run all unit tests
def main [] {
    print "=== [UNIT TESTS] Nu Shell Functions ==="
    print ""
    
    test get-cpu-count
    test get-optimal-parallel
    test security-functions-exist
    test git-shortcuts-exist
    test k8s-shortcuts-exist
    test dev-workflow-functions-exist
    test docker-helpers-exist
    
    print ""
    print "=== [UNIT TESTS] All tests passed! ==="
}