# Nu shell environment configuration

# Set config directory to use ~/.config/nushell
$env.XDG_CONFIG_HOME = ($env.HOME | path join ".config")

# PATH setup
$env.PATH = ($env.PATH | split row (char esep) | append [
    ($env.HOME | path join ".cargo" "bin")
    "/usr/local/bin"
    "/opt/homebrew/bin"
])

# Shell integrations
$env.STARSHIP_SHELL = "nu"
