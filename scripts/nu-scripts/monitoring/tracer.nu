# Command tracing utility for Nu shell scripts

# Global tracing configuration
const TRACE_ENABLED = true
const TRACE_FILE = "/tmp/nu-commands.jsonl"
const TRACE_API_URL = "http://localhost:3001/api/trace"

# Initialize tracing (create trace file)
def trace-init [] {
    if $TRACE_ENABLED {
        "" | save -f $TRACE_FILE
        print $"🔍 Tracing initialized: ($TRACE_FILE)"
    }
}

# Log a command trace event
def trace-log [
    command: string      # Command being executed
    status: string       # started, completed, failed
    --data(-d): any      # Additional data/context
    --duration(-t): duration  # Command duration
] {
    if not $TRACE_ENABLED {
        return
    }
    
    let timestamp = (date now | format date "%Y-%m-%dT%H:%M:%S%.3fZ")
    let trace_id = (random uuid)
    
    mut trace_event = {
        id: $trace_id,
        timestamp: $timestamp,
        command: $command,
        status: $status,
        pid: $nu.pid,
        cwd: $env.PWD
    }
    
    if ($data != null) {
        $trace_event = ($trace_event | insert data $data)
    }
    
    if ($duration != null) {
        $trace_event = ($trace_event | insert duration ($duration | into string))
    }
    
    # Write to file
    try {
        $trace_event | to json -r | save -a $TRACE_FILE
    } catch {
        # Silently fail if we can't write trace
    }
    
    # Send to API if available
    try {
        $trace_event | to json | http post $TRACE_API_URL
    } catch {
        # Silently fail if API is not available
    }
}

# Trace a command execution with timing
def trace-command [
    command: string      # Command name/description
    block: closure       # Code block to execute and trace
] {
    if not $TRACE_ENABLED {
        do $block
        return
    }
    
    trace-log $command "started"
    
    let start_time = (date now)
    
    try {
        let result = (do $block)
        let end_time = (date now)
        let duration = ($end_time - $start_time)
        
        trace-log $command "completed" --duration $duration
        $result
    } catch { |error|
        let end_time = (date now)
        let duration = ($end_time - $start_time)
        
        trace-log $command "failed" --data {error: $error.msg} --duration $duration
        error make {msg: $error.msg}
    }
}

# Trace external command execution
def trace-external [
    ...args: string      # Command and arguments
] {
    let cmd_str = ($args | str join " ")
    
    trace-command $"external: ($cmd_str)" {
        run-external ...$args
    }
}

# Trace kubectl command
def trace-kubectl [
    ...args: string      # kubectl arguments
] {
    let cmd_str = ($args | str join " ")
    
    trace-command $"kubectl ($cmd_str)" {
        ^kubectl ...$args
    }
}

# Trace kind command
def trace-kind [
    ...args: string      # kind arguments
] {
    let cmd_str = ($args | str join " ")
    
    trace-command $"kind ($cmd_str)" {
        ^kind ...$args
    }
}

# Trace helm command
def trace-helm [
    ...args: string      # helm arguments
] {
    let cmd_str = ($args | str join " ")
    
    trace-command $"helm ($cmd_str)" {
        ^helm ...$args
    }
}

# Get current trace log
def trace-get [] {
    if (($TRACE_FILE | path exists) and $TRACE_ENABLED) {
        open $TRACE_FILE | lines | each { |line| 
            if ($line | str length) > 0 {
                $line | from json
            }
        } | compact
    } else {
        []
    }
}

# Clear trace log
def trace-clear [] {
    if $TRACE_ENABLED {
        "" | save -f $TRACE_FILE
        print "🧹 Trace log cleared"
    }
}

# Start trace monitoring (tail trace file)
def trace-monitor [] {
    if $TRACE_ENABLED and ($TRACE_FILE | path exists) {
        print $"👀 Monitoring trace file: ($TRACE_FILE)"
        print "Press Ctrl+C to stop monitoring"
        ^tail -f $TRACE_FILE
    } else {
        print "❌ Trace file not found or tracing disabled"
    }
}