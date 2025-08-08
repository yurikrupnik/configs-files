#!/usr/bin/env nu

# [FUNCTION TESTS] Bash Script Testing
# Tests bash scripts and shell commands used in the configuration

use std assert

# Get the repository root directory
const repo_root = "/Users/yurikrupnik/configs-files"

# [FUNCTION TEST] init.sh script validation
export def "test init-script-validation" [] {
    print "[FUNCTION TEST] Testing init.sh script validation"
    
    let init_script = $"($repo_root)/init.sh"
    assert ($init_script | path exists) "init.sh should exist"
    
    # Check if script is executable
    let file_info = (ls -la $init_script | get 0)
    let permissions = $file_info.mode
    assert ($permissions | str contains "x") "init.sh should be executable"
    
    # Check script content for basic structure
    let content = (open $init_script)
    assert ($content | str contains "#!/") "Script should have shebang"
    
    print "✓ init.sh script validation passed"
}

# [FUNCTION TEST] Nu setup script validation  
export def "test nu-setup-script" [] {
    print "[FUNCTION TEST] Testing setup-nu.sh script"
    
    let setup_script = $"($repo_root)/scripts/setup-nu.sh"
    assert ($setup_script | path exists) "setup-nu.sh should exist"
    
    # Check if script is executable
    let file_info = (ls -la $setup_script | get 0)
    let permissions = $file_info.mode
    assert ($permissions | str contains "x") "setup-nu.sh should be executable"
    
    print "✓ setup-nu.sh script validation passed"
}

# [FUNCTION TEST] Nu test script functionality
export def "test nu-test-script" [] {
    print "[FUNCTION TEST] Testing test-nu-functions.nu script"
    
    let test_script = $"($repo_root)/scripts/test-nu-functions.nu"
    assert ($test_script | path exists) "test-nu-functions.nu should exist"
    
    # Check script content
    let content = (open $test_script)
    assert ($content | str contains "help commands") "Script should test command availability"
    assert ($content | str contains "sys-update") "Script should test sys-update function"
    
    print "✓ test-nu-functions.nu script validation passed"
}

# [FUNCTION TEST] Shell script wrapper validation
export def "test shell-wrapper-scripts" [] {
    print "[FUNCTION TEST] Testing shell wrapper scripts"
    
    let wrapper_script = $"($repo_root)/scripts/nu-with-functions.sh"
    assert ($wrapper_script | path exists) "nu-with-functions.sh should exist"
    
    # Check if script is executable
    let file_info = (ls -la $wrapper_script | get 0)
    let permissions = $file_info.mode
    assert ($permissions | str contains "x") "nu-with-functions.sh should be executable"
    
    print "✓ Shell wrapper scripts validation passed"
}

# [FUNCTION TEST] Configuration file validation
export def "test config-file-structure" [] {
    print "[FUNCTION TEST] Testing configuration file structure"
    
    # Test Nu config files
    assert ($"($repo_root)/nu/.config/nu/config.nu" | path exists) "config.nu should exist"
    assert ($"($repo_root)/nu/.config/nu/functions.nu" | path exists) "functions.nu should exist"
    assert ($"($repo_root)/nu/.config/nu/env.nu" | path exists) "env.nu should exist"
    
    # Test other config files
    assert ($"($repo_root)/starship/.config/starship/starship.toml" | path exists) "starship.toml should exist"
    assert ($"($repo_root)/brew/Brewfile" | path exists) "Brewfile should exist"
    
    print "✓ Configuration file structure validation passed"
}

# [FUNCTION TEST] Devbox configuration validation
export def "test devbox-config" [] {
    print "[FUNCTION TEST] Testing devbox configuration"
    
    let devbox_config = $"($repo_root)/devbox.json"
    assert ($devbox_config | path exists) "devbox.json should exist"
    
    # Parse and validate JSON structure
    let config = (open $devbox_config)
    assert ($config.packages? != null) "devbox.json should have packages"
    
    print "✓ Devbox configuration validation passed"
}

# [FUNCTION TEST] Git configuration validation
export def "test git-integration" [] {
    print "[FUNCTION TEST] Testing git integration"
    
    # Check if we're in a git repository
    let git_dir = $"($repo_root)/.git"
    assert ($git_dir | path exists) "Should be in a git repository"
    
    # Test gitignore exists
    let gitignore = $"($repo_root)/.gitignore"
    assert ($gitignore | path exists) ".gitignore should exist"
    
    print "✓ Git integration validation passed"
}

# [FUNCTION TEST] Directory structure validation
export def "test directory-structure" [] {
    print "[FUNCTION TEST] Testing directory structure"
    
    let required_dirs = [
        $"($repo_root)/nu",
        $"($repo_root)/zsh", 
        $"($repo_root)/starship",
        $"($repo_root)/brew",
        $"($repo_root)/scripts",
        $"($repo_root)/tmp"
    ]
    
    for dir in $required_dirs {
        assert ($dir | path exists) $"Required directory should exist: ($dir)"
    }
    
    print "✓ Directory structure validation passed"
}

# [FUNCTION TEST] Temporary directory structure
export def "test temp-directory-structure" [] {
    print "[FUNCTION TEST] Testing temporary directory structure"
    
    let tmp_dirs = [
        $"($repo_root)/tmp/cache",
        $"($repo_root)/tmp/data", 
        $"($repo_root)/tmp/secrets",
        $"($repo_root)/tmp/workspace"
    ]
    
    for dir in $tmp_dirs {
        assert ($dir | path exists) $"Temp directory should exist: ($dir)"
    }
    
    print "✓ Temporary directory structure validation passed"
}

# Run all function tests
def main [] {
    print "=== [FUNCTION TESTS] Bash Script Testing ==="
    print ""
    
    test init-script-validation
    test nu-setup-script
    test nu-test-script
    test shell-wrapper-scripts
    test config-file-structure
    test devbox-config
    test git-integration
    test directory-structure
    test temp-directory-structure
    
    print ""
    print "=== [FUNCTION TESTS] All bash script tests passed! ==="
}