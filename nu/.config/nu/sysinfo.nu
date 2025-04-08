# sysinfo.nu

def show-sysinfo [] {
  try {
    let sysinfo = sys | select host uptime load memory
    $sysinfo
  } catch {
    print (ansi { fg: "red", attr: "b" }) "Error: Cannot fetch system info. Are you running in a compatible shell?"
  }
}