#!/usr/bin/env nu

use local/mod.nu *

def main [command?: string, ...args] {
  match $command {
    "install-flux" => {
      main install-flux
    }
    "install" => {
      if ($args | is-empty) {
        main install-deps
      } else {
        main install-deps ...$args
      }
    }
    "install-all" => {
      main install-deps --all
    }
    "status" => {
      main deps-status
    }
    "remove" => {
      if ($args | is-empty) {
        main remove-deps
      } else {
        main remove-deps ...$args
      }
    }
    "remove-all" => {
      main remove-deps --all
    }
    _ => {
      print "FluxCD Dependencies Management"
      print "Usage: nu flux-deps.nu <command> [args]"
      print ""
      print "Commands:"
      print "  install-flux         Install FluxCD itself"
      print "  install [deps...]     Install specific dependencies"
      print "  install-all          Install all dependencies"
      print "  status               Check status of dependencies"
      print "  remove [deps...]     Remove specific dependencies"
      print "  remove-all           Remove all dependencies"
      print ""
      print "Available dependencies: keda, prometheus, chaos, loki, external-secrets, crossplane"
    }
  }
}