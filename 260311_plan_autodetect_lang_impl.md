# Plan: Enable Auto-detect Language Mode ✓ IMPLEMENTED

## Context

The Whisper API server (Docker image `whisper-assistant-local`) has `language: str = "en"` hardcoded
as the default in its FastAPI endpoint. When no language is passed, it always transcribes as English.
The goal is to make auto-detect work by fixing both the server and adding a dedicated launcher.

## Steps

### 1. Fix Dockerfile — `whisper-assistant-vscode/Dockerfile`

In the embedded `main.py` string, make two changes:

**a) Accept `language` as an optional Form field (not query param)**

```python
# Before
from fastapi import FastAPI, UploadFile, File
...
language: str = "en"

# After
from fastapi import FastAPI, UploadFile, File, Form
...
language: str = Form(None)   # None = auto-detect; "fr", "en", etc. = forced
```

**b) Pass `language` to `transcribe()` only when set**

```python
# Before
segments, info = whisper_model.transcribe(
    temp_file.name,
    language=language,
    vad_filter=True
)

# After
transcribe_kwargs = {"vad_filter": True}
if language: transcribe_kwargs["language"] = language
segments, info = whisper_model.transcribe(temp_file.name, **transcribe_kwargs)
```

### 2. Rebuild Docker image

```bash
cd /home/helinko/Work/tools/whisper-assistant-vscode
docker build -t whisper-assistant-local .
```

Then restart the container:

```bash
docker stop whisper-assistant-local && docker rm whisper-assistant-local
# next daemon launch via 01_run_... will recreate it
```

### 3. Update `whisper_hotkey_linux.py` — revert `params` → `data`

Now that the server uses `Form()`, language must be sent as multipart form data, not query param.

```python
# Before (current fix — query param)
params = {"language": LANG} if LANG else {}
r = requests.post(API,
                  files={"file": ("speech.wav", f, "audio/wav")},
                  params=params)

# After (form data, matches Form() annotation)
data = {"language": LANG} if LANG else {}
r = requests.post(API,
                  files={"file": ("speech.wav", f, "audio/wav")},
                  data=data)
```

### 4. Add `04_run_whisper_hotkey_daemon_auto.sh`

Thin wrapper that unsets `WHISPER_LANG` so the server receives no language field → auto-detects.

```bash
#!/usr/bin/env bash
# Launch Whisper hotkey daemon with automatic language detection
unset WHISPER_LANG
exec "$(dirname "${BASH_SOURCE[0]}")/01_run_whisper_hotkey_daemon.sh"
```

### 5. Update README

- Document auto-detect launcher
- Add table showing all launchers and their language behaviour

## Test Plan

1. Run `04_run_whisper_hotkey_daemon_auto.sh`, speak French → expect French output
2. Run `02_run_whisper_hotkey_daemon_fr.sh`, speak French → expect French output
3. Run `03_run_whisper_hotkey_daemon_hu.sh`, speak Hungarian → expect Hungarian output
4. Run `01_run_whisper_hotkey_daemon.sh` with no `WHISPER_LANG` → expect auto-detect (same as auto script)

## Files Changed

| File | Change |
|------|--------|
| `whisper-assistant-vscode/Dockerfile` | Fix `language` default and Form annotation |
| `whisper_hotkey_linux.py` | Revert `params` → `data` |
| `04_run_whisper_hotkey_daemon_auto.sh` | New file — auto-detect launcher |
| `README.md` | Document new launcher and behaviour |
