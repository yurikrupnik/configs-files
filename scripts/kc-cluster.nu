#!/usr/bin/env nu

# Supported cloud providers (enum-like)
const CLOUD_PROVIDERS = {
    aws: "aws",
    gcp: "gcp", 
    local: "local",
    azure: "azure"
}

# Get list of valid provider values
const PROVIDER_VALUES = [$CLOUD_PROVIDERS.aws, $CLOUD_PROVIDERS.gcp, $CLOUD_PROVIDERS.local, $CLOUD_PROVIDERS.azure]

# List available cloud providers
def "main list-providers" [] {
    print "🌩️  Available cloud providers:"
    $PROVIDER_VALUES | each {|provider| print $"  • ($provider)"}
}

# Validate cloud provider
def validate-provider [provider: string] {
    if $provider not-in $PROVIDER_VALUES {
        let options = ($PROVIDER_VALUES | str join ", ")
        error make {msg: $"Invalid cloud provider: ($provider). Valid options: ($options)"}
    }
}

# Common cluster creation logic - called by all shells
def main [
    --cloud: string = "local"  # One of: aws, gcp, local, azure
    --gitops: string = "flux"
    --gcp-project: string = "playground-447016"
] {
    # Validate cloud provider using helper function
    validate-provider $cloud

    print $"🚀 Creating Kubernetes development cluster with GitOps-managed stack... (($cloud))"

    match $cloud {
        "aws" => {
            print "🟠 AWS cluster creation"
            nu scripts/cloud-providers.nu provider managed-cluster $CLOUD_PROVIDERS.aws
        }
        "gcp" => {
            print "🔵 GCP cluster creation"
            gcloud config set project $gcp_project
            nu scripts/cloud-providers.nu provider managed-cluster $CLOUD_PROVIDERS.gcp
        }
        "azure" => {
            print "🔵 Azure cluster creation"
            nu scripts/cloud-providers.nu provider managed-cluster $CLOUD_PROVIDERS.azure
        }
        "local" => {
            print "🏠 Local Kind cluster creation"
            
            # Ensure temp directory exists
            let dir = "/tmp/files"
            if not ($dir | path exists) {
                mkdir $dir
            }

            # Download cluster config from GitOps repo
            let cluster_config = http get https://raw.githubusercontent.com/yurikrupnik/gitops/main/cluster/cluster.yaml

            # Create temporary file to avoid stdin issues
            let temp_file = $"/tmp/files/kind-config-($env.USER).yaml"
            $cluster_config | save $temp_file

            kind create cluster --config $temp_file
            rm $temp_file
        }
        _ => {
            let options = ($PROVIDER_VALUES | str join ", ")
            error make {msg: $"Unsupported cloud provider: ($cloud). Valid options: ($options)"}
        }
    }

    print "✅ Cluster created successfully!"
}
