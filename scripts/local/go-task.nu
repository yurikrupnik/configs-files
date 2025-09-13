def "main delete" [] {
    kind delete cluster


    #print_cluster_info $cluster_name $observability $secrets $gitops
}

export def "main list" [] {
    print "list cluster"
    # let kubeconfig = (kind get kubeconfig)
    # print $kubeconfig
    {
        currentContext: "",
        name: "dev"
    }
}
