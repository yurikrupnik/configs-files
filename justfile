#!/usr/bin/env just --justfile

hello:
  echo "hello world"
build:
    cargo clippy
    cargo doc --examples
    cargo test
    cargo build

    docker build -t yurikrupnik/config-files .
    nu config.nu app list
#    nu config.nu config validate
#    docker build -t yurikrupnik/config-files .
nuds:
    nu config.nu app list