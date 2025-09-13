#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ROOT="${PWD}"
FAILED_TESTS=()
PASSED_TESTS=()

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to detect project type and run appropriate tests
run_tests_for_project() {
    local project_dir="$1"
    local project_name=$(basename "$project_dir")
    
    log_info "Testing project: $project_name"
    cd "$project_dir"
    
    # Node.js/TypeScript projects
    if [[ -f "package.json" ]]; then
        if command -v npm &> /dev/null; then
            log_info "Running Node.js tests for $project_name"
            if npm test 2>/dev/null || npm run test 2>/dev/null || npm run test:unit 2>/dev/null; then
                log_success "Node.js tests passed for $project_name"
                PASSED_TESTS+=("$project_name (Node.js)")
            else
                log_warning "No npm test script found or tests failed for $project_name"
                # Try alternative test runners
                if [[ -f "vitest.config.js" ]] || [[ -f "vitest.config.ts" ]]; then
                    if command -v vitest &> /dev/null; then
                        if vitest run; then
                            log_success "Vitest tests passed for $project_name"
                            PASSED_TESTS+=("$project_name (Vitest)")
                        else
                            log_error "Vitest tests failed for $project_name"
                            FAILED_TESTS+=("$project_name (Vitest)")
                        fi
                    else
                        log_warning "Vitest config found but vitest not installed in $project_name"
                    fi
                elif command -v bun &> /dev/null && [[ -f "bun.lockb" ]]; then
                    if bun test; then
                        log_success "Bun tests passed for $project_name"
                        PASSED_TESTS+=("$project_name (Bun)")
                    else
                        log_error "Bun tests failed for $project_name"
                        FAILED_TESTS+=("$project_name (Bun)")
                    fi
                else
                    log_warning "No test configuration found for $project_name"
                fi
            fi
        fi
    fi
    
    # Rust projects
    if [[ -f "Cargo.toml" ]]; then
        if command -v cargo &> /dev/null; then
            log_info "Running Rust tests for $project_name"
            if cargo test; then
                log_success "Rust tests passed for $project_name"
                PASSED_TESTS+=("$project_name (Rust)")
            else
                log_error "Rust tests failed for $project_name"
                FAILED_TESTS+=("$project_name (Rust)")
            fi
        fi
    fi
    
    # Go projects
    if [[ -f "go.mod" ]]; then
        if command -v go &> /dev/null; then
            log_info "Running Go tests for $project_name"
            if go test ./...; then
                log_success "Go tests passed for $project_name"
                PASSED_TESTS+=("$project_name (Go)")
            else
                log_error "Go tests failed for $project_name"
                FAILED_TESTS+=("$project_name (Go)")
            fi
        fi
    fi
    
    # Python projects
    if [[ -f "pytest.ini" ]] || [[ -f "pyproject.toml" ]] || [[ -f "requirements.txt" ]]; then
        if command -v pytest &> /dev/null; then
            log_info "Running Python tests for $project_name"
            if pytest; then
                log_success "Python tests passed for $project_name"
                PASSED_TESTS+=("$project_name (Python)")
            else
                log_error "Python tests failed for $project_name"
                FAILED_TESTS+=("$project_name (Python)")
            fi
        elif command -v python &> /dev/null; then
            if python -m pytest; then
                log_success "Python tests passed for $project_name"
                PASSED_TESTS+=("$project_name (Python)")
            else
                log_error "Python tests failed for $project_name"
                FAILED_TESTS+=("$project_name (Python)")
            fi
        fi
    fi
    
    # KCL files
    if find . -maxdepth 1 -name "*.k" -type f | head -1 | grep -q .; then
        if command -v kcl &> /dev/null; then
            log_info "Running KCL validation for $project_name"
            # Use a more robust way to run KCL validation
            kcl_files=$(find . -maxdepth 1 -name "*.k" -type f)
            if [[ -n "$kcl_files" ]]; then
                if kcl run $kcl_files; then
                    log_success "KCL validation passed for $project_name"
                    PASSED_TESTS+=("$project_name (KCL)")
                else
                    log_error "KCL validation failed for $project_name"
                    FAILED_TESTS+=("$project_name (KCL)")
                fi
            else
                log_warning "No KCL files found in $project_name"
            fi
        fi
    fi
    
    cd "$PROJECT_ROOT"
}

# Main execution
main() {
    log_info "Starting unified test runner..."
    log_info "Project root: $PROJECT_ROOT"
    
    # If a specific directory is provided, test only that
    if [[ -n "$1" ]]; then
        if [[ -d "$1" ]]; then
            run_tests_for_project "$1"
        else
            log_error "Directory $1 does not exist"
            exit 1
        fi
    else
        # Find all projects and run tests
        log_info "Scanning for projects..."
        
        # Test current directory
        run_tests_for_project "."
        
        # Find subdirectories with project files
        find . -maxdepth 3 -type f \( -name "package.json" -o -name "Cargo.toml" -o -name "go.mod" -o -name "pyproject.toml" \) -exec dirname {} \; | sort -u | while read -r project_dir; do
            if [[ "$project_dir" != "." ]]; then
                run_tests_for_project "$project_dir"
            fi
        done
    fi
    
    # Summary
    echo ""
    log_info "=== Test Summary ==="
    
    if [[ ${#PASSED_TESTS[@]} -gt 0 ]]; then
        log_success "Passed tests (${#PASSED_TESTS[@]}):"
        for test in "${PASSED_TESTS[@]}"; do
            echo -e "  ${GREEN}✓${NC} $test"
        done
    fi
    
    if [[ ${#FAILED_TESTS[@]} -gt 0 ]]; then
        log_error "Failed tests (${#FAILED_TESTS[@]}):"
        for test in "${FAILED_TESTS[@]}"; do
            echo -e "  ${RED}✗${NC} $test"
        done
        echo ""
        log_error "Some tests failed!"
        exit 1
    else
        echo ""
        log_success "All tests passed! 🎉"
        exit 0
    fi
}

# Handle script arguments
case "$1" in
    --help|-h)
        echo "Usage: $0 [directory]"
        echo "  Run tests for all projects or a specific directory"
        echo "  Supports: Node.js, Rust, Go, Python, KCL"
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac
