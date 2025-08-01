#!/bin/bash

# Enable job control
set -m

# Function to cleanup on exit
cleanup() {
    echo "🛑 Shutting down collector..."
    
    # Kill all child processes recursively
    if [ ! -z "$COLLECTOR_PID" ]; then
        # Kill the entire process group (negative PID)
        kill -TERM -"$COLLECTOR_PID" 2>/dev/null || true
        sleep 1
        kill -KILL -"$COLLECTOR_PID" 2>/dev/null || true
        
        # Also kill the main process
        kill -TERM "$COLLECTOR_PID" 2>/dev/null || true
        kill -KILL "$COLLECTOR_PID" 2>/dev/null || true
    fi
    
    # Kill any remaining otelcontribcol processes
    pkill -f "otelcontribcol" 2>/dev/null || true
    
    # Also kill any processes using our ports (macOS compatible)
    (lsof -ti :4317 2>/dev/null | xargs kill -9 2>/dev/null || true)
    (lsof -ti :4318 2>/dev/null | xargs kill -9 2>/dev/null || true)
    (lsof -ti :8888 2>/dev/null | xargs kill -9 2>/dev/null || true)
    
    echo "✅ Cleanup completed"
    exit 0
}

# Set up signal handlers for various termination signals
trap cleanup SIGTERM SIGINT SIGQUIT EXIT

CONFIG_FILE=${1:-"../../../../configs/local/otel-collector-config.yaml"}

echo "🚀 Starting OpenTelemetry Collector..."
echo "📄 Config: $CONFIG_FILE"

# Start collector
cd ./cmd/otelcontribcol || exit 1
# Start in background with proper signal handling
GO111MODULE=on go run --race . --config "$CONFIG_FILE" &
COLLECTOR_PID=$!

echo "🔄 Collector running with PID: $COLLECTOR_PID"
echo "🛑 Press Ctrl+C to stop"

# Wait for the process to finish
wait "$COLLECTOR_PID"
