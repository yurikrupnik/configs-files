#!/usr/bin/env nu

def main [] {
    print "🚀 Task Manager TUI Application Demo"
    print "===================================\n"
    
    print "📋 Available tasks in Taskfile.yml:"
    task -t Taskfile.yml --list
    
    print "\n✅ Testing task execution:"
    task -t Taskfile.yml default
    
    print "\n🔍 Testing KCL schema validation:"
    kcl run validate.k --format json | from json | get validated_taskfile.version
    
    print "\n🛠️ Building the Task Manager application:"
    cargo build --release
    
    print "\n📖 Application help:"
    ./target/release/task-manager --help
    
    print "\n🎉 Demo completed successfully!"
    print "\n💡 To run the TUI interactively:"
    print "   ./target/release/task-manager"
    print "\n📚 Features:"
    print "   • Interactive task browsing with j/k navigation"
    print "   • Real-time KCL schema validation (press 'v')"
    print "   • Task execution from the interface (press 'r')"
    print "   • Search and filter tasks (press '/')"
    print "   • Task creation and editing (press 'n' or 'e')"
    print "   • Help system (press '?')"
}