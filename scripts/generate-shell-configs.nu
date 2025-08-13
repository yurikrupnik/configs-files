#!/usr/bin/env nu

# Generate shell configurations from unified config
# --path: str = "~/configs-files/shells/config.toml"
def main [
    repo?: string = "~/configs-files/shells/config.toml"
    --path: string = "~/configs-files/shells/config.toml"
] {
    print $path
    print $repo
    # print $env
    let config = open ~/configs-files/shells/config.toml
    #print $config
    generate-zsh $config
    generate-fish $config
    #generate-nu $config

    print "✅ Generated configurations for all shells"
}

def generate-zsh [config] {
    let zsh_dir = "~/configs-files/zsh/.config/zsh"
    mkdir $zsh_dir
    mut content = "# Generated from shells/config.toml\n\n"
    # Aliases
    for alias in ($config.aliases | transpose key value) {
        $content = $content + $"alias ($alias.key)='($alias.value)'\n"
    }

    $content = $content + "\n"
    # Functions
    for func in ($config.functions | transpose key value) {
        $content = $content + $"($func.key)" + "() {\n"
        if "type" in $func.value and $func.value.type == "complex" {
            # Complex functions call Nu scripts with arguments
            $content = $content + $"    nu ($func.value.script) \"$@\"\n"
        } else if "commands" in $func.value {
            for cmd in $func.value.commands {
                let processed_cmd = ($cmd | str replace "{arg}" '$1')
                $content = $content + $"    ($processed_cmd)\n"
            }
        } else {
            let cmd = if "args" in $func.value {
                mut processed_cmd = $func.value.command
                for i in 0..($func.value.args | length) {
                    $processed_cmd = ($processed_cmd | str replace "{arg}" $"$($i + 1)")
                }
                $processed_cmd
            } else {
                ($func.value.command | str replace "{arg}" '$1')
            }
            $content = $content + $"    ($cmd)\n"
        }
        $content = $content + "}\n\n"
        print $content
    }

    $content | save --force $"($zsh_dir)/generated.zsh"
}

def generate-fish [config] {
    let fish_dir = ($env.HOME | path join "configs-files/fish/.config/fish")
    let functions_dir = ($fish_dir | path join "functions")
    mkdir $fish_dir
    mkdir $functions_dir

    # Create aliases file
    mut aliases_content = "# Generated from shells/config.toml\n\n"
    for alias in ($config.aliases | transpose key value) {
        $aliases_content = $aliases_content + $"alias ($alias.key) '($alias.value)'\n"
    }
    $aliases_content | save --force ($fish_dir | path join "generated_aliases.fish")

    # Create individual function files
    for func in ($config.functions | transpose key value) {
        mut func_content = $"# Generated from shells/config.toml\n"
        if "description" in $func.value {
            $func_content = $func_content + $"# ($func.value.description)\n"
        }
        $func_content = $func_content + $"\nfunction ($func.key)\n"

        if "type" in $func.value and $func.value.type == "complex" {
            # Complex functions call Nu scripts with arguments
            $func_content = $func_content + $"    nu ($func.value.script) $argv\n"
        } else if "commands" in $func.value {
            for cmd in $func.value.commands {
                let processed_cmd = ($cmd | str replace "{arg}" '$argv[1]')
                $func_content = $func_content + $"    ($processed_cmd)\n"
            }
        } else {
            let cmd = ($func.value.command | str replace "{arg}" '$argv[1]')
            $func_content = $func_content + $"    ($cmd)\n"
        }
        $func_content = $func_content + "end\n"

        $func_content | save --force ($functions_dir | path join $"($func.key).fish")
    }
}

def generate-nu [config] {
    let nu_dir = "~/configs-files/nu/.config/nu"
    mkdir $nu_dir

    mut content = "# Generated from shells/config.toml\n\n"

    # Aliases
    for alias in ($config.aliases | transpose key value) {
        $content = $content + $"export alias ($alias.key) = ($alias.value)\n"
    }

    $content = $content + "\n"

    # Functions
    for func in ($config.functions | transpose key value) {
        if "type" in $func.value and $func.value.type == "complex" {
            # Complex functions - keep original implementation or source from script
            $content = $content + $"# Complex function ($func.key) - use original implementation\n"
            $content = $content + $"# Or source from: ($func.value.script)\n\n"
        } else if "commands" in $func.value {
            let args = if "args" in $func.value { $func.value.args.0 } else { "arg" }
            $content = $content + $"export def ($func.key) [($args): string] {\n"
            for cmd in $func.value.commands {
                let processed_cmd = ($cmd | str replace "{arg}" $"$($args)")
                $content = $content + $"    ^($processed_cmd)\n"
            }
            $content = $content + "}\n\n"
        } else {
            let args = if "args" in $func.value { $func.value.args.0 } else { "arg" }
            let cmd = ($func.value.command | str replace "{arg}" $"$($args)")
            $content = $content + $"export def ($func.key) [($args): string] {\n"
            $content = $content + $"    ^($cmd)\n"
            $content = $content + "}\n\n"
        }
    }

    $content | save --force $"($nu_dir)/generated.nu"
}
