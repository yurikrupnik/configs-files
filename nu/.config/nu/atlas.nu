#!/usr/bin/env nu

def "main apply atlas" [] {

    (
        kind create cluster
        helm upgrade --install atlas-operator oci://ghcr.io/ariga/charts/atlas-operator --namespace atlas-operator --create-namespace --wait
    )

}

def "main delete temp_files" [] {

    rm --force .env

    rm --force kubeconfig*.yaml

}

def "main get provider" [] {
    gcloud auth print-access-token
    gcloud auth print-identity-token
    let provider = [aws azure google kind upcloud]
        | input list $"(ansi yellow_bold)Which provider do you want to use?(ansi green_bold)"
    print $"(ansi reset)"

    $"export PROVIDER=($provider)\n" | save --append .env

    $provider
}