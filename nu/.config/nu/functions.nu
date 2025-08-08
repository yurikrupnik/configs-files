#!/usr/bin/env nu

# Kubernetes namespace switcher
export def knd [namespace: string] {
    kubectl config set-context --current --namespace=$namespace
}

# Show available contexts
export def ad [] {
    kubectx
}

# Unset current kubectl context
export def ku [] {
    kubectl config unset current-context
}

# Update system packages and tools
export def sys-update [] {
    print "Updating brew packages..."
    brew bundle --file ~/configs-files/brew/Brewfile
    print "Updating Rust toolchain..."
    rustup update
}

# Create new Nx workspace with Rust preset
export def stam [] {
    cd ~/projects/
    npx create-nx-workspace --pm pnpm --preset=@monodon/rust
    bun exec nx generate @monodon/rust:library --name=s --directory=aris --no-interactive --dry-run
    bun add -D @nxlv/python
    uv init
}

# Run Nx command on all projects
export def nx-run [task: string] {
    bun nx run-many -t $task --parallel --max-parallel=10 --prod
}

# Run Nx command on affected projects
export def nx-runa [task: string] {
    bun nx affected -t $task --parallel --max-parallel=10 --prod
}

# Create kind cluster with Istio
export def kc [] {
    kind create cluster
    sleep 20sec
    istioctl install --set profile=demo -y
    kubectl create namespace argocd
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.1.0/standard-install.yaml

}

# Git shortcuts
export def gs [] {
    git status
}

export def ga [file?: string] {
    if ($file == null) {
        git add .
    } else {
        git add $file
    }
}

export def gc [message: string] {
    git commit -m $message
}

export def gp [] {
    git push
}

# Directory navigation helpers
export def projects [] {
    cd ~/projects
}

export def configs [] {
    cd ~/configs-files
}

# System information with formatting
export def sysinfo [] {
    print $"(ansi green)System Information:(ansi reset)"
    print $"Host: (sys host | get hostname)"
    print $"Memory: (sys mem)"
    print $"CPUs: (sys cpu | length)"

    dclean
}

# Docker helpers
export def dps [] {
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
}

export def dclean [] {
    docker system prune -f
    docker volume prune -f
}

# Process management
export def psg [pattern: string] {
    ps | where name =~ $pattern
}

def "main get provider" [
    --providers = [kind aws azure google upcloud]  # List of cloud providers to choose from (kind first as default)
] {

    let message = $"
Right now, only providers listed below are supported in this demo.
Please send an email to (ansi yellow_bold)viktor@farcic.com(ansi reset) if you'd like to add additional providers.

(ansi yellow_bold)Select a provider(ansi green_bold)"

    let provider = $providers | input list $message
    print $"(ansi reset)"

    # Update or add PROVIDER in .env file
    let env_content = if (".env" | path exists) { open .env } else { "" }
    let updated_content = if ($env_content | str contains "PROVIDER=") {
        $env_content | str replace --regex "PROVIDER=.*" $"PROVIDER=($provider)"
    } else {
        if ($env_content | str trim | is-empty) {
            $"PROVIDER=($provider)"
        } else {
            $"($env_content)PROVIDER=($provider)\n"
        }
    }
    $updated_content | save --force .env

    $provider
}

# Prints a reminder to source the environment variables
def "main print source" [] {

    print $"
Execute `(ansi yellow_bold)source .env(ansi reset)` to load the environment variables.
"

}



# Removes temporary files created during script execution
def "main delete temp_files" [] {

    rm --force .env

    rm --force kubeconfig*.yaml

}