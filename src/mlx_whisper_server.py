#!/usr/bin/env python3
"""Minimal HTTP wrapper exposing mlx-whisper as an OpenAI-shape transcription
endpoint, so the existing daemon can use it unchanged on Apple Silicon.

    POST /v1/audio/transcriptions   (multipart: file=<wav>)  → {"text": ...}

mlx-whisper only runs on Apple Silicon; the actual `mlx_whisper` import is
deferred into `transcribe_audio` so this module imports (and its HTTP contract
is testable) on any platform with the boundary mocked.

Run on a Mac:  uv run src/mlx_whisper_server.py
Env:
    WHISPER_MLX_MODEL   HuggingFace repo for the mlx model (default turbo q4)
    WHISPER_MLX_HOST    bind host (default 127.0.0.1)
    WHISPER_MLX_PORT    bind port (default 4444)
"""
import os, tempfile, pathlib
from typing import Any
from flask import Flask, request, jsonify

os.environ.setdefault("HF_HUB_DISABLE_XET", "1")
MODEL = os.getenv("WHISPER_MLX_MODEL", "mlx-community/whisper-large-v3-turbo-q4")


def transcribe_audio(path: str) -> str:
    "Transcribe the WAV at `path` with mlx-whisper. Imports mlx lazily (Mac-only)."
    import mlx_whisper                                       # noqa: PLC0415 — deferred: Apple-Silicon only
    result: dict[str, Any] = mlx_whisper.transcribe(path, path_or_hf_repo=MODEL)
    return result.get("text", "").strip()


def create_app() -> Flask:
    "Build the Flask app. Factory form so tests can stub `transcribe_audio`."
    app = Flask(__name__)

    @app.get("/")
    def health() -> Any:                                     # readiness probe for run.sh wait loop
        return jsonify(status="ok", model=MODEL)

    @app.post("/v1/audio/transcriptions")
    def transcribe() -> Any:
        if "file" not in request.files:
            return jsonify(error="missing 'file' part"), 400
        upload = request.files["file"]
        suffix = pathlib.Path(upload.filename or "audio.wav").suffix or ".wav"
        with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as tmp:
            upload.save(tmp.name)
            tmp_path = tmp.name
        try:
            text = transcribe_audio(tmp_path)
        finally:
            os.unlink(tmp_path)
        return jsonify(text=text)

    return app


if __name__ == "__main__":
    host = os.getenv("WHISPER_MLX_HOST", "127.0.0.1")
    port = int(os.getenv("WHISPER_MLX_PORT", "4444"))
    print(f"mlx-whisper server on http://{host}:{port} (model: {MODEL})")
    create_app().run(host=host, port=port, threaded=True)
