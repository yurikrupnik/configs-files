#use polars
#use aris


export def main [
    name
    --observability
    --secrets
    --gitops: string
    --registry
]  {
    print "Creating cluster"
    let cluster_name = $name

   let config = http get "https://raw.githubusercontent.com/yurikrupnik/gitops/main/cluster/cluster.yaml"

   let temp_file = $"/tmp/kind-config-($env.USER).yaml"
   $config | save $temp_file -f

   print "📦 Creating Kind cluster..."
   kind create cluster --name $cluster_name --config $temp_file
   #rm $temp_file

   kubectl cluster-info --context $"kind-($cluster_name)"
   kubectl wait --for=condition=Ready nodes --all --timeout=300s

  # if $registry {
  #     setup_local_registry $cluster_name
  # }

   install_gateway_api

   if $gitops == "flux" {
       install_flux
   } else if $gitops == "argo" {
       install_argocd
   }

   if $observability {
       install_observability_stack $gitops
   }

   if $secrets {
       install_external_secrets $gitops
   }
}

def "main delete" [] {
    kind delete cluster


    #print_cluster_info $cluster_name $observability $secrets $gitops
}

export def "main list" [] {
    print "list cluster"
    let kubeconfig = (kind get kubeconfig)
    print $kubeconfig
    {
        currentContext: "",
        name: "dev"
    }
}
