#!/usr/bin/env bash
# Launch Whisper hotkey daemon with Hungarian language hint
export WHISPER_LANG=hu
exec "$(dirname "${BASH_SOURCE[0]}")/00_run_whisper_hotkey_daemon.sh"
