#!/usr/bin/env bash
# Sourceable: ensure_whispercpp_backend [--cpu]
# Launches the native whisper.cpp server on :4444 with the OpenAI-shape endpoint
# the daemon expects. Idempotent: if :4444 already answers, reuse it.
# Requires 101_install_whispercpp.sh to have built the binary + model.

WHISPERCPP_DIR="${WHISPERCPP_DIR:-$HOME/.cache/whisper.cpp}"
WHISPERCPP_REPO="$WHISPERCPP_DIR/repo"
WHISPERCPP_MODEL_NAME="${WHISPERCPP_MODEL_NAME:-large-v3-turbo-q5_0}"
# Binary: prefer PATH (brew install whisper-cpp puts it there), fall back to cmake build
_whispercpp_default_bin="$WHISPERCPP_REPO/build/bin/whisper-server"
command -v whisper-server >/dev/null 2>&1 && _whispercpp_default_bin="$(command -v whisper-server)"
WHISPERCPP_BIN="${WHISPERCPP_BIN:-$_whispercpp_default_bin}"
# Model: check both brew model dir and our own cache dir
WHISPERCPP_MODEL="${WHISPERCPP_MODEL:-$WHISPERCPP_DIR/models/ggml-${WHISPERCPP_MODEL_NAME}.bin}"
WHISPERCPP_PORT="${WHISPERCPP_PORT:-4444}"
WHISPERCPP_INFER_PATH="/v1/audio/transcriptions"
WHISPERCPP_PID=""                                  # set when we spawn the server

ensure_whispercpp_backend() {
    local force_cpu="${1:-}"

    # Already serving? Reuse (matches the Docker path's "port in use → assume ready").
    if curl -sf "http://localhost:${WHISPERCPP_PORT}" >/dev/null 2>&1; then
        echo "✓ whisper.cpp server already responding on :${WHISPERCPP_PORT}"; return 0
    fi

    if [ ! -x "$WHISPERCPP_BIN" ] || [ ! -f "$WHISPERCPP_MODEL" ]; then
        echo "Error: whisper.cpp not installed."
        echo "  expected binary: $WHISPERCPP_BIN"
        echo "  expected model:  $WHISPERCPP_MODEL"
        echo "  run: ./scripts/101_install_whispercpp.sh"
        return 1
    fi

    local args=(-m "$WHISPERCPP_MODEL" --host 127.0.0.1 --port "$WHISPERCPP_PORT"
                --inference-path "$WHISPERCPP_INFER_PATH")
    [ "$force_cpu" = "--cpu" ] && args+=(--no-gpu)   # Metal builds: force CPU when asked

    echo "Starting whisper.cpp server (model: $WHISPERCPP_MODEL_NAME)…"
    "$WHISPERCPP_BIN" "${args[@]}" >"$WHISPERCPP_DIR/server.log" 2>&1 &
    WHISPERCPP_PID=$!
    trap '[ -n "$WHISPERCPP_PID" ] && kill "$WHISPERCPP_PID" 2>/dev/null' EXIT

    echo "Waiting for whisper.cpp API to be ready…"
    local tries=0
    until curl -sf "http://localhost:${WHISPERCPP_PORT}" >/dev/null 2>&1; do
        if ! kill -0 "$WHISPERCPP_PID" 2>/dev/null; then
            echo "Error: whisper.cpp server exited; see $WHISPERCPP_DIR/server.log"; return 1
        fi
        tries=$((tries + 1))
        if [ "$tries" -ge 120 ]; then
            echo "Error: whisper.cpp API not ready after 120s; see $WHISPERCPP_DIR/server.log"; return 1
        fi
        sleep 1
    done
    echo "✓ whisper.cpp server ready on :${WHISPERCPP_PORT} (PID $WHISPERCPP_PID)"
}
