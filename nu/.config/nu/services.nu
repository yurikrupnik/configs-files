# services.nu

# Mock service checker
def check-services [] {
  let services = [
    { name: "nginx", status: "running" },
    { name: "postgres", status: "running" },
    { name: "redis", status: "stopped" }
  ]

  $services
  | each { |s|
      if $s.status == "running" {
        $s | update status (ansi { fg: "green" }) ($s.status)
      } else {
        $s | update status (ansi { fg: "red" }) ($s.status)
      }
    }
  | table
}