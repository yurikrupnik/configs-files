# Task Manager

A Rust TUI application for managing go-task Taskfiles with KCL schema validation.

## Features

- **Interactive TUI**: Browse, create, edit, and delete tasks using a terminal interface
- **KCL Validation**: Validate Taskfile structure using KCL schemas
- **Task Execution**: Run tasks directly from the interface
- **Search & Filter**: Find tasks quickly with fuzzy search
- **Live Validation**: Real-time validation feedback
- **Configuration**: Customizable themes and keybindings

## Prerequisites

- [Rust](https://rustup.rs/) (latest stable)
- [go-task](https://taskfile.dev/) for task execution
- [KCL](https://kcl-lang.io/) for schema validation (optional)

## Installation

```bash
git clone <repository>
cd task-manager
cargo build --release
```

## Usage

### Basic Usage

```bash
# Run with default Taskfile.yml
./target/release/task-manager

# Specify a custom taskfile
./target/release/task-manager -f MyTaskfile.yml

# Use custom configuration
./target/release/task-manager -c config.yml
```

### Keybindings

| Key | Action |
|-----|--------|
| `q` | Quit application |
| `?` | Toggle help |
| `s` | Save taskfile |
| `v` | Validate with KCL |
| `/` | Search tasks |
| `n` | New task |
| `e` | Edit selected task |
| `d` | Delete selected task |
| `r` | Run selected task |
| `Enter` | View task details |
| `j/k` or `↑/↓` | Navigate |
| `Esc` | Cancel current operation |

### Modes

1. **Task List**: Browse and manage tasks
2. **Task View**: View detailed task information
3. **Task Edit**: Create or modify tasks
4. **Search**: Filter tasks by name
5. **Validation**: View KCL validation results
6. **Help**: Display keybindings

## Configuration

The application creates a default configuration at `~/.config/task-manager/config.yml`:

```yaml
default_taskfile: "Taskfile.yml"
editor: "nvim"
auto_save: true
backup_enabled: true
backup_dir: ".task-backups"
kcl_schema_path: "schemas/taskfile.k"

theme:
  primary_color: "blue"
  secondary_color: "cyan" 
  error_color: "red"
  success_color: "green"
  warning_color: "yellow"
  background: "black"
  foreground: "white"

keybindings:
  quit: "q"
  save: "s"
  new_task: "n"
  edit_task: "e"
  delete_task: "d"
  run_task: "r"
  toggle_help: "?"
  validate: "v"
  search: "/"
  reload: "R"
```

## KCL Schema

The application includes a comprehensive KCL schema for go-task Taskfiles based on the official JSON schema. The schema validates:

- Taskfile structure and version
- Task definitions and properties
- Commands and dependencies
- Variables and environment settings
- Includes and platform specifications

## Architecture

### Modules

- **app.rs**: Main application state and TUI rendering
- **taskfile.rs**: Taskfile parsing and manipulation
- **kcl.rs**: KCL validation integration
- **config.rs**: Configuration management
- **cli.rs**: go-task CLI integration
- **tui.rs**: Terminal interface setup

### Key Features

- **Async Runtime**: Built on Tokio for responsive UI
- **Schema Validation**: Integrated KCL validation
- **File Watching**: Auto-reload on external changes
- **Backup System**: Automatic backups before saves
- **Error Handling**: Comprehensive error reporting

## Development

### Building

```bash
cargo build
cargo test
cargo clippy
```

### Dependencies

- `ratatui`: TUI framework
- `crossterm`: Cross-platform terminal
- `serde`: Serialization
- `tokio`: Async runtime
- `anyhow`: Error handling
- `clap`: CLI parsing

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

MIT License