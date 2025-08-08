# Test Suite Documentation

This directory contains comprehensive tests for the configs-files repository, organized by test type with clear labeling.

## Test Types

### **[UNIT TESTS]** - `unit/`
Tests individual functions and components in isolation.

- **`test_nu_functions.nu`** - Tests Nu shell function definitions and basic functionality
- Tests function existence, basic parameter validation, and return types
- Focuses on single function behavior without external dependencies

### **[FUNCTION TESTS]** - `functions/`  
Tests specific function behaviors with various inputs and edge cases.

- **`test_individual_functions.nu`** - Tests Nu functions with different scenarios and inputs
- **`test_bash_scripts.nu`** - Tests bash scripts, configuration files, and directory structure
- Validates function logic, error handling, and cross-platform compatibility

### **[INTEGRATION TESTS]** - `integration/`
Tests integration between different components and workflows.

- **`test_shell_workflows.nu`** - Tests workflow integration between git, docker, kubernetes, and development tools
- Validates that components work together correctly
- Tests environment variable integration and cross-component communication

### **[E2E TESTS]** - `e2e/`
End-to-end tests for complete workflows from start to finish.

- **`test_full_setup_workflow.nu`** - Tests complete development environment setup
- Validates entire user workflows from environment setup to cleanup
- Tests real-world usage scenarios and multi-step processes

## Running Tests

### Run All Tests
```bash
nu tests/run_all_tests.nu
```

### Run Specific Test Type
```bash
# Unit tests only
nu tests/run_all_tests.nu --type unit

# Function tests only  
nu tests/run_all_tests.nu --type function

# Integration tests only
nu tests/run_all_tests.nu --type integration

# E2E tests only
nu tests/run_all_tests.nu --type e2e
```

### Run Individual Test Files
```bash
# Unit tests
nu tests/unit/test_nu_functions.nu

# Function tests
nu tests/functions/test_individual_functions.nu
nu tests/functions/test_bash_scripts.nu

# Integration tests
nu tests/integration/test_shell_workflows.nu

# E2E tests
nu tests/e2e/test_full_setup_workflow.nu
```

## Test Coverage

### Components Tested

1. **Nu Shell Functions** (`nu/.config/nu/functions.nu`)
   - System utilities (CPU detection, parallel execution)
   - Git workflow shortcuts (gs, ga, gc, gp)
   - Kubernetes management (knd, ad, ku, kc)  
   - Development workflow (sys-update, nx-run, projects)
   - Docker helpers (dps, dclean, psg)
   - Security functions (load-secrets, cleanup-secrets, secure-file)

2. **Configuration Files**
   - Nu shell configuration (`nu/.config/nu/`)
   - Starship configuration (`starship/.config/starship/`)
   - Devbox configuration (`devbox.json`)
   - Brew packages (`brew/Brewfile`)

3. **Setup Scripts**
   - Main initialization (`init.sh`)
   - Nu shell setup (`scripts/setup-nu.sh`)
   - Test validation (`scripts/test-nu-functions.nu`)

4. **Workflows**
   - Git integration and shortcuts
   - Docker container management
   - Kubernetes cluster operations
   - Development environment setup
   - Security and secrets management
   - Cross-platform compatibility

### Test Assertions

Each test type uses specific assertion patterns:

- **Unit Tests**: Function existence, basic parameter validation, return types
- **Function Tests**: Input/output validation, edge cases, error handling
- **Integration Tests**: Component interaction, workflow continuity, environment integration
- **E2E Tests**: Complete workflow validation, real-world scenarios, end-user experience

## Test Environment Requirements

### Minimal Requirements
- Nu shell installed and configured
- Basic shell environment (HOME, USER environment variables)
- Git repository context

### Full Test Environment
- Docker (for container management tests)
- kubectl (for Kubernetes workflow tests)  
- Git (for version control workflow tests)
- Standard Unix tools (for cross-platform tests)

### Optional Dependencies
- Kind (for cluster creation tests)
- Helm (for Kubernetes package management tests)
- Various CLI tools from Brewfile

## Adding New Tests

### Test Naming Convention
- File names: `test_<component>_<type>.nu`
- Function names: `test <specific-functionality>`
- Test labels: `[TEST TYPE]` in comments and output

### Test Structure Template
```nu
#!/usr/bin/env nu

# [TEST TYPE] Description
# Purpose and scope of tests

use std assert
source ../../path/to/functions.nu  # If needed

# [TEST TYPE] Specific test description
export def "test specific-functionality" [] {
    print "[TEST TYPE] Testing specific functionality"
    
    # Test implementation
    assert (condition) "Error message"
    
    print "✓ Test passed"
}

# Run all tests in file
def main [] {
    print "=== [TEST TYPE] Test Suite Name ==="
    print ""
    
    test specific-functionality
    # Add more test calls
    
    print ""
    print "=== [TEST TYPE] All tests passed! ==="
}
```

### Adding Tests to Runner
Update `run_all_tests.nu` to include new test files in the appropriate test type section.

## Continuous Integration

Tests are designed to run in CI environments with:
- Graceful handling of missing optional dependencies
- Clear pass/fail indicators for CI systems
- Minimal external dependencies for basic functionality tests
- Comprehensive coverage for development environment validation