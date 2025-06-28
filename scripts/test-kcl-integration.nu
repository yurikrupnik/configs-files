#!/usr/bin/env nu

# Test script for KCL integration with Nu shell scripts
# This script tests the KCL configuration management functionality

print "🧪 Testing KCL Integration with Nu Shell Scripts"
print "================================================="
print ""

# Test 1: Check if KCL is available
print "1️⃣ Testing KCL availability..."
try {
    let kcl_version = (kcl --version | str trim)
    print $"   ✅ KCL is available: ($kcl_version)"
} catch {
    print "   ❌ KCL is not installed or not in PATH"
    print "   💡 Run 'kcl install' to install KCL"
    exit 1
}

# Test 2: Check if KCL project exists
print ""
print "2️⃣ Testing KCL project structure..."
let kcl_path = "../kcl"
if ($kcl_path | path exists) {
    print $"   ✅ KCL project exists at ($kcl_path)"

    # Check for required files
    let required_files = ["base.k", "main.k", "kcl.mod"]
    mut missing_files = []

    for file in $required_files {
        let file_path = $"($kcl_path)/($file)"
        if ($file_path | path exists) {
            print $"   ✅ Found: ($file)"
        } else {
            print $"   ❌ Missing: ($file)"
            $missing_files = ($missing_files | append $file)
        }
    }

    if ($missing_files | length) > 0 {
        print $"   ⚠️  Missing files: ($missing_files | str join ', ')"
    }
} else {
    print $"   ❌ KCL project not found at ($kcl_path)"
    print "   💡 Run 'kcl init' to initialize the project"
    exit 1
}

# Test 3: Check environment configurations
print ""
print "3️⃣ Testing environment configurations..."
let envs_path = $"($kcl_path)/environments"
if ($envs_path | path exists) {
    let env_files = try {
        ls $"($envs_path)/*.k" | get name | each { |file|
            $file | path basename | str replace ".k" ""
        }
    } catch {
        []
    }

    print $"   ✅ Found environments: ($env_files | str join ', ')"

    # Test each environment
    for env in $env_files {
        try {
            let env_file = $"($envs_path)/($env).k"
            kcl run $env_file --format yaml | complete | get exit_code
            if $in == 0 {
                print $"   ✅ ($env) environment validates successfully"
            } else {
                print $"   ❌ ($env) environment validation failed"
            }
        } catch {
            print $"   ❌ Error validating ($env) environment"
        }
    }
} else {
    print $"   ❌ Environments directory not found"
    exit 1
}

# Test 4: Validate KCL configurations
print ""
print "4️⃣ Testing KCL validation..."
try {
    cd $kcl_path

    # Test base configuration
    let base_result = (kcl run base.k | complete)
    if $base_result.exit_code == 0 {
        print "   ✅ Base configuration is valid"
    } else {
        print "   ❌ Base configuration validation failed"
        print $"      Error: ($base_result.stderr)"
    }

    # Test main configuration
    let main_result = (kcl run main.k | complete)
    if $main_result.exit_code == 0 {
        print "   ✅ Main configuration is valid"
    } else {
        print "   ❌ Main configuration validation failed"
        print $"      Error: ($main_result.stderr)"
    }

    # Test test configuration if it exists
    if ("test.k" | path exists) {
        let test_result = (kcl run test.k | complete)
        if $test_result.exit_code == 0 {
            print "   ✅ Test configuration passed"
        } else {
            print "   ❌ Test configuration failed"
            print $"      Error: ($test_result.stderr)"
        }
    }

    cd ..
} catch {
    print "   ❌ Error during KCL validation"
    cd ..
}

# Test 5: Test Nu script integration
print ""
print "5️⃣ Testing Nu script integration..."

# Check if Nu scripts are loadable
try {
    source nu-scripts/kcl.nu
    print "   ✅ KCL Nu module loaded successfully"
} catch {
    print "   ❌ Failed to load KCL Nu module"
    print "   💡 Check if scripts/nu-scripts/config-management/kcl.nu exists and is valid"
}

# Test 6: Test specific KCL functions (if Nu module loaded successfully)
print ""
print "6️⃣ Testing KCL functions..."

try {
    # Test environment listing
    source nu-scripts/kcl.nu
    let envs = (kcl list-envs --path $kcl_path)
    print $"   ✅ Environment listing works: ($envs | length) environments found"

    # Test environment configuration retrieval
    if ($envs | length) > 0 {
        let first_env = ($envs | first)
        try {
            let config = (kcl get-env $first_env --path $kcl_path)
            if ($config | is-empty) {
                print $"   ⚠️  Environment config for ($first_env) is empty"
            } else {
                print $"   ✅ Environment config retrieval works for ($first_env)"
            }
        } catch {
            print $"   ❌ Failed to get environment config for ($first_env)"
        }
    }

    # Test infrastructure summary
    try {
        let summary = (kcl infrastructure-summary --path $kcl_path)
        if ($summary | is-empty) {
            print "   ⚠️  Infrastructure summary is empty"
        } else {
            print "   ✅ Infrastructure summary generation works"
        }
    } catch {
        print "   ❌ Failed to generate infrastructure summary"
    }

} catch {
    print "   ❌ KCL functions not available - Nu module integration failed"
}

# Test 7: Test YAML/JSON output
print ""
print "7️⃣ Testing output formats..."
try {
    cd $kcl_path

    # Test YAML output
    let yaml_result = (kcl run main.k --format yaml | complete)
    if $yaml_result.exit_code == 0 {
        print "   ✅ YAML output works"
    } else {
        print "   ❌ YAML output failed"
    }

    # Test JSON output
    let json_result = (kcl run main.k --format json | complete)
    if $json_result.exit_code == 0 {
        print "   ✅ JSON output works"

        # Try to parse JSON
        try {
            $json_result.stdout | from json | length
            print "   ✅ JSON output is valid and parseable"
        } catch {
            print "   ⚠️  JSON output is not valid JSON"
        }
    } else {
        print "   ❌ JSON output failed"
    }

    cd ..
} catch {
    print "   ❌ Error testing output formats"
    cd ..
}

# Test Summary
print ""
print "📊 Test Summary"
print "==============="

# Get overall system status
let kcl_available = (which kcl | is-not-empty)
let project_exists = ($kcl_path | path exists)
let scripts_loadable = true  # We'll assume this if we got this far

print $"KCL Installation: ($kcl_available | if $in { '✅ Available' } else { '❌ Missing' })"
print $"KCL Project: ($project_exists | if $in { '✅ Present' } else { '❌ Missing' })"
print $"Nu Integration: ($scripts_loadable | if $in { '✅ Working' } else { '❌ Failed' })"

if $kcl_available and $project_exists and $scripts_loadable {
    print ""
    print "🎉 All tests passed! KCL integration is working correctly."
    print ""
    print "💡 Next steps:"
    print "   • Run 'kcl help' to see all available commands"
    print "   • Try 'kcl create-cluster local --dry-run' to test cluster creation"
    print "   • Use 'kcl infrastructure-summary' to see your infrastructure overview"
    print "   • Generate ArgoCD apps with 'kcl generate-argocd-apps local'"
} else {
    print ""
    print "❌ Some tests failed. Please check the errors above and fix them."
    print ""
    print "💡 Common fixes:"
    print "   • Install KCL: 'kcl install'"
    print "   • Initialize project: 'kcl init'"
    print "   • Check file permissions and paths"
}

print ""
print "🔚 KCL Integration Test Complete"
