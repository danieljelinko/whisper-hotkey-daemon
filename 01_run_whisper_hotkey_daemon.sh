#!/usr/bin/env bash
set -euo pipefail

# UV Launcher for Whisper Hotkey Daemon
# This script runs whisper_hotkey_linux.py using uv with automatic dependency management
# and ensures the Whisper Docker container is running

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Configuration
CONTAINER_NAME="whisper-assistant-local"
CONTAINER_IMAGE="whisper-assistant-local"
CONTAINER_PORT="4444:4444"
WHISPER_API="${WHISPER_API:-http://localhost:4444/v1/audio/transcriptions}"
GPU_MODE="${USE_GPU:-1}"

# Allow disabling GPU by exporting USE_GPU=0 before running the script
GPU_ARGS=()
if [ "$GPU_MODE" = "1" ]; then
    GPU_ARGS+=(--gpus all)
fi

# ─── Check Dependencies ───────────────────────────────────────────────────────

echo "Checking dependencies..."

# Check if uv is installed
if ! command -v uv &> /dev/null; then
    echo "Error: uv is not installed. Please install it first:"
    echo "  curl -LsSf https://astral.sh/uv/install.sh | sh"
    exit 1
fi

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if Docker daemon is running
if ! docker info &> /dev/null; then
    echo "Error: Docker daemon is not running. Please start Docker first:"
    echo "  sudo systemctl start docker"
    exit 1
fi

# Check for sox
if ! command -v sox &> /dev/null; then
    echo "Error: sox is not installed. Install it with:"
    echo "  sudo apt install sox"
    exit 1
fi

# Check for notify-send (optional)
if ! command -v notify-send &> /dev/null; then
    echo "Warning: notify-send is not installed. Install for desktop notifications:"
    echo "  sudo apt install libnotify-bin"
fi

# Check if running on Wayland or X11 and verify tools
if [ -n "${WAYLAND_DISPLAY:-}" ]; then
    echo "Detected Wayland session"
    if ! command -v wtype &> /dev/null; then
        echo "Warning: wtype is not installed. Install it for paste functionality on Wayland:"
        echo "  sudo apt install wtype"
    fi
else
    echo "Detected X11 session"
    if ! command -v xdotool &> /dev/null; then
        echo "Warning: xdotool is not installed. Install it for paste functionality on X11:"
        echo "  sudo apt install xdotool"
    fi
    if ! command -v xsetroot &> /dev/null; then
        echo "Warning: xsetroot is not installed. Install it for cursor changes on X11:"
        echo "  sudo apt install x11-xserver-utils"
    fi
fi

# ─── Check and Start Docker Container ────────────────────────────────────────

echo ""
echo "Checking Whisper Docker container..."

# Check if container exists and is running
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "✓ Container '$CONTAINER_NAME' is already running"
else
    # Check if container exists but is stopped
    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo "Starting existing container '$CONTAINER_NAME'..."
        if ! docker start "$CONTAINER_NAME" 2>&1; then
            echo "Failed to start existing container. Checking port status..."
            # Check what's using port 4444
            if ss -tuln | grep -q ':4444 '; then
                echo "Port 4444 is already in use. Checking if it's another whisper container..."
                RUNNING_CONTAINER=$(docker ps --filter "publish=4444" --format '{{.Names}}' | head -n1)
                if [ -n "$RUNNING_CONTAINER" ]; then
                    echo "✓ Found running container '$RUNNING_CONTAINER' on port 4444"
                    echo "Removing conflicting stopped container '$CONTAINER_NAME'..."
                    docker rm "$CONTAINER_NAME" || true
                else
                    echo "✓ Port 4444 is in use (likely by the Whisper API)"
                    echo "Removing conflicting container '$CONTAINER_NAME'..."
                    docker rm "$CONTAINER_NAME" || true
                fi
            else
                echo "Port is free but container won't start. Removing and will recreate..."
                docker rm "$CONTAINER_NAME" || true
            fi
        else
            echo "✓ Container started"
        fi
    else
        # Check if image exists
        if ! docker images --format '{{.Repository}}' | grep -q "^${CONTAINER_IMAGE}$"; then
            echo "Error: Docker image '$CONTAINER_IMAGE' not found."
            echo "Please build the image first or pull it from a registry."
            exit 1
        fi

        echo "Creating and starting new container '$CONTAINER_NAME'..."
        # Try to create container, but don't fail if it already exists
        if docker run -d \
            --name "$CONTAINER_NAME" \
            -p "$CONTAINER_PORT" \
            "${GPU_ARGS[@]}" \
            "$CONTAINER_IMAGE" 2>&1; then
            echo "✓ Container created and started"
        else
            # If creation failed, check if container now exists (race condition or port conflict)
            if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
                echo "Container '$CONTAINER_NAME' exists, attempting to start..."
                if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
                    echo "✓ Container is already running"
                else
                    docker start "$CONTAINER_NAME" || true
                    echo "✓ Container started"
                fi
            else
                # Check if something else is using port 4444
                if ss -tuln | grep -q ':4444 '; then
                    echo "Warning: Port 4444 is already in use by another process"
                    echo "The Whisper API might already be running at http://localhost:4444"
                    echo "Continuing anyway..."
                else
                    echo "Error: Failed to create or start container and port is not in use"
                    exit 1
                fi
            fi
        fi
    fi
fi

# Final check: ensure we have a running container or API endpoint
echo ""
if ! docker ps --format '{{.Names}}' | grep -q "whisper"; then
    echo "No whisper container is running. Checking if API is accessible..."
    if ! ss -tuln | grep -q ':4444 '; then
        echo "Error: No container running and port 4444 is not in use"
        exit 1
    fi
    echo "✓ Port 4444 is in use, assuming Whisper API is available"
fi

# Wait for the API to be ready
echo ""
echo "Waiting for Whisper API to be ready..."
MAX_RETRIES=30
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -sf "$WHISPER_API" > /dev/null 2>&1 || curl -sf "http://localhost:4444" > /dev/null 2>&1; then
        echo "✓ Whisper API is ready"
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
        echo "Error: Whisper API did not become ready within 30 seconds"
        echo "Check container logs with: docker logs $CONTAINER_NAME"
        exit 1
    fi
    echo -n "."
    sleep 1
done

# ─── Start Whisper Hotkey Daemon ──────────────────────────────────────────────

echo ""
echo "Starting Whisper Hotkey Daemon..."
echo "API endpoint: $WHISPER_API"
echo "Press Ctrl+Alt+Space to record, release Ctrl to stop and transcribe"
echo "Log file: ~/.local/share/whisper_hotkey.log"
echo ""

# Export environment variable for the Python script
export WHISPER_API

# Run with uv - this will automatically create a virtual environment and install dependencies
exec uv run whisper_hotkey_linux.py
