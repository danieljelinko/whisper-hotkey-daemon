#!/usr/bin/env bash
# Launch Whisper hotkey daemon with English language hint
export WHISPER_LANG=en
exec "$(dirname "${BASH_SOURCE[0]}")/00_run_whisper_hotkey_daemon.sh"
