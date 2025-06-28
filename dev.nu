#!/usr/bin/env nu

# Nu Shell Initialization Script
use std log

# Configuration
const BREW_BUNDLE_PATH = "brew/Brewfile"
const NUSHELL_CONFIG_DIR = ".config/nu"

# Source initialization modules
source scripts/nu-scripts/init/system-setup.nu
# npx @modelcontextprotocol/inspector