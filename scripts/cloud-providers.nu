#!/usr/bin/env nu

def "main provider setup" [
    provider: string
    --region: string = "us-central1"
    --project: string = ""
    --profile: string = "default"
] {
    match $provider {
        "gcp" => { setup_gcp --region $region --project $project }
        "aws" => { setup_aws --region $region --profile $profile }
        "azure" => { setup_azure --region $region }
        "local" => { setup_local }
        _ => { error make { msg: $"Unsupported provider: ($provider)" } }
    }
}

def setup_gcp [--region: string, --project: string] {
    print "🌩️  Setting up Google Cloud Platform..."
    
    if (which gcloud | is-empty) {
        error make { msg: "gcloud CLI not installed. Install via: brew install google-cloud-sdk" }
    }
    
    let project_id = if ($project | is-empty) {
        gcloud config get-value project
    } else {
        $project
    }
    
    if ($project_id | is-empty) {
        print "No project configured. Creating new project..."
        let new_project = $"dev-cluster-(date now | format date '%Y%m%d%H%M%S')"
        gcloud projects create $new_project
        gcloud config set project $new_project
        $new_project
    } else {
        $project_id
    }
    
    gcloud config set compute/region $region
    gcloud config set compute/zone $"($region)-a"
    
    gcloud auth application-default login
    
    gcloud services enable container.googleapis.com
    gcloud services enable secretmanager.googleapis.com
    gcloud services enable monitoring.googleapis.com
    gcloud services enable logging.googleapis.com
    gcloud services enable clouddebugger.googleapis.com
    gcloud services enable cloudtrace.googleapis.com
    
    create_gcp_secrets_store $project_id
    create_gcp_service_accounts $project_id
    
    print "✅ GCP setup complete"
    print $"   Project: ($project_id)"
    print $"   Region: ($region)"
}

def setup_aws [--region: string, --profile: string] {
    print "☁️  Setting up Amazon Web Services..."
    
    if (which aws | is-empty) {
        error make { msg: "AWS CLI not installed. Install via: brew install awscli" }
    }
    
    if (which eksctl | is-empty) {
        error make { msg: "eksctl not installed. Install via: brew install eksctl" }
    }
    
    aws configure set region $region --profile $profile
    
    if (aws sts get-caller-identity --profile $profile | from json | get Arn | is-empty) {
        print "AWS credentials not configured. Running aws configure..."
        aws configure --profile $profile
    }
    
    let account_id = (aws sts get-caller-identity --profile $profile | from json | get Account)
    
    create_aws_secrets_store $region $profile
    create_aws_service_accounts $account_id $region $profile
    
    print "✅ AWS setup complete"
    print $"   Account: ($account_id)"
    print $"   Region: ($region)"
    print $"   Profile: ($profile)"
}

def setup_azure [--region: string] {
    print "🔵 Setting up Microsoft Azure..."
    
    if (which az | is-empty) {
        error make { msg: "Azure CLI not installed. Install via: brew install azure-cli" }
    }
    
    az login
    
    let subscription_id = (az account show | from json | get id)
    az account set --subscription $subscription_id
    
    az provider register --namespace Microsoft.ContainerService
    az provider register --namespace Microsoft.KeyVault
    az provider register --namespace Microsoft.Insights
    az provider register --namespace Microsoft.OperationalInsights
    
    create_azure_secrets_store $region $subscription_id
    create_azure_service_accounts $subscription_id $region
    
    print "✅ Azure setup complete"
    print $"   Subscription: ($subscription_id)"
    print $"   Region: ($region)"
}

def setup_local [] {
    print "🏠 Setting up local development environment..."
    
    load-secrets
    
    create_local_secrets_store
    
    print "✅ Local setup complete"
}

def create_gcp_secrets_store [project_id: string] {
    print "🔐 Setting up Google Secret Manager..."
    
    let secret_store = $"
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: gcp-secret-store
  namespace: external-secrets
spec:
  provider:
    gcpsm:
      projectId: \"($project_id)\"
      auth:
        workloadIdentity:
          clusterLocation: us-central1
          clusterName: dev-cluster
          serviceAccountRef:
            name: external-secrets-sa
"
    
    mkdir -p tmp/secrets/gcp
    $secret_store | save tmp/secrets/gcp/secret-store.yaml
    
    print "✅ GCP Secret Store configuration saved"
}

def create_aws_secrets_store [region: string, profile: string] {
    print "🔐 Setting up AWS Secrets Manager..."
    
    let secret_store = $"
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: aws-secret-store
  namespace: external-secrets
spec:
  provider:
    aws:
      service: SecretsManager
      region: ($region)
      auth:
        serviceAccount:
          name: external-secrets-sa
"
    
    mkdir -p tmp/secrets/aws
    $secret_store | save tmp/secrets/aws/secret-store.yaml
    
    print "✅ AWS Secret Store configuration saved"
}

def create_azure_secrets_store [region: string, subscription_id: string] {
    print "🔐 Setting up Azure Key Vault..."
    
    let secret_store = $"
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: azure-secret-store
  namespace: external-secrets
spec:
  provider:
    azurekv:
      vaultUrl: \"https://dev-cluster-kv.vault.azure.net/\"
      authType: ServicePrincipal
      serviceAccountRef:
        name: external-secrets-sa
"
    
    mkdir -p tmp/secrets/azure
    $secret_store | save tmp/secrets/azure/secret-store.yaml
    
    print "✅ Azure Secret Store configuration saved"
}

def create_local_secrets_store [] {
    print "🔐 Setting up local secrets store..."
    
    let secret_store = $"
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: local-secret-store
  namespace: external-secrets
spec:
  provider:
    kubernetes:
      server:
        caProvider:
          type: ConfigMap
          name: kube-root-ca.crt
          key: ca.crt
      auth:
        serviceAccount:
          name: external-secrets-sa
"
    
    mkdir -p tmp/secrets/local
    $secret_store | save tmp/secrets/local/secret-store.yaml
    
    print "✅ Local Secret Store configuration saved"
}

def create_gcp_service_accounts [project_id: string] {
    print "👤 Creating GCP service accounts..."
    
    let sa_name = "external-secrets-sa"
    let sa_email = $"($sa_name)@($project_id).iam.gserviceaccount.com"
    
    do --ignore-errors {
        gcloud iam service-accounts create $sa_name --project $project_id
    }
    
    gcloud projects add-iam-policy-binding $project_id --member $"serviceAccount:($sa_email)" --role roles/secretmanager.secretAccessor
    
    gcloud iam service-accounts add-iam-policy-binding $sa_email --role roles/iam.workloadIdentityUser --member $"serviceAccount:($project_id).svc.id.goog[external-secrets/external-secrets-sa]" --project $project_id
    
    print "✅ GCP service accounts configured"
}

def create_aws_service_accounts [account_id: string, region: string, profile: string] {
    print "👤 Creating AWS service accounts..."
    
    let role_name = "ExternalSecretsRole"
    let policy_document = $"
{
  \"Version\": \"2012-10-17\",
  \"Statement\": [
    {
      \"Effect\": \"Allow\",
      \"Principal\": {
        \"Federated\": \"arn:aws:iam::($account_id):oidc-provider/oidc.eks.($region).amazonaws.com/id/EXAMPLE\"
      },
      \"Action\": \"sts:AssumeRoleWithWebIdentity\",
      \"Condition\": {
        \"StringEquals\": {
          \"oidc.eks.($region).amazonaws.com/id/EXAMPLE:sub\": \"system:serviceaccount:external-secrets:external-secrets-sa\"
        }
      }
    }
  ]
}
"
    
    mkdir -p tmp/secrets/aws
    $policy_document | save tmp/secrets/aws/trust-policy.json
    
    do --ignore-errors {
        aws iam create-role --role-name $role_name --assume-role-policy-document $"file://tmp/secrets/aws/trust-policy.json" --profile $profile
    }
    
    aws iam attach-role-policy --role-name $role_name --policy-arn arn:aws:iam::aws:policy/SecretsManagerReadWrite --profile $profile
    
    print "✅ AWS service accounts configured"
}

def create_azure_service_accounts [subscription_id: string, region: string] {
    print "👤 Creating Azure service accounts..."
    
    let sp_name = "external-secrets-sp"
    
    let sp_data = (az ad sp create-for-rbac --name $sp_name --role "Key Vault Secrets User" --scopes $"/subscriptions/($subscription_id)" | from json)
    
    let service_principal = $"
apiVersion: v1
kind: Secret
metadata:
  name: azure-secret-sp
  namespace: external-secrets
type: Opaque
data:
  ClientID: (($sp_data.appId) | encode base64)
  ClientSecret: (($sp_data.password) | encode base64)
  TenantID: (($sp_data.tenant) | encode base64)
"
    
    mkdir -p tmp/secrets/azure
    $service_principal | save tmp/secrets/azure/service-principal.yaml
    
    print "✅ Azure service accounts configured"
}

def "main provider managed-cluster" [
    provider: string
    cluster_name: string = "dev-cluster"
    --region: string = "us-central1"
    --node-count: int = 3
    --machine-type: string = ""
] {
    match $provider {
        "gcp" => { create_gke_cluster $cluster_name --region $region --node-count $node_count --machine-type $machine_type }
        "aws" => { create_eks_cluster $cluster_name --region $region --node-count $node_count --machine-type $machine_type }
        "azure" => { create_aks_cluster $cluster_name --region $region --node-count $node_count --machine-type $machine_type }
        _ => { error make { msg: $"Managed clusters not supported for provider: ($provider)" } }
    }
}

def create_gke_cluster [
    cluster_name: string
    --region: string
    --node-count: int
    --machine-type: string
] {
    let machine = if ($machine_type | is-empty) { "e2-standard-4" } else { $machine_type }
    
    print $"🚀 Creating GKE cluster '($cluster_name)'..."
    
    gcloud container clusters create $cluster_name --region $region --node-locations $"($region)-a,($region)-b,($region)-c" --num-nodes $node_count --machine-type $machine --enable-autorepair --enable-autoupgrade --enable-autoscaling --min-nodes 1 --max-nodes 10 --enable-network-policy --enable-ip-alias --enable-stackdriver-kubernetes --enable-autorepair --enable-autoupgrade
    
    gcloud container clusters get-credentials $cluster_name --region $region
    
    print "✅ GKE cluster created and configured"
}

def create_eks_cluster [
    cluster_name: string
    --region: string
    --node-count: int
    --machine-type: string
] {
    let machine = if ($machine_type | is-empty) { "m5.large" } else { $machine_type }
    
    print $"🚀 Creating EKS cluster '($cluster_name)'..."
    
    eksctl create cluster --name $cluster_name --region $region --nodegroup-name standard-workers --node-type $machine --nodes $node_count --nodes-min 1 --nodes-max 10 --managed
    
    aws eks update-kubeconfig --region $region --name $cluster_name
    
    print "✅ EKS cluster created and configured"
}

def create_aks_cluster [
    cluster_name: string
    --region: string
    --node-count: int
    --machine-type: string
] {
    let machine = if ($machine_type | is-empty) { "Standard_DS2_v2" } else { $machine_type }
    
    print $"🚀 Creating AKS cluster '($cluster_name)'..."
    
    let resource_group = $"rg-($cluster_name)"
    
    az group create --name $resource_group --location $region
    
    az aks create --resource-group $resource_group --name $cluster_name --node-count $node_count --node-vm-size $machine --enable-addons monitoring --generate-ssh-keys
    
    az aks get-credentials --resource-group $resource_group --name $cluster_name
    
    print "✅ AKS cluster created and configured"
}

def "main provider cleanup" [provider: string] {
    print $"🧹 Cleaning up ($provider) resources..."
    
    match $provider {
        "gcp" => { cleanup_gcp }
        "aws" => { cleanup_aws }
        "azure" => { cleanup_azure }
        "local" => { cleanup_local }
        _ => { print $"No cleanup needed for provider: ($provider)" }
    }
}

def cleanup_gcp [] {
    print "Cleaning up GCP resources..."
    cleanup-secrets
    rm -rf tmp/secrets/gcp
}

def cleanup_aws [] {
    print "Cleaning up AWS resources..."
    cleanup-secrets
    rm -rf tmp/secrets/aws
}

def cleanup_azure [] {
    print "Cleaning up Azure resources..."
    cleanup-secrets
    rm -rf tmp/secrets/azure
}

def cleanup_local [] {
    print "Cleaning up local resources..."
    cleanup-secrets
    rm -rf tmp/secrets/local
}

def "main provider list" [] {
    print "🌩️  Supported cloud providers:"
    print "  • gcp    - Google Cloud Platform"
    print "  • aws    - Amazon Web Services"
    print "  • azure  - Microsoft Azure"
    print "  • local  - Local development"
    print ""
    print "📋 Available commands:"
    print "  • setup <provider>           - Configure provider credentials"
    print "  • managed-cluster <provider> - Create managed Kubernetes cluster"
    print "  • cleanup <provider>         - Clean up provider resources"
    print "  • list                       - Show this help"
}