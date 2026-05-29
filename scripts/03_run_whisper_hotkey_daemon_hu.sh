#!/usr/bin/env bash
# Launch daemon with Hungarian language hint.
export WHISPER_LANG=hu
exec "$(dirname "${BASH_SOURCE[0]}")/../run.sh" "$@"
