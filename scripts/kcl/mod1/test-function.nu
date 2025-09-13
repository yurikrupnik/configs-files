#!/usr/bin/env nu

# Test the KCL function with proper parameters as Crossplane would provide them

def test_kcl_function [size: string, name: string, namespace: string] {
    let params = {
        oxr: {
            metadata: {
                name: $name,
                namespace: $namespace
            },
            spec: {
                size: $size
            }
        },
        ocds: {}
    }
    
    print $"Testing KCL function with ($size) size, name: ($name), namespace: ($namespace)..."
    
    let result = (^kcl run . -D $"params=($params | to json)" | complete)
    
    if $result.exit_code == 0 {
        print $"✓ Success for ($size) configuration"
        return $result.stdout
    } else {
        print $"✗ Failed for ($size) configuration"
        print $result.stderr
        return null
    }
}

# Test different configurations
print "=== KCL Crossplane Function Tests ==="
print ""

# Test small configuration
test_kcl_function "small" "small-db" "test"
print ""

# Test medium configuration  
test_kcl_function "medium" "medium-db" "production"
print ""

# Test large configuration
test_kcl_function "large" "large-db" "production"
print ""

# Test with existing composed resources (ocds)
print "Testing with existing composed resources (ocds)..."
let params_with_ocds = {
    oxr: {
        metadata: {
            name: "existing-db",
            namespace: "default"
        },
        spec: {
            size: "medium"
        }
    },
    ocds: {
        cluster: {
            Resource: {
                status: {
                    atProvider: {
                        serviceHost: "existing-cluster.local"
                    }
                }
            }
        }
    }
}

let result_with_ocds = (^kcl run . -D $"params=($params_with_ocds | to json)" | complete)
if $result_with_ocds.exit_code == 0 {
    print "✓ Success with existing composed resources"
    print $result_with_ocds.stdout
} else {
    print "✗ Failed with existing composed resources"
    print $result_with_ocds.stderr
}
