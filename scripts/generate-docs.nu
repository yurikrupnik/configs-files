#!/usr/bin/env nu

# Generate TypeDoc/Cargo Doc style documentation for KCL and Nu scripts

def main [
    --serve(-s)     # Serve the documentation locally
    --port: int = 8080  # Port to serve on
] {
    print "📚 Generating Scripts Documentation..."
    
    # Create docs directory structure
    create_docs_structure
    
    # Generate remaining module pages
    generate_remaining_modules
    
    # Copy assets
    copy_assets
    
    print "✅ Documentation generated successfully!"
    print $"📂 Documentation available at: (pwd)/docs/index.html"
    
    if $serve {
        serve_docs $port
    }
}

def create_docs_structure [] {
    print "📁 Creating documentation structure..."
    
    let dirs = [
        "docs/modules"
        "docs/css" 
        "docs/js"
        "docs/assets"
        "docs/search"
    ]
    
    $dirs | each { |dir|
        mkdir $dir
        print $"  Created: ($dir)"
    }
}

def generate_remaining_modules [] {
    print "📄 Generating module pages..."
    
    # Generate placeholder pages for remaining modules
    let modules = [
        {name: "kcl-service", type: "KCL", title: "service.k", description: "Kubernetes Service generation"}
        {name: "kcl-deployment", type: "KCL", title: "deployment.k", description: "Kubernetes Deployment generation"}
        {name: "kcl-complete-app", type: "KCL", title: "complete-app.k", description: "Complete application stack"}
        {name: "nu-app-management", type: "Nu", title: "app-management.nu", description: "Application lifecycle management"}
        {name: "nu-cloud-providers", type: "Nu", title: "cloud-providers.nu", description: "Multi-cloud provider support"}
        {name: "nu-secrets-management", type: "Nu", title: "secrets-management.nu", description: "Cross-platform secrets management"}
        {name: "nu-cluster-setup", type: "Nu", title: "cluster-setup.nu", description: "Comprehensive cluster setup"}
        {name: "nu-nx", type: "Nu", title: "nx.nu", description: "Nx monorepo management"}
        {name: "nu-local", type: "Nu", title: "local.nu", description: "Local development workflow"}
        {name: "nu-setup-shells", type: "Nu", title: "setup-shells.nu", description: "Shell environment setup"}
        {name: "nu-kc-cluster", type: "Nu", title: "kc-cluster.nu", description: "Kubernetes cluster operations"}
        {name: "nu-local-cluster", type: "Nu", title: "local/cluster.nu", description: "Extended cluster operations"}
        {name: "nu-infrastructure-setup", type: "Nu", title: "infrastructure-setup.nu", description: "Infrastructure provisioning"}
    ]
    
    $modules | each { |module|
        generate_module_page $module
    }
}

def generate_module_page [module: record] {
    let content = $"<!DOCTYPE html>
<html lang=\"en\">
<head>
    <meta charset=\"UTF-8\">
    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">
    <title>($module.title) - Scripts Documentation</title>
    <link rel=\"stylesheet\" href=\"../css/main.css\">
    <link rel=\"stylesheet\" href=\"https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/github.min.css\">
    <script src=\"https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js\"></script>
</head>
<body>
    <div class=\"container\">
        <nav class=\"sidebar\">
            <div class=\"sidebar-header\">
                <h1><a href=\"../index.html\">Scripts Documentation</a></h1>
            </div>
        </nav>
        
        <main class=\"content\">
            <header class=\"page-header\">
                <h1><code>($module.title)</code></h1>
                <p class=\"subtitle\">($module.description)</p>
                <div class=\"module-badges\">
                    <span class=\"badge badge-($module.type | str downcase)\">($module.type)</span>
                </div>
            </header>
            
            <section class=\"section\">
                <h2>Overview</h2>
                <p>This module provides ($module.description | str downcase) functionality.</p>
                
                <div class=\"coming-soon\">
                    <h3>🚧 Documentation In Progress</h3>
                    <p>Detailed documentation for this module is being generated. Please check back soon or refer to the source code directly.</p>
                    
                    <div class=\"source-links\">
                        <a href=\"#\" class=\"source-link\">📄 View Source Code</a>
                        <a href=\"../index.html\" class=\"source-link\">🏠 Back to Home</a>
                    </div>
                </div>
            </section>
        </main>
    </div>
    
    <script src=\"../js/main.js\"></script>
    
    <style>
        .badge-kcl { background-color: #2563eb; color: white; }
        .badge-nu { background-color: #059669; color: white; }
        
        .coming-soon {
            background-color: var(--surface);
            padding: 2rem;
            border-radius: 0.5rem;
            border: 1px solid var(--border);
            text-align: center;
            margin-top: 2rem;
        }
        
        .coming-soon h3 {
            color: var(--primary-color);
            margin-bottom: 1rem;
        }
        
        .source-links {
            display: flex;
            justify-content: center;
            gap: 1rem;
            margin-top: 1.5rem;
        }
        
        .source-link {
            display: inline-block;
            padding: 0.75rem 1.5rem;
            background-color: var(--primary-color);
            color: white;
            text-decoration: none;
            border-radius: 0.375rem;
            font-weight: 500;
            transition: all 0.15s ease;
        }
        
        .source-link:hover {
            background-color: var(--primary-dark);
            transform: translateY(-1px);
        }
    </style>
</body>
</html>"

    let filepath = $"docs/modules/($module.name).html"
    $content | save $filepath
    print $"  Generated: ($filepath)"
}

def copy_assets [] {
    print "📋 Copying additional assets..."
    
    # Create a README for the docs directory
    let readme = "# Generated Documentation

This directory contains auto-generated documentation for the KCL and Nu shell scripts.

## Structure

- `index.html` - Main documentation homepage
- `modules/` - Individual module documentation pages
- `css/` - Stylesheets (TypeDoc/Cargo Doc inspired)
- `js/` - Interactive functionality (search, navigation)

## Viewing

Open `index.html` in a web browser or serve with:

```bash
nu scripts/generate-docs.nu --serve
```

## Regeneration

To regenerate the documentation:

```bash
nu scripts/generate-docs.nu
```

*Documentation generated on $(date now)*"

    $readme | save "docs/README.md"
    print "  Created: docs/README.md"
}

def serve_docs [port: int] {
    print $"🌐 Starting documentation server on port ($port)..."
    print $"🔗 Open http://localhost:($port) in your browser"
    print "📡 Press Ctrl+C to stop the server"
    
    try {
        # Try different server options
        if (which python | length) > 0 {
            cd docs
            python -m http.server $port
        } else if (which python3 | length) > 0 {
            cd docs  
            python3 -m http.server $port
        } else if (which serve | length) > 0 {
            cd docs
            serve -p $port
        } else {
            print "❌ No HTTP server found. Install python or serve."
            print $"💡 You can manually open docs/index.html in your browser"
        }
    } catch {
        print $"❌ Failed to start server on port ($port)"
        print $"💡 Try a different port: nu scripts/generate-docs.nu --serve --port 3000"
    }
}

# Generate search index
def generate_search_index [] {
    print "🔍 Generating search index..."
    
    let search_data = [
        {title: "local/mod.nu", type: "Module", url: "modules/nu-local-mod.html", description: "Main cluster management module"}
        {title: "flux-helm.k", type: "Module", url: "modules/kcl-flux-helm.html", description: "FluxCD HelmRelease generation"}
        {title: "flux-deps.nu", type: "Module", url: "modules/nu-flux-deps.html", description: "FluxCD dependency management"}
        # Add more search entries as needed
    ]
    
    $search_data | to json | save "docs/search/index.json"
    print "  Created: docs/search/index.json"
}

# Helper function to check if documentation is up to date
def "main check" [] {
    print "🔍 Checking documentation status..."
    
    let docs_exist = ("docs/index.html" | path exists)
    if not $docs_exist {
        print "❌ Documentation not found. Run 'nu scripts/generate-docs.nu' to generate."
        return
    }
    
    let docs_time = ("docs/index.html" | path expand | stat | get modified)
    let script_files = (glob "scripts/**/*.nu" | append (glob "scripts/**/*.k"))
    
    let outdated_files = $script_files | where {|file|
        let file_time = ($file | stat | get modified)
        $file_time > $docs_time
    }
    
    if ($outdated_files | length) > 0 {
        print "⚠️  Documentation is outdated. Modified files:"
        $outdated_files | each { |file| print $"  - ($file)" }
        print "\nRun 'nu scripts/generate-docs.nu' to regenerate."
    } else {
        print "✅ Documentation is up to date."
    }
}

# Quick serve function
def "main serve" [--port: int = 8080] {
    if not ("docs/index.html" | path exists) {
        print "❌ Documentation not found. Generating first..."
        main
    }
    serve_docs $port
}