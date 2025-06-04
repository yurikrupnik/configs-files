# dashboard.nu

# Import other scripts
source sysinfo.nu
source services.nu

# Define custom styles
let blue_header = { fg: "blue", attr: "b" }
let green_ok = { fg: "green", attr: "b" }
let red_err = { fg: "red", attr: "b" }

def main [] {
  clear

  print (ansi { fg: "yellow", attr: "b" }) "=== 🖥️ Nushell System Dashboard ==="
  print ""

  # Show system info
  print (ansi $blue_header) "→ System Information"
  show-sysinfo

  print ""
  # Show running services
  print (ansi $blue_header) "→ Services Status"
  check-services

  print ""
  print (ansi { fg: "dark_gray" }) "Run 'main' to refresh the dashboard"
}