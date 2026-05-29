#!/usr/bin/env bash
# Launch daemon with English language hint.
export WHISPER_LANG=en
exec "$(dirname "${BASH_SOURCE[0]}")/../run.sh" "$@"
