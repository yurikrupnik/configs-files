#!/usr/bin/env nu

# KCL Crossplane Function Integration Tests

def run_kcl_test [params: record] {
    let result = (^kcl run . -D $"params=($params | to json)" | complete)
    return {
        exit_code: $result.exit_code,
        stdout: $result.stdout,
        stderr: $result.stderr
    }
}

def assert_contains [text: string, pattern: string, test_name: string] {
    if ($text | str contains $pattern) {
        print $"✓ PASS: ($test_name)"
        return true
    } else {
        print $"✗ FAIL: ($test_name) - Expected pattern not found: ($pattern)"
        return false
    }
}

def test_size_configuration [size: string, expected_instances: int, expected_storage: string] {
    let params = {
        oxr: {
            metadata: { name: $"test-($size)", namespace: "default" },
            spec: { size: $size }
        },
        ocds: {}
    }
    
    let result = (run_kcl_test $params)
    
    if $result.exit_code != 0 {
        print $"✗ FAIL: ($size) configuration - Command failed"
        print $result.stderr
        return false
    }
    
    let output = $result.stdout
    let instances_test = (assert_contains $output $"instances: ($expected_instances)" $"($size) instance count")
    let storage_test = (assert_contains $output $"size: '($expected_storage)'" $"($size) storage size")
    
    return ($instances_test and $storage_test)
}

def test_resource_creation [] {
    let params = {
        oxr: {
            metadata: { name: "test-resources", namespace: "default" },
            spec: { size: "small" }
        },
        ocds: {}
    }
    
    let result = (run_kcl_test $params)
    
    if $result.exit_code != 0 {
        print "✗ FAIL: Resource creation test - Command failed"
        return false
    }
    
    let output = $result.stdout
    let cluster_test = (assert_contains $output "apiVersion: postgresql.cnpg.io/v1" "PostgreSQL cluster API version")
    let cluster_kind_test = (assert_contains $output "kind: Cluster" "PostgreSQL cluster kind")
    let secret_test = (assert_contains $output "apiVersion: kubernetes.m.crossplane.io/v1alpha1" "Secret object API version")
    let secret_kind_test = (assert_contains $output "kind: Object" "Secret object kind")
    
    return ($cluster_test and $cluster_kind_test and $secret_test and $secret_kind_test)
}

def test_naming_and_annotations [name: string, namespace: string] {
    let params = {
        oxr: {
            metadata: { name: $name, namespace: $namespace },
            spec: { size: "small" }
        },
        ocds: {}
    }
    
    let result = (run_kcl_test $params)
    
    if $result.exit_code != 0 {
        print $"✗ FAIL: Naming test for ($name)/($namespace) - Command failed"
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

def run_all_tests [] {
    mut test_results = []
    mut test_count = 0
    
    print "🧪 Running KCL Crossplane Function Integration Tests"
    print "===================================================="
    print ""
    
    # Test 1: Size configurations
    print "📋 Testing size configurations..."
    $test_count += 1
    $test_results = ($test_results | append (test_size_configuration "small" 1 "1Gi"))
    
    $test_count += 1
    $test_results = ($test_results | append (test_size_configuration "medium" 3 "3Gi"))
    
    $test_count += 1
    $test_results = ($test_results | append (test_size_configuration "large" 6 "6Gi"))
    
    print ""
    
    # Test 2: Resource creation
    print "🏗️  Testing resource creation..."
    $test_count += 1
    $test_results = ($test_results | append (test_resource_creation))
    
    print ""
    
    # Test 3: Naming and annotations
    print "🏷️  Testing naming and annotations..."
    $test_count += 1
    $test_results = ($test_results | append (test_naming_and_annotations "my-database" "production"))
    
    print ""
    
    # Test 4: Edge case - different namespace
    print "🔄 Testing different namespace..."
    $test_count += 1
    $test_results = ($test_results | append (test_naming_and_annotations "test-db" "staging"))
    
    print ""
    
    # Summary
    let passed_count = ($test_results | where $it == true | length)
    let failed_count = ($test_count - $passed_count)
    
    print "====================================================="
    print "📊 Test Results Summary:"
    print $"   Total tests: ($test_count)"
    print $"   ✅ Passed: ($passed_count)"
    print $"   ❌ Failed: ($failed_count)"
    
    if $failed_count == 0 {
        print ""
        print "🎉 All tests passed! Your KCL Crossplane function is working correctly."
        return 0
    } else {
        print ""
        print "❌ Some tests failed. Please review the output above."
        return 1
    }
}

# Run the tests
exit (run_all_tests)
