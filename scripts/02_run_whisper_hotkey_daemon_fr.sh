#!/usr/bin/env bash
# Launch daemon with French language hint.
export WHISPER_LANG=fr
exec "$(dirname "${BASH_SOURCE[0]}")/../run.sh" "$@"
