#!/usr/bin/env just --justfile

hello:
  echo "hello worlda"
build:
    ls
    #cargo clippy
#    cargo doc --examples
#    cargo test
#    cargo build

#    docker build -t yurikrupnik/config-files .
#    nu config.nu app list
#    nu config.nu config validate
#    docker build -t yurikrupnik/config-files .
nuds:
    nu ~/configs-files/scripts/flux-deps.nu
    #nu config.nu app list
cluster:
    nu ~/configs-files/scripts/local/mod.nu -n shit
    nu ~/configs-files/scripts/generate-shell-configs.nu
    nu ~/configs-files/scripts/kc-cluster.nu
    gcloud auth configure-docker \
        me-west1-docker.pkg.dev

    nu ~/configs-files/scripts/nx.nu
    # storage
    kcl run scripts/kcl/storage/main.k -Y scripts/kcl/storage/kcl.yaml
    # mod1
    kcl run . -D params='{"oxr": {"metadata": {"name": "small-db", "namespace": "test"}, "spec": {"size": "small"}}, "ocds": {}}'
