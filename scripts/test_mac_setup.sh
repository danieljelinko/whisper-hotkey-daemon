#!/usr/bin/env bash
# Smoke test for the macOS whisper-hotkey setup (mlx-whisper backend).
# Run this after ./install.sh to verify every piece works before you try the
# daemon for the first time.
#
# What it checks:
#   1. Apple Silicon chip (M-series) + macOS version
#   2. uv installed and Python deps synced
#   3. mlx_whisper + flask import
#   4. End-to-end: start the mlx server, POST a real WAV → text
#      (downloads the model from HuggingFace on first run — can take minutes)
#   5. run.sh dispatch resolves to mlx
#   6. macOS permission reminder (advisory)
#
# Usage:
#   ./scripts/test_mac_setup.sh

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE="$REPO_DIR/tests/fixtures/sample_speech.wav"
PORT=14444   # non-standard port so we don't collide with a running daemon

PASS=0; FAIL=0; WARN=0
ok()   { echo "  ✅ PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "  ❌ FAIL: $1"; FAIL=$((FAIL+1)); }
warn() { echo "  ⚠️  WARN: $1"; WARN=$((WARN+1)); }
hr()   { echo ""; echo "──────────────────────────────────────────────"; }

echo ""
echo "=== whisper-hotkey-daemon Mac smoke test (mlx-whisper) ==="
echo "Repo: $REPO_DIR"
cd "$REPO_DIR"

# ─── 1. Hardware ──────────────────────────────────────────────────────────────
hr; echo "1. Hardware"
CHIP="$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo unknown)"
if echo "$CHIP" | grep -qi "apple"; then
    ok "Apple Silicon: $CHIP"
else
    fail "Non-Apple-Silicon chip: $CHIP — mlx-whisper requires Apple Silicon"
fi
ok "macOS version: $(sw_vers -productVersion 2>/dev/null || echo unknown)"

# ─── 2. uv + Python deps ──────────────────────────────────────────────────────
hr; echo "2. Python environment"
if command -v uv >/dev/null 2>&1; then
    ok "uv: $(uv --version)"
    uv sync --quiet 2>/dev/null && ok "uv sync OK" || fail "uv sync failed"
else
    fail "uv not installed. Run: ./install.sh"
fi

# ─── 3. Imports ───────────────────────────────────────────────────────────────
hr; echo "3. Key imports"
uv run python -c "import flask" 2>/dev/null && ok "flask imports" || fail "flask missing"
uv run python -c "import mlx_whisper" 2>/dev/null && ok "mlx_whisper imports" || \
    fail "mlx_whisper missing — is this Apple Silicon? Run: ./install.sh"
uv run python -c "import pynput, pyperclip, requests, sounddevice, pyautogui" 2>/dev/null && \
    ok "daemon deps import (pynput, pyperclip, requests, sounddevice, pyautogui)" || \
    fail "a daemon dependency failed to import"

# ─── 4. End-to-end: launch mlx server → transcribe fixture ───────────────────
hr; echo "4. End-to-end transcription (mlx server + real audio)"
echo "   NOTE: first run downloads the model (~1.5 GB) — this can take minutes."
SERVER_PID=""
cleanup() { [ -n "$SERVER_PID" ] && kill "$SERVER_PID" 2>/dev/null || true; }
trap cleanup EXIT

if [ ! -f "$FIXTURE" ]; then
    warn "Skipping (fixture not found: $FIXTURE)"
else
    LOG="$(mktemp)"
    WHISPER_MLX_PORT="$PORT" uv run src/mlx_whisper_server.py >"$LOG" 2>&1 &
    SERVER_PID=$!

    echo -n "   Waiting for server (incl. possible model download)"
    READY=0
    for _ in $(seq 1 600); do          # up to 10 min for first-time model pull
        if curl -sf "http://127.0.0.1:$PORT/" >/dev/null 2>&1; then READY=1; break; fi
        if ! kill -0 "$SERVER_PID" 2>/dev/null; then break; fi
        echo -n "."; sleep 1
    done
    echo ""

    if [ "$READY" = "0" ]; then
        fail "mlx server did not become ready. Log:"; tail -15 "$LOG"
    else
        ok "mlx server ready on :$PORT"
        RESPONSE="$(curl -sf -F "file=@$FIXTURE;type=audio/wav" \
            "http://127.0.0.1:$PORT/v1/audio/transcriptions" 2>/dev/null || echo "")"
        if echo "$RESPONSE" | grep -q '"text"'; then
            TEXT="$(echo "$RESPONSE" | uv run python -c \
                'import sys,json; print(json.load(sys.stdin).get("text",""))' 2>/dev/null || echo "")"
            ok "Transcription response received"
            echo "      Transcript: \"$TEXT\""
            echo "$TEXT" | grep -qi -e test -e whisper -e three -e one -e two \
                && ok "Transcript contains expected words" \
                || warn "Transcript missing expected words (accent/quality variation?)"
        else
            fail "No 'text' in response: $RESPONSE"
        fi
    fi
fi

# ─── 5. Dispatch ──────────────────────────────────────────────────────────────
hr; echo "5. run.sh dispatch"
BACKEND="$(bash run.sh --print-backend 2>/dev/null || echo error)"
[ "$BACKEND" = "mlx" ] && ok "run.sh --print-backend → mlx" || \
    fail "run.sh --print-backend → '$BACKEND' (expected mlx)"

# ─── 6. Permissions (advisory) ────────────────────────────────────────────────
hr; echo "6. macOS permissions (verify manually — cannot be tested automatically)"
echo ""
echo "  Grant both before running the daemon, or recording/paste fail silently:"
echo "    Microphone:    System Settings → Privacy & Security → Microphone → your terminal"
echo "    Accessibility: System Settings → Privacy & Security → Accessibility → your terminal"
echo ""
warn "Verify the two permissions above before running ./run.sh"

# ─── Summary ─────────────────────────────────────────────────────────────────
hr; echo ""
echo "Results: $PASS passed  |  $WARN warnings  |  $FAIL failed"
echo ""
if [ "$FAIL" -gt 0 ]; then
    echo "Fix the failures above, then re-run: ./scripts/test_mac_setup.sh"; exit 1
else
    echo "Ready. Start the daemon:  ./run.sh"
    echo "Hold Ctrl+Option+Space to record; release Ctrl to transcribe and paste."
fi
