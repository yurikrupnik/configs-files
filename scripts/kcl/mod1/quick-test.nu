#!/usr/bin/env nu

# Quick utility to test KCL function with custom parameters

def main [
    --name (-n): string = "test-db"        # Database name
    --namespace: string = "default"        # Kubernetes namespace
    --size (-s): string = "small"          # Database size (small, medium, large)
    --ocds: string = "{}"                  # Existing composed resources (JSON)
] {
    print $"🚀 Quick KCL Function Test"
    print $"========================="
    print $"Name: ($name)"
    print $"Namespace: ($namespace)"
    print $"Size: ($size)"
    print ""
    
    let ocds_data = if $ocds == "{}" {
        {}
    } else {
        ($ocds | from json)
    }
    
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
        ocds: $ocds_data
    }
    
    print "Running KCL function..."
    let result = (^kcl run . -D $"params=($params | to json)" | complete)
    
    if $result.exit_code == 0 {
        print "✅ SUCCESS!"
        print ""
        print "Generated resources:"
        print "==================="
        print $result.stdout
    } else {
        print "❌ FAILED!"
        print $result.stderr
        exit 1
    }
}
