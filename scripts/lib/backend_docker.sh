#!/usr/bin/env bash
# Sourceable: ensure_docker_backend
# Brings up the Docker-hosted whisper-assistant container on :4444 (CUDA by
# default, CPU when USE_GPU=0). Extracted verbatim-in-spirit from the original
# 00_run_whisper_hotkey_daemon.sh so the Linux+NVIDIA path is unchanged.

WHISPER_MODEL="${WHISPER_MODEL:-turbo}"
DOCKER_CONTAINER_NAME="whisper-assistant-${WHISPER_MODEL}"
DOCKER_CONTAINER_IMAGE="whisper-assistant:${WHISPER_MODEL}"
DOCKER_CONTAINER_PORT="4444:4444"
DOCKER_GPU_MODE="${USE_GPU:-1}"
WHISPER_API="${WHISPER_API:-http://localhost:4444/v1/audio/transcriptions}"

ensure_docker_backend() {
    command -v docker >/dev/null || { echo "Error: Docker is not installed."; return 1; }
    docker info >/dev/null 2>&1 || {
        echo "Error: Docker daemon is not running (sudo systemctl start docker)"; return 1; }

    local gpu_args=()
    [ "$DOCKER_GPU_MODE" = "1" ] && gpu_args+=(--gpus all)

    # Stop any *other* whisper container squatting on 4444.
    local cid cname
    for cid in $(docker ps -q --filter "publish=4444"); do
        cname=$(docker inspect --format '{{.Name}}' "$cid" | sed 's|^/||')
        if [ "$cname" != "$DOCKER_CONTAINER_NAME" ]; then
            echo "Stopping conflicting container '$cname' on port 4444…"
            docker stop "$cname" >/dev/null && echo "✓ Stopped '$cname'"
        fi
    done

    echo "Checking Whisper Docker container…"
    if docker ps --format '{{.Names}}' | grep -q "^${DOCKER_CONTAINER_NAME}$"; then
        echo "✓ Container '$DOCKER_CONTAINER_NAME' is already running"
    elif docker ps -a --format '{{.Names}}' | grep -q "^${DOCKER_CONTAINER_NAME}$"; then
        echo "Starting existing container '$DOCKER_CONTAINER_NAME'…"
        if ! docker start "$DOCKER_CONTAINER_NAME" 2>&1; then
            echo "Failed to start; clearing conflicting stopped container…"
            docker rm "$DOCKER_CONTAINER_NAME" || true
        fi
    else
        if ! docker images --format '{{.Repository}}:{{.Tag}}' | grep -q "^${DOCKER_CONTAINER_IMAGE}$"; then
            echo "Error: Docker image '$DOCKER_CONTAINER_IMAGE' not found. Build or pull it first."
            return 1
        fi
        echo "Creating and starting new container '$DOCKER_CONTAINER_NAME'…"
        docker run -d --name "$DOCKER_CONTAINER_NAME" -p "$DOCKER_CONTAINER_PORT" \
            -v whisper-model-cache:/root/.cache/huggingface \
            "${gpu_args[@]}" "$DOCKER_CONTAINER_IMAGE" >/dev/null \
            && echo "✓ Container created and started" \
            || { echo "Error: failed to create/start container"; return 1; }
    fi

    echo "Waiting for Whisper API to be ready…"
    local tries=0
    until curl -sf "$WHISPER_API" >/dev/null 2>&1 || curl -sf "http://localhost:4444" >/dev/null 2>&1; do
        tries=$((tries + 1))
        if [ "$tries" -ge 30 ]; then
            echo "Error: Whisper API not ready in 30s (docker logs $DOCKER_CONTAINER_NAME)"; return 1
        fi
        sleep 1
    done
    echo "✓ Whisper API ready on :4444"
}
