#!/usr/bin/env nu

# Setup script for unified shell configuration
def main [action?: string = "setup"] {
    match $action {
        "setup" => { setup_configs }
        "unstow" => { unstow_configs }
        _ => {
            print "❌ Invalid action. Use 'setup' or 'unstow'"
            exit 1
        }
    }
}

def setup_configs [] {
    print "🚀 Setting up unified shell configuration..."
    
    # Generate shell configs
    nu ~/configs-files/scripts/generate-shell-configs.nu
    
    # Make scripts executable
    chmod +x ~/configs-files/scripts/kc-cluster.nu
    chmod +x ~/configs-files/scripts/generate-shell-configs.nu
    chmod +x ~/configs-files/scripts/setup-shells.nu
    
    # Use stow to manage configurations
    print "📦 Using stow to manage configurations..."
    cd ~/configs-files
    stow -R zsh
    stow -R nu 
    stow -R fish
    stow -R zed
    stow -R claude
    stow -R starship

    print "✅ Shell configuration setup complete!"
    print "\n📋 Usage:"
    print "• Run `nu ~/configs-files/scripts/generate-shell-configs.nu` to regenerate configs"
    print "• Edit `~/configs-files/shells/config.toml` to modify shared configurations"
    print "• Add complex functions to `~/configs-files/scripts/` directory"
    print "• Use any shell (zsh/fish/nu) - they'll have the same functions!"
}

def unstow_configs [] {
    print "🗑️  Removing stow-managed configurations..."
    
    cd ~/configs-files
    let packages = ["zsh", "nu", "fish", "zed", "claude", "starship"]
    
    for package in $packages {
        print $"📤 Unstowing ($package)..."
        stow -D $package
    }
    
    print "✅ All configurations unstowed successfully!"
    print "\n📋 To re-setup configurations, run:"
    print "• `nu ~/configs-files/scripts/setup-shells.nu setup`"
}