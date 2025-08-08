##!/bin/bash
#
## Setup Nu shell configuration globally
#
#echo "Setting up Nu shell configuration..."
#
## Create Nu config directory if it doesn't exist
#mkdir -p ~/.config/nushell
#
## Remove old symlinks if they exist
#rm -f ~/Library/Application\ Support/nushell/*.nu
#
## Create symlinks to our Nu configuration files
#ln -sf ~/configs-files/nu/.config/nu/config.nu ~/.config/nushell/config.nu
#ln -sf ~/configs-files/nu/.config/nu/env.nu ~/.config/nushell/env.nu
#ln -sf ~/configs-files/nu/.config/nu/functions.nu ~/.config/nushell/functions.nu
#ln -sf ~/configs-files/nu/.config/nu/services.nu ~/.config/nushell/services.nu
#ln -sf ~/configs-files/nu/.config/nu/sysinfo.nu ~/.config/nushell/sysinfo.nu
#
#echo "Nu shell configuration linked successfully!"
#echo "Your custom functions are now available globally in Nu shell."
#echo ""
#echo "Available functions:"
#echo "  knd <namespace>  - Switch kubectl namespace"
#echo "  ad               - Show kubectl contexts"
#echo "  ku               - Unset kubectl context"
#echo "  update           - Update brew packages and Rust"
#echo "  stam             - Create Nx workspace"
#echo "  nx-run <task>    - Run Nx task on all projects"
#echo "  nx-runa <task>   - Run Nx task on affected projects"
#echo "  kc               - Create kind cluster with Istio"
#echo "  gs               - Git status"
#echo "  ga [file]        - Git add"
#echo "  gc <message>     - Git commit"
#echo "  gp               - Git push"
#echo "  projects         - Navigate to ~/projects"
#echo "  configs          - Navigate to ~/configs-files"
#echo "  sysinfo          - Show system information"
#echo "  dps              - Docker ps with formatting"
#echo "  dclean           - Clean Docker system"
#echo "  psg <pattern>    - Search processes"