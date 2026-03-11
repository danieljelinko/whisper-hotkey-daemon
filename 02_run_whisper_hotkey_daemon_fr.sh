#!/usr/bin/env bash
# Launch Whisper hotkey daemon with French language hint
export WHISPER_LANG=fr
exec "$(dirname "${BASH_SOURCE[0]}")/01_run_whisper_hotkey_daemon.sh"
