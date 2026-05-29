#!/usr/bin/env bash
# Legacy entry point — forces the Docker CUDA backend for back-compat, then
# delegates to run.sh which handles container bring-up and daemon launch.
export WHISPER_BACKEND="${WHISPER_BACKEND:-docker_cuda}"
exec "$(dirname "${BASH_SOURCE[0]}")/../run.sh" "$@"
