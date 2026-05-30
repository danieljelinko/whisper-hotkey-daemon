#!/usr/bin/env bash
# Tests for installer/uninstaller behavior that can run safely on Linux.
# macOS is simulated with a temporary uname stub; pixi is stubbed so no network
# or dependency installation happens.
set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(cd "$TEST_DIR/.." && pwd)"
PASS=0; FAIL=0
ok()   { echo "  PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL+1)); }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

FAKE_BIN="$TMP/bin"
HOME_DIR="$TMP/home"
APP_PARENT="$TMP/apps"
INSTALL_DIR="$TMP/install"
mkdir -p "$FAKE_BIN" "$HOME_DIR" "$APP_PARENT" "$INSTALL_DIR"

cat > "$FAKE_BIN/uname" <<'EOF'
#!/usr/bin/env bash
echo Darwin
EOF
chmod +x "$FAKE_BIN/uname"

cat > "$FAKE_BIN/pixi" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
    --version) echo "pixi 0.test" ;;
    install) echo "fake pixi install OK" ;;
    *) echo "fake pixi $*" ;;
esac
EOF
chmod +x "$FAKE_BIN/pixi"

export PATH="$FAKE_BIN:$PATH"
export HOME="$HOME_DIR"
export WHISPER_APP_PARENT="$APP_PARENT"

echo "=== install/uninstall tests ==="

# ─── install.sh: macOS path creates app wrapper and prints uninstall command ──

install_out="$TMP/install.out"
if bash "$SCRIPT_DIR/install.sh" >"$install_out" 2>&1; then
    ok "install.sh macOS path exits successfully with fake pixi"
else
    cat "$install_out"
    fail "install.sh macOS path exits successfully with fake pixi"
fi

APP_DIR="$APP_PARENT/tigris-whisper.app"
[ -x "$APP_DIR/Contents/MacOS/tigris-whisper" ] && \
    ok "install.sh creates executable app wrapper" || \
    fail "install.sh creates executable app wrapper"

grep -q "com.danieljelinko.tigris-whisper" "$APP_DIR/Contents/Info.plist" && \
    ok "app wrapper plist contains bundle id" || \
    fail "app wrapper plist contains bundle id"

grep -q "Uninstall:     ./uninstall.sh" "$install_out" && \
    ok "install.sh prints uninstall command" || \
    fail "install.sh prints uninstall command"

# ─── uninstall.sh: removes generated app/state/logs/model/install dir safely ──

mkdir -p \
    "$HOME/Library/Logs/tigris-whisper" \
    "$HOME/Library/Application Support/tigris-whisper" \
    "$HOME/.cache/huggingface/hub/models--mlx-community--whisper-large-v3-turbo-q4" \
    "$HOME/.cache/whisper.cpp" \
    "$INSTALL_DIR"
touch \
    "$HOME/Library/Logs/tigris-whisper/daemon.log" \
    "$HOME/Library/Application Support/tigris-whisper/daemon.pid" \
    "$HOME/.cache/huggingface/hub/models--mlx-community--whisper-large-v3-turbo-q4/model.safetensors" \
    "$HOME/.cache/whisper.cpp/mlx_server.log" \
    "$INSTALL_DIR/bootstrap.sh"

uninstall_out="$TMP/uninstall.out"
if bash "$SCRIPT_DIR/uninstall.sh" --yes --install-dir "$INSTALL_DIR" >"$uninstall_out" 2>&1; then
    ok "uninstall.sh --yes exits successfully"
else
    cat "$uninstall_out"
    fail "uninstall.sh --yes exits successfully"
fi

[ ! -e "$APP_DIR" ] && \
    ok "uninstall.sh removes app wrapper" || \
    fail "uninstall.sh removes app wrapper"

[ ! -e "$HOME/Library/Logs/tigris-whisper" ] && \
    ok "uninstall.sh removes app logs" || \
    fail "uninstall.sh removes app logs"

[ ! -e "$HOME/Library/Application Support/tigris-whisper" ] && \
    ok "uninstall.sh removes app state" || \
    fail "uninstall.sh removes app state"

[ ! -e "$HOME/.cache/huggingface/hub/models--mlx-community--whisper-large-v3-turbo-q4" ] && \
    ok "uninstall.sh removes known mlx model cache" || \
    fail "uninstall.sh removes known mlx model cache"

[ ! -e "$HOME/.cache/whisper.cpp/mlx_server.log" ] && \
    ok "uninstall.sh removes mlx server log" || \
    fail "uninstall.sh removes mlx server log"

[ ! -e "$INSTALL_DIR" ] && \
    ok "uninstall.sh --yes removes install dir" || \
    fail "uninstall.sh --yes removes install dir"

[ -d "$HOME" ] && \
    ok "uninstall.sh keeps HOME intact" || \
    fail "uninstall.sh keeps HOME intact"

# ─── Summary ─────────────────────────────────────────────────────────────────

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
