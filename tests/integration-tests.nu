#!/usr/bin/env nu

def "main test all" [
    --provider: string = "kind"
    --verbose: bool = false
    --cleanup: bool = true
] {
    print "🧪 Running comprehensive integration tests..."
    
    let start_time = (date now)
    mut passed = 0
    mut failed = 0
    mut results = []
    
    let tests = [
        "cluster-lifecycle",
        "observability-stack", 
        "secrets-management",
        "cloud-providers",
        "gitops-workflow",
        "security-validation"
    ]
    
    for test in $tests {
        print $"\n🔍 Running test: ($test)"
        
        let test_result = match $test {
            "cluster-lifecycle" => { test_cluster_lifecycle $provider $verbose }
            "observability-stack" => { test_observability_stack $provider $verbose }
            "secrets-management" => { test_secrets_management $provider $verbose }
            "cloud-providers" => { test_cloud_providers $verbose }
            "gitops-workflow" => { test_gitops_workflow $provider $verbose }
            "security-validation" => { test_security_validation $verbose }
            _ => { {status: "error", message: "Unknown test"} }
        }
        
        if $test_result.status == "pass" {
            $passed = ($passed + 1)
            print $"✅ ($test): ($test_result.message)"
        } else {
            $failed = ($failed + 1)
            print $"❌ ($test): ($test_result.message)"
        }
        
        $results = ($results | append {test: $test, status: $test_result.status, message: $test_result.message})
    }
    
    if $cleanup {
        print "\n🧹 Cleaning up test resources..."
        cleanup_test_resources $provider
    }
    
    let end_time = (date now)
    let duration = (($end_time - $start_time) / 1sec)
    
    print $"\n📊 Test Results Summary:"
    print $"   Passed: ($passed)"
    print $"   Failed: ($failed)"
    print $"   Duration: ($duration)s"
    
    if $failed > 0 {
        print "\n❌ Some tests failed:"
        for result in $results {
            if $result.status != "pass" {
                print $"   • ($result.test): ($result.message)"
            }
        }
        exit 1
    } else {
        print "\n🎉 All tests passed!"
    }
}

def test_cluster_lifecycle [provider: string, verbose: bool] {
    try {
        if $verbose { print "  Creating test cluster..." }
        
        let cluster_name = "test-cluster"
        
        if $provider == "kind" {
            kind create cluster --name $cluster_name --wait 300s
            
            kubectl cluster-info --context $"kind-($cluster_name)"
            kubectl wait --for=condition=Ready nodes --all --timeout=300s
            
            let nodes = (kubectl get nodes --no-headers | lines | length)
            if $nodes < 1 {
                error make { msg: "No nodes found in cluster" }
            }
            
            if $verbose { print "  Destroying test cluster..." }
            kind delete cluster --name $cluster_name
            
            {status: "pass", message: "Cluster lifecycle test completed successfully"}
        } else {
            {status: "skip", message: $"Cluster lifecycle test skipped for provider ($provider)"}
        }
    } catch { |e|
        {status: "fail", message: $"Cluster lifecycle test failed: ($e.msg)"}
    }
}

def test_observability_stack [provider: string, verbose: bool] {
    try {
        if $verbose { print "  Testing observability components..." }
        
        let cluster_name = "obs-test-cluster"
        
        if $provider == "kind" {
            kind create cluster --name $cluster_name --wait 300s
            kubectl cluster-info --context $"kind-($cluster_name)"
            
            nu scripts/cluster-setup.nu cluster create --provider kind --observability true --gitops ""
            
            if $verbose { print "  Waiting for observability stack..." }
            sleep 60sec
            
            let prometheus_pods = (kubectl get pods -n monitoring --no-headers | where {|line| $line =~ "prometheus"} | length)
            let grafana_pods = (kubectl get pods -n monitoring --no-headers | where {|line| $line =~ "grafana"} | length)
            let loki_pods = (kubectl get pods -n loki --no-headers | where {|line| $line =~ "loki"} | length)
            
            if $prometheus_pods == 0 or $grafana_pods == 0 or $loki_pods == 0 {
                error make { msg: "Observability stack components not found" }
            }
            
            kind delete cluster --name $cluster_name
            
            {status: "pass", message: "Observability stack test completed successfully"}
        } else {
            {status: "skip", message: $"Observability test skipped for provider ($provider)"}
        }
    } catch { |e|
        {status: "fail", message: $"Observability test failed: ($e.msg)"}
    }
}

def test_secrets_management [provider: string, verbose: bool] {
    try {
        if $verbose { print "  Testing secrets management..." }
        
        let cluster_name = "secrets-test-cluster"
        
        if $provider == "kind" {
            kind create cluster --name $cluster_name --wait 300s
            kubectl cluster-info --context $"kind-($cluster_name)"
            
            nu scripts/cluster-setup.nu cluster create --provider kind --secrets true --observability false --gitops ""
            
            if $verbose { print "  Waiting for External Secrets Operator..." }
            sleep 30sec
            
            let eso_pods = (kubectl get pods -n external-secrets --no-headers | where {|line| $line =~ "external-secrets"} | length)
            
            if $eso_pods == 0 {
                error make { msg: "External Secrets Operator not found" }
            }
            
            kubectl create secret generic test-secret --from-literal=key=value
            
            let secret_exists = (kubectl get secret test-secret --ignore-not-found | str length) > 0
            
            if not $secret_exists {
                error make { msg: "Test secret creation failed" }
            }
            
            kind delete cluster --name $cluster_name
            
            {status: "pass", message: "Secrets management test completed successfully"}
        } else {
            {status: "skip", message: $"Secrets test skipped for provider ($provider)"}
        }
    } catch { |e|
        {status: "fail", message: $"Secrets test failed: ($e.msg)"}
    }
}

def test_cloud_providers [verbose: bool] {
    try {
        if $verbose { print "  Testing cloud provider scripts..." }
        
        let gcp_available = (which gcloud | is-not-empty)
        let aws_available = (which aws | is-not-empty)
        let azure_available = (which az | is-not-empty)
        
        if not $gcp_available and not $aws_available and not $azure_available {
            error make { msg: "No cloud provider CLIs available" }
        }
        
        if $gcp_available {
            gcloud version | ignore
        }
        
        if $aws_available {
            aws --version | ignore
        }
        
        if $azure_available {
            az version | ignore
        }
        
        {status: "pass", message: "Cloud provider CLIs validation passed"}
    } catch { |e|
        {status: "fail", message: $"Cloud provider test failed: ($e.msg)"}
    }
}

def test_gitops_workflow [provider: string, verbose: bool] {
    try {
        if $verbose { print "  Testing GitOps workflow..." }
        
        let flux_available = (which flux | is-not-empty)
        let helm_available = (which helm | is-not-empty)
        
        if not $flux_available {
            error make { msg: "FluxCD CLI not available" }
        }
        
        if not $helm_available {
            error make { msg: "Helm CLI not available" }
        }
        
        flux version | ignore
        helm version | ignore
        
        {status: "pass", message: "GitOps tools validation passed"}
    } catch { |e|
        {status: "fail", message: $"GitOps test failed: ($e.msg)"}
    }
}

def test_security_validation [verbose: bool] {
    try {
        if $verbose { print "  Testing security configurations..." }
        
        let age_available = (which age | is-not-empty)
        
        if not $age_available {
            error make { msg: "age encryption tool not available" }
        }
        
        let test_content = "test secret data"
        let temp_file = "/tmp/test-secret.txt"
        let encrypted_file = "/tmp/test-secret.txt.age"
        
        $test_content | save $temp_file
        
        if not ($"~/.config/age/key.txt" | path exists) {
            age-keygen -o ~/.config/age/key.txt
        }
        
        let public_key = (age-keygen -y ~/.config/age/key.txt)
        
        age -e -r $public_key $temp_file > $encrypted_file
        
        let decrypted_content = (age -d -i ~/.config/age/key.txt $encrypted_file)
        
        if $decrypted_content != $test_content {
            error make { msg: "Encryption/decryption test failed" }
        }
        
        rm $temp_file $encrypted_file
        
        {status: "pass", message: "Security validation passed"}
    } catch { |e|
        {status: "fail", message: $"Security test failed: ($e.msg)"}
    }
}

def cleanup_test_resources [provider: string] {
    do --ignore-errors { kind delete cluster --name test-cluster }
    do --ignore-errors { kind delete cluster --name obs-test-cluster }
    do --ignore-errors { kind delete cluster --name secrets-test-cluster }
    
    do --ignore-errors { rm -rf /tmp/test-* }
    
    clean-tmp
}

def "main test unit" [
    --verbose: bool = false
] {
    print "🧪 Running unit tests..."
    
    let test_results = []
    
    let function_tests = [
        "test_get_cpu_count",
        "test_secure_file",
        "test_load_secrets"
    ]
    
    for test in $function_tests {
        match $test {
            "test_get_cpu_count" => { test_get_cpu_count $verbose }
            "test_secure_file" => { test_secure_file $verbose }
            "test_load_secrets" => { test_load_secrets $verbose }
            _ => { print $"Unknown test: ($test)" }
        }
    }
}

def test_get_cpu_count [verbose: bool] {
    try {
        let cpu_count = (get-cpu-count)
        
        if $cpu_count < 1 {
            error make { msg: "Invalid CPU count returned" }
        }
        
        if $verbose { print $"  ✅ CPU count: ($cpu_count)" }
        {status: "pass", message: "get-cpu-count function works correctly"}
    } catch { |e|
        {status: "fail", message: $"get-cpu-count test failed: ($e.msg)"}
    }
}

def test_secure_file [verbose: bool] {
    try {
        let test_file = "/tmp/test-permissions.txt"
        "test content" | save $test_file
        
        secure-file $test_file
        
        let permissions = (ls -la $test_file | get 0.mode)
        
        if not ($permissions | str starts-with "-rw-------") {
            error make { msg: $"Incorrect permissions: ($permissions)" }
        }
        
        rm $test_file
        
        if $verbose { print "  ✅ File permissions set correctly" }
        {status: "pass", message: "secure-file function works correctly"}
    } catch { |e|
        {status: "fail", message: $"secure-file test failed: ($e.msg)"}
    }
}

def test_load_secrets [verbose: bool] {
    try {
        load-secrets
        
        let secrets_dir = $"($env.HOME)/configs-files/tmp/secrets"
        
        if not ($secrets_dir | path exists) {
            error make { msg: "Secrets directory not created" }
        }
        
        if $verbose { print "  ✅ Secrets directory created" }
        {status: "pass", message: "load-secrets function works correctly"}
    } catch { |e|
        {status: "fail", message: $"load-secrets test failed: ($e.msg)"}
    }
}

def "main test benchmark" [
    --provider: string = "kind"
    --iterations: int = 5
] {
    print "⚡ Running performance benchmarks..."
    
    let benchmarks = [
        "cluster_creation_time",
        "observability_deploy_time", 
        "secrets_sync_time"
    ]
    
    for benchmark in $benchmarks {
        print $"\n📊 Benchmark: ($benchmark)"
        
        let times = (0..$iterations | each { |i|
            print $"  Run ($i + 1)/($iterations)..."
            
            match $benchmark {
                "cluster_creation_time" => { benchmark_cluster_creation $provider }
                "observability_deploy_time" => { benchmark_observability_deploy $provider }
                "secrets_sync_time" => { benchmark_secrets_sync }
                _ => { 0 }
            }
        })
        
        let avg_time = ($times | math avg)
        let min_time = ($times | math min)
        let max_time = ($times | math max)
        
        print $"  Average: ($avg_time)s"
        print $"  Min: ($min_time)s" 
        print $"  Max: ($max_time)s"
    }
}

def benchmark_cluster_creation [provider: string] {
    let start_time = (date now)
    
    if $provider == "kind" {
        let cluster_name = $"bench-cluster-(date now | format date '%H%M%S')"
        kind create cluster --name $cluster_name --wait 300s
        kind delete cluster --name $cluster_name
    }
    
    let end_time = (date now)
    (($end_time - $start_time) / 1sec)
}

def benchmark_observability_deploy [provider: string] {
    let start_time = (date now)
    
    if $provider == "kind" {
        let cluster_name = $"obs-bench-(date now | format date '%H%M%S')"
        kind create cluster --name $cluster_name --wait 300s
        
        helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
        helm repo update
        helm install prometheus-stack prometheus-community/kube-prometheus-stack --namespace monitoring --create-namespace --wait
        
        kind delete cluster --name $cluster_name
    }
    
    let end_time = (date now)
    (($end_time - $start_time) / 1sec)
}

def benchmark_secrets_sync [] {
    let start_time = (date now)
    
    for i in 0..10 {
        kubectl create secret generic $"bench-secret-($i)" --from-literal=key=value --dry-run=client -o yaml | kubectl apply -f -
    }
    
    kubectl delete secrets -l app=benchmark --ignore-not-found
    
    let end_time = (date now)
    (($end_time - $start_time) / 1sec)
}

def "main test validate" [
    config_file?: string
] {
    print "✅ Running configuration validation..."
    
    let config_path = if ($config_file | is-empty) {
        "claude/.claude/settings.json"
    } else {
        $config_file
    }
    
    if not ($config_path | path exists) {
        print $"❌ Configuration file not found: ($config_path)"
        exit 1
    }
    
    try {
        let config = (open $config_path | from json)
        
        if "hooks" not-in $config {
            print "❌ Missing 'hooks' section in configuration"
            exit 1
        }
        
        if "aliases" not-in $config {
            print "❌ Missing 'aliases' section in configuration"
            exit 1
        }
        
        print "✅ Configuration validation passed"
        
        let required_tools = ["kubectl", "helm", "kind", "flux", "age"]
        let missing_tools = []
        
        for tool in $required_tools {
            if (which $tool | is-empty) {
                $missing_tools = ($missing_tools | append $tool)
            }
        }
        
        if ($missing_tools | length) > 0 {
            print $"⚠️  Missing tools: (($missing_tools | str join ', '))"
            print "   Install missing tools for full functionality"
        } else {
            print "✅ All required tools available"
        }
        
    } catch { |e|
        print $"❌ Configuration validation failed: ($e.msg)"
        exit 1
    }
}

def "main test help" [] {
    print "🧪 Test Suite Commands:"
    print ""
    print "🔧 Test Execution:"
    print "  all                    - Run all integration tests"
    print "  unit                   - Run unit tests"
    print "  benchmark              - Run performance benchmarks"
    print "  validate [config]      - Validate configuration"
    print ""
    print "⚙️  Options:"
    print "  --provider <name>      - Target provider (kind, k3d, minikube)"
    print "  --verbose              - Enable verbose output"
    print "  --cleanup              - Clean up resources after tests"
    print "  --iterations <num>     - Number of benchmark iterations"
    print ""
    print "📊 Test Categories:"
    print "  • cluster-lifecycle    - Test cluster creation/destruction"
    print "  • observability-stack  - Test monitoring/logging deployment"
    print "  • secrets-management   - Test secret operations"
    print "  • cloud-providers      - Test cloud provider integrations"
    print "  • gitops-workflow      - Test GitOps tools and workflows"
    print "  • security-validation  - Test security configurations"
}