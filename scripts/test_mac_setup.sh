#!/usr/bin/env bash
# Smoke test for the macOS whisper-hotkey setup.
# Run this after ./install.sh to verify every piece is working before you
# try the daemon for the first time.
#
# What it checks:
#   1. Apple Silicon chip (M-series)
#   2. whisper-server binary is present and runnable
#   3. Model file is present
#   4. whisper.cpp server starts and transcribes a real audio file → text
#   5. uv + Python deps are installed
#   6. Microphone permission (advisory, can't test programmatically)
#   7. Accessibility permission (advisory)
#
# Usage:
#   ./scripts/test_mac_setup.sh

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE="$REPO_DIR/tests/fixtures/sample_speech.wav"
WHISPERCPP_DIR="${WHISPERCPP_DIR:-$HOME/.cache/whisper.cpp}"
MODEL_NAME="${WHISPERCPP_MODEL_NAME:-large-v3-turbo-q5_0}"
MODEL_FILE="${WHISPERCPP_MODEL:-$WHISPERCPP_DIR/models/ggml-${MODEL_NAME}.bin}"
PORT=14444   # use a non-standard port so we don't collide with a running daemon

PASS=0; FAIL=0; WARN=0
ok()   { echo "  ✅ PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "  ❌ FAIL: $1"; FAIL=$((FAIL+1)); }
warn() { echo "  ⚠️  WARN: $1"; WARN=$((WARN+1)); }
hr()   { echo ""; echo "──────────────────────────────────────────────"; }

echo ""
echo "=== whisper-hotkey-daemon Mac smoke test ==="
echo "Repo: $REPO_DIR"
echo ""

# ─── 1. Hardware ──────────────────────────────────────────────────────────────
hr; echo "1. Hardware"
CHIP="$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo unknown)"
if echo "$CHIP" | grep -qi "apple"; then
    ok "Apple Silicon: $CHIP"
else
    warn "Non-Apple-Silicon chip: $CHIP — Metal won't be available (whisper.cpp will use CPU)"
fi

MACOS="$(sw_vers -productVersion 2>/dev/null || echo unknown)"
ok "macOS version: $MACOS"

# ─── 2. whisper-server binary ─────────────────────────────────────────────────
hr; echo "2. whisper-server binary"
WHISPER_BIN=""
if command -v whisper-server >/dev/null 2>&1; then
    WHISPER_BIN="$(command -v whisper-server)"
    ok "Found on PATH: $WHISPER_BIN"
elif [ -x "$WHISPERCPP_DIR/repo/build/bin/whisper-server" ]; then
    WHISPER_BIN="$WHISPERCPP_DIR/repo/build/bin/whisper-server"
    ok "Found cmake build: $WHISPER_BIN"
else
    fail "whisper-server not found. Run: ./install.sh"
fi

# ─── 3. Model file ────────────────────────────────────────────────────────────
hr; echo "3. Model file"
if [ -f "$MODEL_FILE" ]; then
    SIZE="$(du -sh "$MODEL_FILE" | cut -f1)"
    ok "Model present ($SIZE): $MODEL_FILE"
else
    fail "Model not found: $MODEL_FILE — Run: ./install.sh"
fi

# ─── 4. uv + Python deps ──────────────────────────────────────────────────────
hr; echo "4. Python environment"
if command -v uv >/dev/null 2>&1; then
    ok "uv: $(uv --version)"
    cd "$REPO_DIR"
    uv sync --quiet 2>/dev/null && ok "Python dependencies installed" || \
        fail "uv sync failed — check pyproject.toml"
    uv run python -c "import pynput, pyperclip, requests, sounddevice, pyautogui" 2>/dev/null && \
        ok "All Python imports succeed" || \
        fail "Python import failed — check deps: pynput pyperclip requests sounddevice pyautogui"
else
    fail "uv not installed. Run: ./install.sh"
fi

# ─── 5. End-to-end: launch server → transcribe fixture WAV ───────────────────
hr; echo "5. End-to-end transcription (whisper.cpp server + real audio)"
SERVER_PID=""
cleanup() { [ -n "$SERVER_PID" ] && kill "$SERVER_PID" 2>/dev/null || true; }
trap cleanup EXIT

if [ -z "$WHISPER_BIN" ] || [ ! -f "$MODEL_FILE" ]; then
    warn "Skipping end-to-end test (binary or model missing from step 2/3)"
elif [ ! -f "$FIXTURE" ]; then
    warn "Skipping end-to-end test (fixture not found: $FIXTURE)"
else
    echo "  Starting whisper-server on port $PORT…"
    "$WHISPER_BIN" -m "$MODEL_FILE" --host 127.0.0.1 --port "$PORT" \
        --inference-path /v1/audio/transcriptions \
        >"$TMPDIR/whisper_smoke.log" 2>&1 &
    SERVER_PID=$!

    # Wait for the server to be ready (up to 60s for first-time Metal compilation)
    echo -n "  Waiting for server"
    READY=0
    for i in $(seq 1 60); do
        if curl -sf "http://127.0.0.1:$PORT" >/dev/null 2>&1; then READY=1; break; fi
        if ! kill -0 "$SERVER_PID" 2>/dev/null; then break; fi
        echo -n "."; sleep 1
    done
    echo ""

    if [ "$READY" = "0" ]; then
        fail "Server did not start in 60s. Log: $TMPDIR/whisper_smoke.log"
        cat "$TMPDIR/whisper_smoke.log" | tail -10
    else
        ok "Server ready on :$PORT"

        echo "  Posting sample audio…"
        RESPONSE="$(curl -sf -F "file=@$FIXTURE;type=audio/wav" \
            "http://127.0.0.1:$PORT/v1/audio/transcriptions" 2>/dev/null || echo "")"

        if echo "$RESPONSE" | grep -q '"text"'; then
            TEXT="$(echo "$RESPONSE" | python3 -c \
                'import sys,json; print(json.load(sys.stdin).get("text",""))' 2>/dev/null || echo "(parse error)")"
            ok "Transcription response received"
            echo "     Transcript: \"$TEXT\""
            if echo "$TEXT" | grep -qi -e test -e whisper -e three -e one -e two; then
                ok "Transcript contains expected words"
            else
                warn "Transcript did not contain expected words — may be accent/quality variation"
            fi
        else
            fail "No 'text' field in response: $RESPONSE"
        fi
    fi
fi

# ─── 6. macOS permissions (advisory) ─────────────────────────────────────────
hr; echo "6. macOS permissions (cannot test automatically — verify manually)"
echo ""
echo "  Before running the daemon for the first time, grant two permissions."
echo "  Without them the daemon will start but recording and/or paste will silently fail."
echo ""
echo "  Microphone:"
echo "    System Settings → Privacy & Security → Microphone"
echo "    Enable your terminal app (Terminal.app, iTerm2, Warp, etc.)"
echo ""
echo "  Accessibility (needed for the Ctrl+Alt+Space hotkey and ⌘V paste):"
echo "    System Settings → Privacy & Security → Accessibility"
echo "    Enable your terminal app"
echo ""
warn "Verify the two permissions above before running ./run.sh"

# ─── 7. Dispatch sanity ───────────────────────────────────────────────────────
hr; echo "7. run.sh dispatch"
cd "$REPO_DIR"
BACKEND="$(bash run.sh --print-backend 2>/dev/null || echo error)"
if [ "$BACKEND" = "whispercpp_metal" ]; then
    ok "run.sh --print-backend → whispercpp_metal  ✓"
else
    fail "run.sh --print-backend → '$BACKEND' (expected whispercpp_metal)"
fi

# ─── Summary ─────────────────────────────────────────────────────────────────
hr
echo ""
echo "Results: $PASS passed  |  $WARN warnings  |  $FAIL failed"
echo ""

if [ "$FAIL" -gt 0 ]; then
    echo "Fix the failures above, then re-run: ./scripts/test_mac_setup.sh"
    exit 1
elif [ "$WARN" -gt 0 ]; then
    echo "Warnings above are non-blocking. Review them, then run: ./run.sh"
    exit 0
else
    echo "All checks passed. You're ready:"
    echo ""
    echo "  ./run.sh                        # start the daemon (auto-detect)"
    echo "  WHISPER_LANG=fr ./run.sh        # French"
    echo "  WHISPER_LANG=hu ./run.sh        # Hungarian"
    echo ""
    echo "Hold Ctrl+Option+Space to record; release Ctrl to transcribe and paste."
fi
