#!/usr/bin/env bash
set -euo pipefail

# Control the generated macOS app wrapper.

OS="$(uname -s)"
[ "$OS" = "Darwin" ] || { echo "Error: control_mac_app.sh is macOS-only"; exit 1; }

APP_PATH="${TIGRIS_APP_PATH:-$HOME/Applications/tigris-whisper.app}"
STATE_DIR="$HOME/Library/Application Support/tigris-whisper"
LOG_FILE="$HOME/Library/Logs/tigris-whisper/daemon.log"
PID_FILE="$STATE_DIR/daemon.pid"
RUN_PID_FILE="$STATE_DIR/run.pid"

usage() {
    cat <<EOF
Usage: ./scripts/control_mac_app.sh <command>

Commands:
  status   Show whether tigris-whisper is running
  start    Launch ~/Applications/tigris-whisper.app
  stop     Stop the background daemon
  restart  Stop, then launch the app again
  logs     Follow the app log
EOF
}

read_pid() {
    local file="$1"
    [ -f "$file" ] || return 1
    cat "$file" 2>/dev/null || return 1
}

is_alive() {
    local pid="$1"
    [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null
}

launcher_pid() {
    read_pid "$PID_FILE" || true
}

daemon_pid() {
    read_pid "$RUN_PID_FILE" || true
}

status() {
    local lp rp
    lp="$(launcher_pid)"
    rp="$(daemon_pid)"
    if is_alive "$lp"; then
        echo "tigris-whisper app wrapper is running (PID $lp)."
        if is_alive "$rp"; then
            echo "daemon process is running (PID $rp)."
        else
            echo "daemon process PID is not available or no longer running."
        fi
    else
        echo "tigris-whisper is not running."
        return 1
    fi
}

start() {
    if status >/dev/null 2>&1; then
        status
        return 0
    fi
    echo "Launching $APP_PATH"
    open "$APP_PATH"
}

stop() {
    local lp rp
    lp="$(launcher_pid)"
    rp="$(daemon_pid)"

    if ! is_alive "$lp" && ! is_alive "$rp"; then
        echo "tigris-whisper is not running."
        rm -f "$PID_FILE" "$RUN_PID_FILE"
        return 0
    fi

    [ -n "$lp" ] && kill "$lp" 2>/dev/null || true
    [ -n "$rp" ] && kill "$rp" 2>/dev/null || true

    for _ in $(seq 1 20); do
        if ! is_alive "$lp" && ! is_alive "$rp"; then
            rm -f "$PID_FILE" "$RUN_PID_FILE"
            echo "Stopped tigris-whisper."
            return 0
        fi
        sleep 0.2
    done

    [ -n "$lp" ] && kill -TERM "$lp" 2>/dev/null || true
    [ -n "$rp" ] && kill -TERM "$rp" 2>/dev/null || true
    rm -f "$PID_FILE" "$RUN_PID_FILE"
    echo "Stop requested. If it still appears stuck, check: $LOG_FILE"
}

logs() {
    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"
    tail -f "$LOG_FILE"
}

cmd="${1:-}"
case "$cmd" in
    status) status ;;
    start) start ;;
    stop) stop ;;
    restart) stop; start ;;
    logs) logs ;;
    -h|--help|help|"") usage ;;
    *) echo "Error: unknown command: $cmd"; usage; exit 1 ;;
esac
