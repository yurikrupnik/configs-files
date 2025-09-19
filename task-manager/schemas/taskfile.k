"""
KCL schema for go-task Taskfile configuration
Converted from official JSON schema at https://taskfile.dev/schema.json
"""

# Basic types
type SetOption = "allexport" | "a" | "errexit" | "e" | "noexec" | "n" | "noglob" | "f" | "nounset" | "u" | "xtrace" | "x" | "pipefail"
type ShoptOption = "expand_aliases" | "globstar" | "nullglob"
type RunOption = "always" | "once" | "when_changed"
type ForAttribute = "sources" | "generates"

# Variable types
type VarValue = bool | int | float | str | [any] | VarSubkey

schema VarSubkey:
    sh?: str
    ref?: str
    map?: {str: any}

# Output types
type OutputType = str | OutputObject

schema OutputObject:
    group?: GroupOutput

schema GroupOutput:
    begin?: str
    end?: str
    error_only?: bool = False

# Include types
type IncludeType = str | IncludeObject

schema IncludeObject:
    taskfile: str
    dir?: str
    optional?: bool
    flatten?: bool
    internal?: bool
    aliases?: [str]
    excludes?: [str]
    vars?: {str: VarValue}
    checksum?: str

# For loop types
type ForType = [str] | ForAttribute | ForVar | ForMatrix

schema ForVar:
    var: str
    split?: str
    as?: str = "ITEM"

schema ForMatrix:
    matrix: {str: any}

# Precondition types
type PreconditionType = str | PreconditionObject

schema PreconditionObject:
    sh: str
    msg?: str

# Glob types
type GlobType = str | GlobObject

schema GlobObject:
    exclude: str

# Required variable types
type RequiredVar = str | RequiredVarObject

schema RequiredVarObject:
    name: str
    enum: [str]

schema RequiresObject:
    vars?: [RequiredVar]

# Task command types
type TaskCommand = str | CmdCall | TaskCall | DeferTaskCall | DeferCmdCall | ForCmdsCall

schema CmdCall:
    cmd: str
    silent?: bool
    set?: [SetOption]
    shopt?: [ShoptOption]
    ignore_error?: bool
    platforms?: [str]

schema TaskCall:
    task: str
    vars?: {str: VarValue}
    silent?: bool

schema DeferTaskCall:
    defer: TaskCall

schema DeferCmdCall:
    defer: str
    silent?: bool

schema ForCmdsCall:
    for: ForType
    cmd?: str
    task?: str
    vars?: {str: VarValue}
    silent?: bool
    platforms?: [str]

# Task dependency types
type TaskDep = str | TaskCall | ForDepsCall

schema ForDepsCall:
    for: ForType
    task?: str
    vars?: {str: VarValue}
    silent?: bool

# Task types
type TaskType = str | [TaskCommand] | Task

schema Task:
    cmds?: [TaskCommand]
    cmd?: TaskCommand
    deps?: [TaskDep]
    label?: str
    desc?: str
    prompt?: str | [str]
    summary?: str
    aliases?: [str]
    sources?: [GlobType]
    generates?: [GlobType]
    status?: [str]
    preconditions?: [PreconditionType]
    dir?: str
    set?: [SetOption]
    shopt?: [ShoptOption]
    vars?: {str: VarValue}
    env?: {str: VarValue}
    dotenv?: [str]
    silent?: bool = False
    interactive?: bool = False
    internal?: bool = False
    method?: "none" | "checksum" | "timestamp"
    prefix?: str
    ignore_error?: bool
    run?: RunOption
    platforms?: [str]
    requires?: RequiresObject
    watch?: bool = False

# Main Taskfile schema
schema Taskfile:
    """Main Taskfile configuration schema"""
    version: str | int
    output?: OutputType
    method?: "none" | "checksum" | "timestamp" = "checksum"
    includes?: {str: IncludeType}
    vars?: {str: VarValue}
    env?: {str: VarValue}
    tasks?: {str: TaskType}
    silent?: bool
    set?: [SetOption]
    shopt?: [ShoptOption]
    dotenv?: [str]
    run?: RunOption
    interval?: str

# Task manager configuration
schema TaskManagerConfig:
    """Configuration for the task manager TUI application"""
    default_taskfile?: str = "Taskfile.yml"
    editor?: str = "nvim"
    theme?: TaskManagerTheme
    keybindings?: TaskManagerKeybindings
    auto_save?: bool = True
    backup_enabled?: bool = True
    backup_dir?: str = ".task-backups"

schema TaskManagerTheme:
    """Theme configuration for the TUI"""
    primary_color?: str = "blue"
    secondary_color?: str = "cyan"
    error_color?: str = "red"
    success_color?: str = "green"
    warning_color?: str = "yellow"
    background?: str = "black"
    foreground?: str = "white"

schema TaskManagerKeybindings:
    """Keybinding configuration"""
    quit?: str = "q"
    save?: str = "s"
    new_task?: str = "n"
    edit_task?: str = "e"
    delete_task?: str = "d"
    run_task?: str = "r"
    toggle_help?: str = "?"
    navigate_up?: str = "k"
    navigate_down?: str = "j"
    navigate_left?: str = "h"
    navigate_right?: str = "l"