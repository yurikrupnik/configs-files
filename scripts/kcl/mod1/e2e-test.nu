#!/usr/bin/env nu

# E2E Testing for KCL Crossplane Functions
# Simulates how Crossplane would invoke the function in different scenarios

def create_test_scenario [name: string, spec: record, ocds: record] {
    return {
        name: $name,
        params: {
            oxr: {
                metadata: {
                    name: $name,
                    namespace: "crossplane-system"
                },
                spec: $spec
            },
            ocds: $ocds
        }
    }
}

def run_scenario_test [scenario: record] {
    print $"🔬 Testing scenario: ($scenario.name)"
    print "  Parameters:"
    print $"    Name: ($scenario.params.oxr.metadata.name)"
    print $"    Namespace: ($scenario.params.oxr.metadata.namespace)"
    print $"    Size: ($scenario.params.oxr.spec.size)"
    
    let result = (^kcl run . -D $"params=($scenario.params | to json)" | complete)
    
    if $result.exit_code != 0 {
        print $"  ❌ FAILED: ($result.stderr)"
        return false
    }
    
    # Parse the output and validate
    let output = $result.stdout
    
    # Extract resources from the output
    let has_cluster = ($output | str contains "kind: Cluster")
    let has_secret = ($output | str contains "kind: Object")
    
    if $has_cluster and $has_secret {
        print "  ✅ SUCCESS: Generated PostgreSQL cluster and secret resources"
        
        # Additional validations based on size
        match $scenario.params.oxr.spec.size {
            "small" => {
                if ($output | str contains "instances: 1") and ($output | str contains "size: '1Gi'") {
                    print "    ✓ Small configuration validated"
                } else {
                    print "    ❌ Small configuration mismatch"
                    return false
                }
            },
            "medium" => {
                if ($output | str contains "instances: 3") and ($output | str contains "size: '3Gi'") {
                    print "    ✓ Medium configuration validated"
                } else {
                    print "    ❌ Medium configuration mismatch"
                    return false
                }
            },
            "large" => {
                if ($output | str contains "instances: 6") and ($output | str contains "size: '6Gi'") {
                    print "    ✓ Large configuration validated"
                } else {
                    print "    ❌ Large configuration mismatch"
                    return false
                }
            }
        }
        return true
    } else {
        print "  ❌ FAILED: Missing expected resources"
        return false
    }
}

def generate_test_report [results: list<bool>, scenarios: list<record>] {
    print ""
    print "📊 E2E Test Report"
    print "=================="
    
    let total_tests = ($results | length)
    let passed_tests = ($results | where $it == true | length)
    let failed_tests = ($total_tests - $passed_tests)
    
    print $"Total scenarios: ($total_tests)"
    print $"✅ Passed: ($passed_tests)"
    print $"❌ Failed: ($failed_tests)"
    
    if $failed_tests > 0 {
        print ""
        print "Failed scenarios:"
        for i in 0..($results | length) {
            if not $results.$i {
                print $"  - ($scenarios.$i.name)"
            }
        }
    }
    
    return ($failed_tests == 0)
}

def main [] {
    print "🚀 KCL Crossplane Function E2E Testing"
    print "======================================="
    print ""
    
    # Define test scenarios
    let scenarios = [
        (create_test_scenario "dev-postgres-small" {size: "small"} {}),
        (create_test_scenario "staging-postgres-medium" {size: "medium"} {}),
        (create_test_scenario "prod-postgres-large" {size: "large"} {}),
        (create_test_scenario "existing-postgres" {size: "medium"} {
            cluster: {
                Resource: {
                    status: {
                        atProvider: {
                            serviceHost: "existing-postgres.local"
                        }
                    }
                }
            }
        })
    ]
    
    # Run all scenarios
    mut results = []
    for scenario in $scenarios {
        let result = (run_scenario_test $scenario)
        $results = ($results | append $result)
        print ""
    }
    
    # Generate report
    let all_passed = (generate_test_report $results $scenarios)
    
    if $all_passed {
        print ""
        print "🎉 All E2E tests passed! Your KCL function is ready for Crossplane."
        exit 0
    } else {
        print ""
        print "❌ Some E2E tests failed. Please review the output above."
        exit 1
    }
}

main
