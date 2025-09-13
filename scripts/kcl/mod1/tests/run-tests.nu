#!/usr/bin/env nu

# KCL PostgreSQL Function Test Runner (Nu Shell)
# Enhanced version with better formatting and output

use std log

# Configuration and command line parsing
def main [
    --mode: string = "all"          # all, basic, integration, scenarios, performance
    --namespace: string = "default" # Target namespace 
    --type: string = "local"        # local, cluster, both
    --verbose: bool = false         # Verbose output
    --help: bool = false           # Show help
] {
    if $help {
        show_help
        return
    }
    
    if $verbose {
        $env.LOG_LEVEL = "DEBUG"
    }
    
    print_header "KCL PostgreSQL Function Test Runner" $"Mode: ($mode) | Type: ($type) | Namespace: ($namespace)"
    
    # Check prerequisites
    check_prerequisites $type
    
    # Run tests based on type
    let result = match $type {
        "local" => { 
            if $mode == "performance" {
                run_performance_tests
            } else {
                run_local_tests $mode $namespace
            }
        }
        "cluster" => { run_cluster_tests $mode }
        "both" => {
            print ""
            log info "Running both local and cluster tests..."
            print ""
            
            let local_result = if $mode == "performance" {
                run_performance_tests
            } else {
                run_local_tests $mode $namespace
            }
            
            print ""
            let cluster_result = run_cluster_tests $mode
            
            $local_result and $cluster_result
        }
        _ => {
            log error $"Invalid type: ($type)"
            show_help
            false
        }
    }
    
    # Final status
    print ""
    if $result {
        print_success "All tests completed successfully! 🎉"
    } else {
        print_error "Some tests failed. Check the output above."
        exit 1
    }
}

# Enhanced output formatting
def print_header [title: string, subtitle: string = ""] {
    let separator = ("=" | str repeat ($title | str length))
    print $"🚀 ($title)"
    print $separator
    if ($subtitle | str length) > 0 {
        print $subtitle
    }
    print ""
}

def print_success [message: string] {
    print $"(ansi green)✅ ($message)(ansi reset)"
}

def print_error [message: string] {
    print $"(ansi red)❌ ($message)(ansi reset)"
}

def print_warning [message: string] {
    print $"(ansi yellow)⚠️  ($message)(ansi reset)"
}

def print_info [message: string] {
    print $"(ansi blue)ℹ️  ($message)(ansi reset)"
}

def print_section [title: string] {
    print ""
    print $"(ansi purple)## ($title)(ansi reset)"
    print $"(ansi purple)(("=" | str repeat ($title | str length)))(ansi reset)"
}

# Show help information
def show_help [] {
    print "Usage: nu run-tests.nu [OPTIONS]"
    print ""
    print "Options:"
    print "  --mode MODE          Test mode: all, basic, integration, scenarios, performance"
    print "  --namespace NS       Target namespace (default: default)"
    print "  --type TYPE          Test type: local, cluster, both (default: local)"
    print "  --verbose           Verbose output"
    print "  --help              Show this help message"
    print ""
    print "Examples:"
    print "  nu run-tests.nu                           # Run all local tests"
    print "  nu run-tests.nu --mode basic              # Run only basic tests"  
    print "  nu run-tests.nu --type cluster            # Run cluster tests only"
    print "  nu run-tests.nu --mode scenarios --verbose # Run scenarios with verbose output"
    print ""
}

# Check prerequisites
def check_prerequisites [test_type: string] {
    print_info "Checking prerequisites..."
    
    # Check KCL
    if not (which kcl | is-empty) {
        print_success "KCL found"
    } else {
        print_error "KCL is not installed or not in PATH"
        exit 1
    }
    
    # Check for cluster requirements
    if $test_type == "cluster" or $test_type == "both" {
        if not (which kubectl | is-empty) {
            print_success "kubectl found"
        } else {
            print_error "kubectl is not installed (required for cluster tests)"
            exit 1
        }
        
        # Check cluster connectivity
        let cluster_check = (^kubectl cluster-info | complete)
        if $cluster_check.exit_code == 0 {
            print_success "Kubernetes cluster connectivity verified"
        } else {
            print_error "Cannot connect to Kubernetes cluster"
            exit 1
        }
    }
    
    # Check if we're in the right directory
    if not ("main.k" | path exists) or not ("kcl.mod" | path exists) {
        print_error "Not in a KCL module directory (main.k or kcl.mod missing)"
        exit 1
    }
    
    print_success "Prerequisites check passed"
}

# Load test scenarios
def load_test_scenarios [] {
    let scenarios_file = "tests/shared/test-scenarios.yaml"
    if ($scenarios_file | path exists) {
        open $scenarios_file
    } else {
        {
            scenarios: {
                basic: [
                    {name: "dev-postgres-small", size: "small", expected: {instances: 1, storage: "1Gi"}},
                    {name: "staging-postgres-medium", size: "medium", expected: {instances: 3, storage: "3Gi"}},
                    {name: "prod-postgres-large", size: "large", expected: {instances: 6, storage: "6Gi"}}
                ],
                edge_cases: [
                    {name: "test-with-special-chars", size: "small", expected: {instances: 1, storage: "1Gi"}},
                    {name: "very-long-name-test", size: "medium", expected: {instances: 3, storage: "3Gi"}}
                ]
            },
            namespaces: ["default", "production", "staging", "development"]
        }
    }
}

# Run KCL test
def run_kcl_test [params: record] {
    let result = (^kcl run . -D $"params=($params | to json)" | complete)
    return {
        exit_code: $result.exit_code,
        stdout: $result.stdout,
        stderr: $result.stderr
    }
}

# Assert that output contains pattern
def assert_contains [text: string, pattern: string, test_name: string] {
    if ($text | str contains $pattern) {
        print_success $"($test_name)"
        return true
    } else {
        print_error $"($test_name) - Expected pattern not found: ($pattern)"
        return false
    }
}

# Test specific scenario
def test_scenario [scenario: record, namespace: string = "default"] {
    print_info $"🔬 Testing scenario: ($scenario.name)"
    
    let params = {
        oxr: {
            metadata: {
                name: $scenario.name,
                namespace: $namespace
            },
            spec: { size: $scenario.size }
        },
        ocds: {}
    }
    
    let result = (run_kcl_test $params)
    
    if $result.exit_code != 0 {
        print_error $"Scenario failed: ($result.stderr)"
        return false
    }
    
    let output = $result.stdout
    
    # Basic resource validation
    let has_cluster = ($output | str contains "kind: Cluster")
    let has_secret = ($output | str contains "kind: Object")
    
    if not ($has_cluster and $has_secret) {
        print_error "Missing expected resources (Cluster or Object)"
        return false
    }
    
    # Size-specific validation
    if "expected" in $scenario {
        let instances_valid = ($output | str contains $"instances: ($scenario.expected.instances)")
        let storage_valid = ($output | str contains $"size: '($scenario.expected.storage)'")
        
        if not ($instances_valid and $storage_valid) {
            print_error $"Size configuration mismatch for ($scenario.size)"
            return false
        }
        
        print_success $"($scenario.name) validated"
    }
    
    return true
}

# Run local tests
def run_local_tests [mode: string, namespace: string] {
    print_section "Local KCL Function Tests"
    
    let config = (load_test_scenarios)
    mut test_results = []
    mut test_count = 0
    
    # Basic integration tests
    if $mode == "all" or $mode == "basic" or $mode == "integration" {
        print_info "Running basic integration tests..."
        
        for size in ["small", "medium", "large"] {
            let expected = match $size {
                "small" => {instances: 1, storage: "1Gi"}
                "medium" => {instances: 3, storage: "3Gi"}  
                "large" => {instances: 6, storage: "6Gi"}
            }
            
            $test_count += 1
            let scenario = {name: $"test-($size)", size: $size, expected: $expected}
            $test_results = ($test_results | append (test_scenario $scenario $namespace))
        }
        print ""
    }
    
    # Scenario-based tests
    if $mode == "all" or $mode == "scenarios" {
        print_info "Running scenario-based tests..."
        
        # Basic scenarios
        for scenario in $config.scenarios.basic {
            $test_count += 1
            $test_results = ($test_results | append (test_scenario $scenario $namespace))
        }
        
        # Edge case scenarios
        if "edge_cases" in $config.scenarios {
            for scenario in $config.scenarios.edge_cases {
                $test_count += 1
                $test_results = ($test_results | append (test_scenario $scenario $namespace))
            }
        }
        print ""
    }
    
    # Multi-namespace tests
    if $mode == "all" {
        print_info "Running multi-namespace tests..."
        
        for ns in $config.namespaces {
            if $ns != $namespace {
                $test_count += 1
                let scenario = {name: $"test-db-($ns)", size: "small", expected: {instances: 1, storage: "1Gi"}}
                $test_results = ($test_results | append (test_scenario $scenario $ns))
            }
        }
        print ""
    }
    
    # Generate detailed report
    generate_test_report $test_results $test_count
}

# Run cluster tests  
def run_cluster_tests [mode: string] {
    print_section "Cluster Tests"
    
    mut cluster_success = true
    
    # Check for Chainsaw
    if not (which chainsaw | is-empty) {
        print_info "Running Chainsaw tests..."
        if ("tests/cluster/chainsaw-tests.yaml" | path exists) {
            let chainsaw_result = (^chainsaw test --test-file tests/cluster/chainsaw-tests.yaml | complete)
            if $chainsaw_result.exit_code == 0 {
                print_success "Chainsaw tests passed"
            } else {
                print_error "Chainsaw tests failed"
                $cluster_success = false
            }
        } else {
            print_warning "Chainsaw test file not found, skipping..."
        }
    } else {
        print_warning "Chainsaw not found, skipping resource validation tests"
    }
    
    # Check for Testkube
    let testkube_check = (^kubectl get deployment testkube-api-server -n testkube | complete)
    if $testkube_check.exit_code == 0 {
        print_info "Running Testkube tests..."
        run_testkube_tests
    } else {
        print_info "Testkube not installed, skipping Testkube tests"
        print_info "Run './deploy-testkube.sh' to set up Testkube testing"
    }
    
    return $cluster_success
}

# Run Testkube tests
def run_testkube_tests [] {
    let testkube_plugin_check = (^kubectl testkube version | complete)
    if $testkube_plugin_check.exit_code == 0 {
        print_info "Running Testkube test suite..."
        ^kubectl testkube run testsuite kcl-test-suite -n testkube --watch
    } else {
        print_warning "kubectl testkube plugin not found"
        print_info "Install with: kubectl krew install testkube"
    }
}

# Performance tests
def run_performance_tests [] {
    print_section "Performance Tests"
    
    let iterations = 10
    mut times = []
    
    print_info $"Running ($iterations) performance test iterations..."
    
    for i in 1..$iterations {
        let start_time = (date now)
        
        let result = (^kcl run . -D 'params={"oxr": {"metadata": {"name": "perf-test", "namespace": "default"}, "spec": {"size": "medium"}}, "ocds": {}}' | complete)
        
        let end_time = (date now)
        let duration = ($end_time - $start_time)
        $times = ($times | append $duration)
        
        print_info $"Iteration ($i): ($duration | into duration --unit ms)"
    }
    
    let avg_time = ($times | math avg)
    let min_time = ($times | math min) 
    let max_time = ($times | math max)
    
    print ""
    print_success "Performance test completed"
    print $"   Average execution time: ($avg_time | into duration --unit ms)"
    print $"   Min execution time: ($min_time | into duration --unit ms)"
    print $"   Max execution time: ($max_time | into duration --unit ms)"
    
    return true
}

# Generate comprehensive test report
def generate_test_report [results: list<bool>, total_count: int] {
    let passed_count = ($results | where $it == true | length)
    let failed_count = ($total_count - $passed_count)
    let pass_rate = if $total_count > 0 { ($passed_count * 100 / $total_count) } else { 0 }
    
    print ""
    print_section "Test Results Summary"
    print $"   Total tests: ($total_count)"
    print $"   ✅ Passed: ($passed_count)"
    print $"   ❌ Failed: ($failed_count)"
    print $"   📊 Pass rate: ($pass_rate)%"
    
    if $failed_count == 0 {
        return true
    } else {
        return false
    }
}
