# $env.config.buffer_editor = 'code'
# source ($nu.default-config-dir | path join "myfile.nu")
# Starship prompt
use std "assert"
$env.PROMPT_COMMAND = { || starship prompt --cmd-duration $env.CMD_DURATION_MS $"--status=($env.LAST_EXIT_CODE)" }
$env.PROMPT_COMMAND_RIGHT = { || starship prompt --right --cmd-duration $env.CMD_DURATION_MS $"--status=($env.LAST_EXIT_CODE)" }

# Define module and source search path
# const NU_LIB_DIRS = [
#   '~/functions'
# ]
# # Load myscript.nu from the ~/myscripts directory
# source functions.nu

# Nu shell configuration
alias gs = git status
# Source custom functions
#
# source ~/.config/nushell/config.nu
source ~/configs-files/nu/.config/nu/env.nu
source ~/configs-files/nu/.config/nu/functions.nu
source ~/configs-files/nu/.config/nu/services.nu
source ~/configs-files/nu/.config/nu/sysinfo.nu
# nu -c "source ~/.config/nushell/config.nu; main delete temp_files"

# History settings
$env.config = {
    show_banner: false
    history: {
        max_size: 100_000
        sync_on_enter: true
        # file_format: "sqlite"
    }
    completions: {
        quick: true
        partial: true
        algorithm: "fuzzy"
    }
}
