#!/usr/bin/env nu

# KCL PostgreSQL Function Local Tests
# Organized version combining integration-test.nu and e2e-test.nu

use std log

# Load test scenarios from shared config
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
                ]
            },
            namespaces: ["default", "production", "staging"]
        }
    }
}

# Run KCL with parameters and return structured result
def run_kcl_test [params: record] {
    let result = (^kcl run . -D $"params=($params | to json)" | complete)
    return {
        exit_code: $result.exit_code,
        stdout: $result.stdout,
        stderr: $result.stderr
    }
}

# Assert that text contains pattern
def assert_contains [text: string, pattern: string, test_name: string] {
    if ($text | str contains $pattern) {
        log info $"✓ PASS: ($test_name)"
        return true
    } else {
        log error $"✗ FAIL: ($test_name) - Expected pattern not found: ($pattern)"
        return false
    }
}

# Test size configuration
def test_size_configuration [size: string, expected_instances: int, expected_storage: string] {
    let params = {
        oxr: {
            metadata: { name: $"test-($size)", namespace: "default" },
            spec: { size: $size }
        },
        ocds: {}
    }
    
    log info $"Testing size configuration: ($size)"
    let result = (run_kcl_test $params)
    
    if $result.exit_code != 0 {
        log error $"✗ FAIL: ($size) configuration - Command failed"
        log error $result.stderr
        return false
    }
    
    let output = $result.stdout
    let instances_test = (assert_contains $output $"instances: ($expected_instances)" $"($size) instance count")
    let storage_test = (assert_contains $output $"size: '($expected_storage)'" $"($size) storage size")
    
    return ($instances_test and $storage_test)
}

# Test resource creation and structure
def test_resource_creation [] {
    let params = {
        oxr: {
            metadata: { name: "test-resources", namespace: "default" },
            spec: { size: "small" }
        },
        ocds: {}
    }
    
    log info "Testing resource creation and structure"
    let result = (run_kcl_test $params)
    
    if $result.exit_code != 0 {
        log error "✗ FAIL: Resource creation test - Command failed"
        log error $result.stderr
        return false
    }
    
    let output = $result.stdout
    let cluster_test = (assert_contains $output "apiVersion: postgresql.cnpg.io/v1" "PostgreSQL cluster API version")
    let cluster_kind_test = (assert_contains $output "kind: Cluster" "PostgreSQL cluster kind")
    let secret_test = (assert_contains $output "apiVersion: kubernetes.m.crossplane.io/v1alpha1" "Secret object API version")
    let secret_kind_test = (assert_contains $output "kind: Object" "Secret object kind")
    
    return ($cluster_test and $cluster_kind_test and $secret_test and $secret_kind_test)
}

# Test naming and annotations
def test_naming_and_annotations [name: string, namespace: string] {
    let params = {
        oxr: {
            metadata: { name: $name, namespace: $namespace },
            spec: { size: "small" }
        },
        ocds: {}
    }
    
    log info $"Testing naming and annotations for ($name) in ($namespace)"
    let result = (run_kcl_test $params)
    
    if $result.exit_code != 0 {
        log error $"✗ FAIL: Naming test for ($name)/($namespace) - Command failed"
        log error $result.stderr
        return false
    }
    
    let output = $result.stdout
    let name_test = (assert_contains $output $"name: ($name)" "Resource name")
    let secret_name_test = (assert_contains $output $"name: ($name)-secret" "Secret resource name")
    let namespace_test = (assert_contains $output $"namespace: ($namespace)" "Namespace")
    let cluster_annotation_test = (assert_contains $output "krm.kcl.dev/composition-resource-name: cluster" "Cluster annotation")
    let secret_annotation_test = (assert_contains $output "krm.kcl.dev/composition-resource-name: sql-secret" "Secret annotation")
    
    return ($name_test and $secret_name_test and $namespace_test and $cluster_annotation_test and $secret_annotation_test)
}

# Test scenario from config
def test_scenario [scenario: record, namespace: string = "default"] {
    log info $"🔬 Testing scenario: ($scenario.name)"
    
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
        log error $"❌ FAILED: ($result.stderr)"
        return false
    }
    
    let output = $result.stdout
    
    # Basic resource validation
    let has_cluster = ($output | str contains "kind: Cluster")
    let has_secret = ($output | str contains "kind: Object")
    
    if not ($has_cluster and $has_secret) {
        log error "❌ FAILED: Missing expected resources"
        return false
    }
    
    # Size-specific validation
    if "expected" in $scenario {
        let instances_valid = ($output | str contains $"instances: ($scenario.expected.instances)")
        let storage_valid = ($output | str contains $"size: '($scenario.expected.storage)'")
        
        if not ($instances_valid and $storage_valid) {
            log error $"❌ FAILED: Size configuration mismatch for ($scenario.size)"
            return false
        }
        
        log info $"✅ SUCCESS: ($scenario.name) validated"
    }
    
    return true
}

# Run all tests with different modes
def main [
    --mode: string = "all"  # all, basic, integration, scenarios
    --namespace: string = "default"
    --verbose: bool = false
] {
    if $verbose {
        $env.LOG_LEVEL = "DEBUG"
    }
    
    print "🧪 KCL PostgreSQL Function Local Tests"
    print "======================================"
    print ""
    
    let config = (load_test_scenarios)
    mut test_results = []
    mut test_count = 0
    
    # Basic integration tests
    if $mode == "all" or $mode == "basic" or $mode == "integration" {
        print "📋 Running basic integration tests..."
        
        $test_count += 1
        $test_results = ($test_results | append (test_size_configuration "small" 1 "1Gi"))
        
        $test_count += 1
        $test_results = ($test_results | append (test_size_configuration "medium" 3 "3Gi"))
        
        $test_count += 1
        $test_results = ($test_results | append (test_size_configuration "large" 6 "6Gi"))
        
        $test_count += 1
        $test_results = ($test_results | append (test_resource_creation))
        
        $test_count += 1
        $test_results = ($test_results | append (test_naming_and_annotations "my-database" "production"))
        
        print ""
    }
    
    # Scenario-based tests
    if $mode == "all" or $mode == "scenarios" {
        print "🎯 Running scenario-based tests..."
        
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
        print "🔄 Running multi-namespace tests..."
        
        for ns in $config.namespaces {
            if $ns != $namespace {
                $test_count += 1
                $test_results = ($test_results | append (test_naming_and_annotations $"test-db-($ns)" $ns))
            }
        }
        
        print ""
    }
    
    # Generate report
    let passed_count = ($test_results | where $it == true | length)
    let failed_count = ($test_count - $passed_count)
    
    print "====================================================="
    print "📊 Test Results Summary:"
    print $"   Total tests: ($test_count)"
    print $"   ✅ Passed: ($passed_count)"
    print $"   ❌ Failed: ($failed_count)"
    
    if $failed_count == 0 {
        print ""
        print "🎉 All tests passed! Your KCL function is working correctly."
        exit 0
    } else {
        print ""
        print "❌ Some tests failed. Please review the output above."
        exit 1
    }
}
