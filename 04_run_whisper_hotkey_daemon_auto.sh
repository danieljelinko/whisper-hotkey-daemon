#!/usr/bin/env bash
# Launch Whisper hotkey daemon with automatic language detection
unset WHISPER_LANG
export WHISPER_MODEL=turbo
exec "$(dirname "${BASH_SOURCE[0]}")/01_run_whisper_hotkey_daemon.sh"
