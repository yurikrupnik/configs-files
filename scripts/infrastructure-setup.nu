#!/usr/bin/env nu

def main [] {
    #main install crossplane
}
def "main install crossplane" [
    --namespace: string = "crossplane-system"
    --version: string = "1.15.0"
    --wait
] {
    print "📦 Installing Crossplane..."
    
    helm repo add crossplane-stable https://charts.crossplane.io/stable
    helm repo update
    
    let wait_flag = if $wait { "--wait" } else { "" }
    
    helm install crossplane crossplane-stable/crossplane --namespace $namespace --create-namespace --version $version $wait_flag
    
    print "⏳ Waiting for Crossplane to be ready..."
    kubectl wait --for=condition=Ready pods -l app=crossplane --namespace $namespace --timeout=300s
    
    print "✅ Crossplane installed successfully"
    kubectl get pods -n $namespace
}

def "main install vault" [
    --namespace: string = "vault"
    --mode: string = "dev"
    --ha
    --wait
] {
    print "🔐 Installing HashiCorp Vault..."
    
    helm repo add hashicorp https://helm.releases.hashicorp.com
    helm repo update
    
    let values = if $mode == "dev" {
        $"
server:
  dev:
    enabled: true
    devRootToken: \"root\"
  ha:
    enabled: ($ha)
    replicas: 3
ui:
  enabled: true
  serviceType: ClusterIP
injector:
  enabled: true
"
    } else {
        $"
server:
  ha:
    enabled: ($ha)
    replicas: 3
  dataStorage:
    enabled: true
    size: 10Gi
    storageClass: standard
ui:
  enabled: true
  serviceType: ClusterIP
injector:
  enabled: true
"
    }
    
    let temp_values = "/tmp/vault-values.yaml"
    $values | save $temp_values
    
    let wait_flag = if $wait { "--wait" } else { "" }
    
    helm install vault hashicorp/vault --namespace $namespace --create-namespace --values $temp_values $wait_flag
    
    rm $temp_values
    
    print "⏳ Waiting for Vault to be ready..."
    sleep 10sec
    kubectl wait --for=condition=Ready pods -l app.kubernetes.io/name=vault --namespace $namespace --timeout=300s
    
    if $mode == "dev" {
        print "🔑 Vault is running in dev mode with root token: 'root'"
        print "🌐 Access Vault UI: kubectl port-forward -n vault svc/vault 8200:8200"
        print "   Then visit: http://localhost:8200 (token: root)"
    } else {
        print "🔧 Vault is installed in production mode. Manual initialization required:"
        print "   kubectl exec -n vault vault-0 -- vault operator init"
    }
    
    print "✅ Vault installed successfully"
    kubectl get pods -n $namespace
}

def "main install external-secrets" [
    --namespace: string = "external-secrets"
    --wait
] {
    print "🔐 Installing External Secrets Operator..."
    
    helm repo add external-secrets https://charts.external-secrets.io
    helm repo update
    
    let wait_flag = if $wait { "--wait" } else { "" }
    
    helm install external-secrets external-secrets/external-secrets --namespace $namespace --create-namespace --set installCRDs=true --set replicaCount=2 $wait_flag
    
    print "⏳ Waiting for External Secrets Operator to be ready..."
    kubectl wait --for=condition=Ready pods -l app.kubernetes.io/name=external-secrets --namespace $namespace --timeout=300s
    
    print "✅ External Secrets Operator installed successfully"
    kubectl get pods -n $namespace
    
    print "\n📋 Next steps:"
    print "1. Configure SecretStore/ClusterSecretStore for your secret backend"
    print "2. Create ExternalSecret resources to sync secrets"
    print "3. Example Vault SecretStore:"
    print "   kubectl apply -f - <<EOF"
    print "   apiVersion: external-secrets.io/v1beta1"
    print "   kind: SecretStore"
    print "   metadata:"
    print "     name: vault-backend"
    print "     namespace: default"
    print "   spec:"
    print "     provider:"
    print "       vault:"
    print "         server: \"http://vault.vault.svc.cluster.local:8200\""
    print "         path: \"secret\""
    print "         version: \"v2\""
    print "         auth:"
    print "           tokenSecretRef:"
    print "             name: \"vault-token\""
    print "             key: \"token\""
    print "   EOF"
}

def "main setup vault-external-secrets" [
    --vault-namespace: string = "vault"
    --eso-namespace: string = "external-secrets"
    --app-namespace: string = "default"
    --vault-token: string = "root"
] {
    print "🔗 Setting up Vault integration with External Secrets..."
    
    # Create vault token secret for External Secrets
    kubectl create secret generic vault-token --from-literal=token=$vault_token --namespace $app_namespace --dry-run=client -o yaml | kubectl apply -f -
    
    # Create SecretStore for Vault
    let secret_store = $"
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-backend
  namespace: ($app_namespace)
spec:
  provider:
    vault:
      server: \"http://vault.($vault_namespace).svc.cluster.local:8200\"
      path: \"secret\"
      version: \"v2\"
      auth:
        tokenSecretRef:
          name: \"vault-token\"
          key: \"token\"
"
    
    $secret_store | kubectl apply -f -
    
    print "✅ Vault SecretStore created successfully"
    print "📋 Test the setup:"
    print "1. Add a secret to Vault: kubectl exec -n vault vault-0 -- vault kv put secret/myapp username=admin password=secret123"
    print "2. Create an ExternalSecret:"
    print "   kubectl apply -f - <<EOF"
    print "   apiVersion: external-secrets.io/v1beta1"
    print "   kind: ExternalSecret"
    print "   metadata:"
    print "     name: myapp-secret"
    print "     namespace: default"
    print "   spec:"
    print "     refreshInterval: 30s"
    print "     secretStoreRef:"
    print "       name: vault-backend"
    print "       kind: SecretStore"
    print "     target:"
    print "       name: myapp-secret"
    print "       creationPolicy: Owner"
    print "     data:"
    print "     - secretKey: username"
    print "       remoteRef:"
    print "         key: secret/myapp"
    print "         property: username"
    print "     - secretKey: password"
    print "       remoteRef:"
    print "         key: secret/myapp"
    print "         property: password"
    print "   EOF"
}

def "main install all" [
    --crossplane-namespace: string = "crossplane-system"
    --vault-namespace: string = "vault"
    --eso-namespace: string = "external-secrets"
    --vault-mode: string = "dev"
    --vault-ha
    --setup-integration
    --send-slack
    --slack-webhook: string = ""
    --slack-channel: string = "#general"
] {
    print "🚀 Installing complete infrastructure stack..."
    
    # Install Crossplane
    main install crossplane --namespace $crossplane_namespace --wait
    
    # Install Vault
    if $vault_ha {
        main install vault --namespace $vault_namespace --mode $vault_mode --ha --wait
    } else {
        main install vault --namespace $vault_namespace --mode $vault_mode --wait
    }
    
    # Install External Secrets
    main install external-secrets --namespace $eso_namespace --wait
    
    # Setup integration if requested
    if $setup_integration {
        main setup vault-external-secrets --vault-namespace $vault_namespace --eso-namespace $eso_namespace
    }
    
    print "\n🎉 All infrastructure components installed successfully!"
    print "\n📋 Installed components:"
    print $"  • Crossplane (namespace: ($crossplane_namespace))"
    print $"  • HashiCorp Vault (namespace: ($vault_namespace), mode: ($vault_mode))"
    print $"  • External Secrets Operator (namespace: ($eso_namespace))"
    
    if $setup_integration {
        print "  • Vault-ESO integration configured"
    }
    
    print "\n🔍 Check status:"
    print $"  kubectl get pods -n ($crossplane_namespace)"
    print $"  kubectl get pods -n ($vault_namespace)"
    print $"  kubectl get pods -n ($eso_namespace)"
    
    # Send Slack notification if requested
    if $send_slack and ($slack_webhook != "") {
        send_slack_notification $slack_webhook $slack_channel
    }
}

def send_slack_notification [webhook_url: string, channel: string] {
    print "📢 Sending Slack notification..."
    
    let message = {
        "channel": $channel,
        "text": "🎉 Infrastructure Setup Complete!",
        "attachments": [
            {
                "color": "good",
                "title": "Kubernetes Cluster Ready",
                "fields": [
                    {
                        "title": "Crossplane",
                        "value": "✅ Installed and Ready",
                        "short": true
                    },
                    {
                        "title": "HashiCorp Vault",
                        "value": "✅ Installed and Ready",
                        "short": true
                    },
                    {
                        "title": "External Secrets",
                        "value": "✅ Installed and Ready",
                        "short": true
                    }
                ],
                "footer": "Kubernetes Infrastructure",
                "ts": (date now | format date "%s")
            }
        ]
    }
    
    try {
        http post $webhook_url ($message | to json)
        print "✅ Slack notification sent successfully"
    } catch {
        print "❌ Failed to send Slack notification"
    }
}

def "main status" [] {
    print "🔍 Infrastructure status:"
    
    print "\n📦 Crossplane:"
    try {
        kubectl get pods -n crossplane-system -l app=crossplane
    } catch {
        print "  Not installed or not accessible"
    }
    
    print "\n🔐 Vault:"
    try {
        kubectl get pods -n vault -l app.kubernetes.io/name=vault
    } catch {
        print "  Not installed or not accessible"
    }
    
    print "\n🔐 External Secrets:"
    try {
        kubectl get pods -n external-secrets -l app.kubernetes.io/name=external-secrets
    } catch {
        print "  Not installed or not accessible"
    }
    
    print "\n🔗 SecretStores:"
    try {
        kubectl get secretstores -A
    } catch {
        print "  No SecretStores found or ESO not installed"
    }
    
    print "\n📝 ExternalSecrets:"
    try {
        kubectl get externalsecrets -A
    } catch {
        print "  No ExternalSecrets found or ESO not installed"
    }
}

def "main help" [] {
    print "🚀 Infrastructure Setup Commands:"
    print ""
    print "🔧 Installation:"
    print "  install crossplane    - Install Crossplane"
    print "  install vault         - Install HashiCorp Vault"
    print "  install external-secrets - Install External Secrets Operator"
    print "  install all           - Install all components with integration"
    print ""
    print "🔗 Integration:"
    print "  setup vault-external-secrets - Configure Vault with External Secrets"
    print ""
    print "📊 Monitoring:"
    print "  status                - Show status of all components"
    print "  help                  - Show this help"
    print ""
    print "⚙️  Options:"
    print "  --namespace <name>    - Target namespace"
    print "  --version <version>   - Component version"
    print "  --mode <mode>         - Vault mode (dev|prod)"
    print "  --ha                  - Enable high availability"
    print "  --wait                - Wait for installation to complete"
    print "  --send-slack          - Send Slack notification"
    print "  --slack-webhook <url> - Slack webhook URL"
    print "  --slack-channel <ch>  - Slack channel"
    print ""
    print "🚀 Quick Start:"
    print "  # Install everything with dev Vault and Slack notification"
    print "  nu scripts/infrastructure-setup.nu install all --send-slack --slack-webhook <webhook-url>"
    print "  "
    print "  # Install for production with HA Vault"
    print "  nu scripts/infrastructure-setup.nu install all --vault-mode prod --vault-ha"
}