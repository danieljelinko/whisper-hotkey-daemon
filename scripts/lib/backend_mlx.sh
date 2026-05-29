#!/usr/bin/env bash
# Sourceable: ensure_mlx_backend
# Launches the mlx-whisper HTTP wrapper on :4444 (Apple Silicon only).
# The model is downloaded lazily from HuggingFace on first transcription, so
# there is no separate model-download step here. Idempotent: reuse if already up.

MLX_PORT="${WHISPER_MLX_PORT:-4444}"
MLX_HOST="${WHISPER_MLX_HOST:-127.0.0.1}"
MLX_DIR="${WHISPERCPP_DIR:-$HOME/.cache/whisper.cpp}"   # reuse cache dir for the server log
MLX_PID=""
PIXI="$(command -v pixi 2>/dev/null || printf '%s/.pixi/bin/pixi' "$HOME")"

ensure_mlx_backend() {
    if curl -sf "http://localhost:${MLX_PORT}" >/dev/null 2>&1; then
        echo "✓ mlx-whisper server already responding on :${MLX_PORT}"; return 0
    fi

    mkdir -p "$MLX_DIR"
    echo "Starting mlx-whisper server (model: ${WHISPER_MLX_MODEL:-mlx-community/whisper-large-v3-turbo})…"
    echo "  (first run downloads the model from HuggingFace — may take a few minutes)"
    WHISPER_MLX_HOST="$MLX_HOST" WHISPER_MLX_PORT="$MLX_PORT" \
        "$PIXI" run python "$SCRIPT_DIR/src/mlx_whisper_server.py" >"$MLX_DIR/mlx_server.log" 2>&1 &
    MLX_PID=$!
    trap '[ -n "$MLX_PID" ] && kill "$MLX_PID" 2>/dev/null' EXIT

    echo "Waiting for mlx-whisper API to be ready…"
    local tries=0
    until curl -sf "http://localhost:${MLX_PORT}" >/dev/null 2>&1; do
        if ! kill -0 "$MLX_PID" 2>/dev/null; then
            echo "Error: mlx-whisper server exited; see $MLX_DIR/mlx_server.log"; return 1
        fi
        tries=$((tries + 1))
        if [ "$tries" -ge 300 ]; then     # generous: first-run model download
            echo "Error: mlx-whisper API not ready after 300s; see $MLX_DIR/mlx_server.log"; return 1
        fi
        sleep 1
    done
    echo "✓ mlx-whisper server ready on :${MLX_PORT} (PID $MLX_PID)"
}
