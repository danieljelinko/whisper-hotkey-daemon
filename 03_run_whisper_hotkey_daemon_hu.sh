#!/usr/bin/env bash
# Launch Whisper hotkey daemon with Hungarian language hint
export WHISPER_LANG=hu
export WHISPER_MODEL=turbo
exec "$(dirname "${BASH_SOURCE[0]}")/01_run_whisper_hotkey_daemon.sh"
