# services.nu

# Mock service checker
def check-services [] {
  let services = [
    { name: "nginx", status: "running" },
    { name: "loki", status: "running" },
    { name: "crossplane", status: "running" },
    { name: "prometheus", status: "running" },
    { name: "external-secrets", status: "running" },
    { name: "flux", status: "running" },
    { name: "flagger", status: "running" },
    { name: "argocd", status: "running" },
    { name: "argo-wrokflows", status: "running" },
    { name: "argo-rollouts", status: "running" },
    { name: "argo-events", status: "running" },
    { name: "postgres", status: "running" },
    { name: "redis", status: "stopped" }
  ]

  $services
  | each { |s|
      if $s.status == "running" {
        $s | update status $"(ansi green)($s.status)(ansi reset)"
      } else {
        $s | update status $"(ansi red)($s.status)(ansi reset)"
      }
    }
  | table
}