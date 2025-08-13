#!/usr/bin/env nu

# KCL Configuration Management Demo
# This script demonstrates the KCL integration without complex dependencies

print "🔧 KCL Configuration Management Demo"
print "===================================="
print ""

# Check if KCL is available
print "1️⃣ Checking KCL availability..."
if (which kcl | is-empty) {
    print "❌ KCL not found. Please install KCL first:"
    print "   brew install kcl"
    exit 1
} else {
    let version = (kcl --version | str trim)
    print $"✅ KCL is available: ($version)"
}

print ""

# Check KCL project structure
print "2️⃣ Checking KCL project..."
if not ("kcl" | path exists) {
    print "❌ KCL project not found. Please run from the configs-files directory."
    exit 1
}

let required_files = ["kcl/base.k", "kcl/main.k", "kcl/kcl.mod"]
for file in $required_files {
    if ($file | path exists) {
        print $"✅ Found: ($file)"
    } else {
        print $"❌ Missing: ($file)"
        exit 1
    }
}

print ""

# Test basic KCL functionality
print "3️⃣ Testing KCL configurations..."

try {
    cd kcl

    print "📋 Validating base configuration..."
    let base_output = (kcl run base.k | complete)
    if $base_output.exit_code == 0 {
        print "✅ Base configuration is valid"
    } else {
        print "❌ Base configuration failed"
        print $base_output.stderr
    }

    print ""
    print "📋 Testing environment configurations..."
    let environments = ["local", "staging", "production"]

    for env in $environments {
        let env_file = $"environments/($env).k"
        if ($env_file | path exists) {
            let result = (kcl run $env_file | complete)
            if $result.exit_code == 0 {
                print $"✅ ($env) environment is valid"
            } else {
                print $"❌ ($env) environment failed"
            }
        }
    }

    print ""
    print "📊 Infrastructure Summary..."
    let summary = (kcl run main.k --format json | from json | get summary)

    print $"Total Environments: ($summary.total_environments)"
    print $"Total Applications: ($summary.total_applications)"
    print $"Total Budget: $($summary.total_budget) USD"

    print ""
    print "🌍 Environment Details:"
    $summary.cluster_info | transpose key value | each { |row|
        let env_name = $row.key
        let info = $row.value
        print $"  ($env_name):"
        print $"    Type: ($info.type)"
        print $"    Nodes: ($info.nodes)"
        print $"    Apps: ($info.enabled_apps)"
        print $"    Budget: $($info.budget)"
    }

    cd ..

} catch {
    print "❌ Error testing KCL configurations"
    cd ..
    exit 1
}

print ""

# Test YAML/JSON output
print "4️⃣ Testing output formats..."

try {
    cd kcl

    print "📄 Testing YAML output..."
    let yaml_result = (kcl run environments/local.k --format yaml | complete)
    if $yaml_result.exit_code == 0 {
        print "✅ YAML output works"
    }

    print "📄 Testing JSON output..."
    let json_result = (kcl run environments/local.k --format json | complete)
    if $json_result.exit_code == 0 {
        print "✅ JSON output works"

        # Parse and show a sample
        let config = ($json_result.stdout | from json)
        let cluster = ($config | values | first)
        print $"   Sample: Cluster '($cluster.name)' with ($cluster.environment.nodeCount) nodes"
    }

    cd ..

} catch {
    print "❌ Error testing output formats"
    cd ..
}

print ""

# Generate sample manifests
print "5️⃣ Generating sample Kubernetes manifests..."

try {
    cd kcl

    let local_config = (kcl run environments/local.k --format json | from json | get localCluster)

    print "📝 Sample Namespace manifest:"
    let namespaces = ($local_config.applications | where enabled == true | where namespace != "default" | get namespace | uniq)

    for ns in $namespaces {
        let manifest = {
            apiVersion: "v1",
            kind: "Namespace",
            metadata: {
                name: $ns,
                labels: {
                    environment: "local",
                    "managed-by": "kcl"
                }
            }
        }
        print $"---"
        $manifest | to yaml
    }

    print ""
    print "📝 Sample Cost Monitoring ConfigMap:"
    let cost_config = {
        apiVersion: "v1",
        kind: "ConfigMap",
        metadata: {
            name: "cost-monitoring-config",
            namespace: "monitoring",
            labels: {
                environment: "local",
                component: "cost-monitoring"
            }
        },
        data: {
            budget: ($local_config.cost.budget | into string),
            "alert-threshold": ($local_config.cost.alertThreshold | into string),
            currency: $local_config.cost.currency,
            environment: "local",
            "node-count": ($local_config.environment.nodeCount | into string),
            "node-size": $local_config.environment.nodeSize
        }
    }

    print "---"
    $cost_config | to yaml

    cd ..

} catch {
    print "❌ Error generating manifests"
    cd ..
}

print ""

# Usage examples
print "6️⃣ Usage Examples:"
print "=================="
print ""
print "📋 Basic commands:"
print "  kcl run kcl/environments/local.k                    # Run local config"
print "  kcl run kcl/main.k --format json                    # Get all configs as JSON"
print "  kcl run kcl/test.k                                  # Run validation tests"
print ""
print "📊 View configurations:"
print "  kcl run kcl/main.k | from yaml | get summary        # Infrastructure summary"
print "  kcl run kcl/environments/production.k | from yaml   # Production config"
print ""
print "🔄 Generate manifests:"
print "  kcl run kcl/environments/staging.k --format yaml > staging-config.yaml"
print ""
print "💡 Integration with existing tools:"
print "  # Use with kubectl"
print "  kcl run kcl/environments/local.k | from yaml | get localCluster.applications"
print ""
print "  # Extract specific values"
print "  kcl run kcl/main.k | from yaml | get clusters.production.cost.budget"
print ""

print "🎉 KCL Demo Complete!"
print ""
print "💡 Next Steps:"
print "   • Modify environment configs in kcl/environments/"
print "   • Add new applications to kcl/base.k"
print "   • Use generated configs with your cluster management tools"
print "   • Integrate with CI/CD pipelines for infrastructure as code"
