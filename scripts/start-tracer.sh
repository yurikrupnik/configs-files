#!/bin/bash

# Nu Shell Command Tracer Startup Script

set -e

echo "🚀 Starting Nu Shell Command Tracer..."

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed. Please install Node.js and try again."
    exit 1
fi

# Check if npm is installed
if ! command -v npm &> /dev/null; then
    echo "❌ npm is not installed. Please install npm and try again."
    exit 1
fi

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Function to cleanup background processes
cleanup() {
    echo "🛑 Shutting down tracer..."
    
    # Kill background processes
    if [ ! -z "$SERVER_PID" ]; then
        echo "🔪 Stopping trace server (PID: $SERVER_PID)"
        kill $SERVER_PID 2>/dev/null || true
    fi
    
    if [ ! -z "$REACT_PID" ]; then
        echo "🔪 Stopping React app (PID: $REACT_PID)"
        kill $REACT_PID 2>/dev/null || true
    fi
    
    # Clean up trace file
    if [ -f "/tmp/nu-commands.jsonl" ]; then
        rm -f "/tmp/nu-commands.jsonl"
        echo "🧹 Cleaned up trace file"
    fi
    
    echo "✅ Cleanup complete"
    exit 0
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

# Start the trace server
echo "🔧 Starting trace server..."
node trace-server.js &
SERVER_PID=$!

# Wait a moment for server to start
sleep 2

# Check if server is running
if ! curl -s http://localhost:3001/api/health > /dev/null; then
    echo "❌ Failed to start trace server"
    cleanup
    exit 1
fi

echo "✅ Trace server started (PID: $SERVER_PID)"

# Start the React app
echo "🔧 Starting React app..."
cd command-tracer

# Install dependencies if needed
if [ ! -d "node_modules" ]; then
    echo "📦 Installing React app dependencies..."
    npm install
fi

# Start React app in background
npm start &
REACT_PID=$!

cd ..

echo "✅ React app started (PID: $REACT_PID)"
echo ""
echo "🎉 Nu Shell Command Tracer is ready!"
echo ""
echo "📊 Dashboard: http://localhost:3000"
echo "🔍 API Health: http://localhost:3001/api/health"
echo "📋 API Traces: http://localhost:3001/api/traces"
echo ""
echo "💡 Usage:"
echo "   1. Open http://localhost:3000 in your browser"
echo "   2. Run Nu shell commands with tracing enabled"
echo "   3. Watch real-time traces in the dashboard"
echo ""
echo "🔄 To use tracing in Nu shell:"
echo "   source nu-scripts/cluster.nu"
echo "   cluster create --crossplane"
echo ""
echo "Press Ctrl+C to stop the tracer"

# Wait for background processes
wait