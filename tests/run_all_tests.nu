#!/usr/bin/env nu

# Test Suite Runner
# Runs all test types in sequence with proper labeling

def main [
    --type: string = "all"  # Test type: unit, function, integration, e2e, or all
    --verbose = false # Verbose output
] {
    print "=== Configs-Files Test Suite Runner ==="
    print $"Running tests: ($type)"
    print ""
    
    let start_time = (date now)
    mut passed_tests = 0
    mut failed_tests = 0
    
    # [UNIT TESTS]
    if $type == "all" or $type == "unit" {
        print "🧪 Running [UNIT TESTS]..."
        let result = (do { nu unit/test_nu_functions.nu } | complete)
        if $result.exit_code == 0 {
            $passed_tests = ($passed_tests + 1)
            print "✅ [UNIT TESTS] PASSED\n"
        } else {
            print "❌ [UNIT TESTS] FAILED\n"
            $failed_tests = ($failed_tests + 1)
        }
    }
    
    # [FUNCTION TESTS]
    if $type == "all" or $type == "function" {
        print "⚙️ Running [FUNCTION TESTS]..."
        let result1 = (do { nu functions/test_individual_functions.nu } | complete)
        let result2 = (do { nu functions/test_bash_scripts.nu } | complete)
        if $result1.exit_code == 0 and $result2.exit_code == 0 {
            $passed_tests = ($passed_tests + 2)
            print "✅ [FUNCTION TESTS] PASSED\n"
        } else {
            print "❌ [FUNCTION TESTS] FAILED\n"
            $failed_tests = ($failed_tests + 1)
        }
    }
    
    # [INTEGRATION TESTS]
    if $type == "all" or $type == "integration" {
        print "🔗 Running [INTEGRATION TESTS]..."
        let result = (do { nu integration/test_shell_workflows.nu } | complete)
        if $result.exit_code == 0 {
            $passed_tests = ($passed_tests + 1)
            print "✅ [INTEGRATION TESTS] PASSED\n"
        } else {
            print "❌ [INTEGRATION TESTS] FAILED\n"
            $failed_tests = ($failed_tests + 1)
        }
    }
    
    # [E2E TESTS]
    if $type == "all" or $type == "e2e" {
        print "🎯 Running [E2E TESTS]..."
        let result = (do { nu e2e/test_full_setup_workflow.nu } | complete)
        if $result.exit_code == 0 {
            $passed_tests = ($passed_tests + 1)
            print "✅ [E2E TESTS] PASSED\n"
        } else {
            print "❌ [E2E TESTS] FAILED\n"
            $failed_tests = ($failed_tests + 1)
        }
    }
    
    let end_time = (date now)
    let duration = ($end_time - $start_time)
    
    print "=== Test Suite Summary ==="
    print $"✅ Passed: ($passed_tests)"
    print $"❌ Failed: ($failed_tests)"
    print $"⏱️  Duration: ($duration)"
    print ""
    
    if $failed_tests == 0 {
        print "🎉 All tests passed!"
        exit 0
    } else {
        print "💥 Some tests failed!"
        exit 1
    }
}