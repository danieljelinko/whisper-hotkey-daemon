# Mac Setup — whisper-hotkey-daemon

This is the complete guide to running the whisper-hotkey daemon on a Mac
(Apple Silicon — M1, M2, M3, M4). It covers setup from scratch and includes a
smoke test script you can run to verify everything works before touching the
daemon itself.

---

## What you'll end up with

Hold **Ctrl + Option + Space** → speak → release Ctrl → transcribed text is
pasted into whatever app is in front of you. The transcription runs entirely
locally on your Mac using a Metal-accelerated whisper.cpp server. No network
call, no API key, no data leaving your machine.

---

## 1. Prerequisites — install once

Open **Terminal** (or iTerm2, Warp, etc.).

### a. Homebrew
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```
After it finishes, follow the instructions it prints to add brew to your PATH
(copy/paste the two `eval` lines it shows — needed on Apple Silicon).

Verify: `brew --version`

### b. uv (Python package manager)
```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```
Then restart your terminal or run `source $HOME/.local/bin/env` (the installer
will tell you the exact command).

Verify: `uv --version`

---

## 2. Get the code

```bash
git clone https://github.com/danieljelinko/whisper-hotkey-daemon.git
cd whisper-hotkey-daemon
```

---

## 3. Install everything

One command handles Homebrew packages, whisper.cpp (Metal build), model
download, and Python deps:

```bash
./install.sh
```

This will:
- `brew install whisper-cpp` (gives you a Metal-accelerated `whisper-server`)
- Download the `ggml-large-v3-turbo-q5_0` model (~570 MB, stored in
  `~/.cache/whisper.cpp/models/`)
- Install Python dependencies via `uv sync`

Takes ~2–5 minutes (mostly the model download).

---

## 4. Grant macOS permissions

**This step is required.** Without it, the daemon starts but recording and/or
paste will silently fail.

### Microphone
> System Settings → Privacy & Security → **Microphone**
> Enable your terminal app (Terminal, iTerm2, Warp…)

### Accessibility (hotkey + paste)
> System Settings → Privacy & Security → **Accessibility**
> Enable your terminal app

When you first run the daemon, macOS may pop up a permission dialog — click
**Allow**. If it doesn't pop up and the hotkey doesn't work, check these
settings manually.

---

## 5. Verify with the smoke test

```bash
./scripts/test_mac_setup.sh
```

This script (no Python needed) checks every component:

| Check | What it verifies |
|---|---|
| Hardware | Apple Silicon chip detected |
| Binary | `whisper-server` is found and executable |
| Model | `ggml-large-v3-turbo-q5_0.bin` is present |
| Python | `uv sync` + all imports succeed |
| **End-to-end** | Launches the server, POSTs a real WAV, asserts text comes back |
| Dispatch | `run.sh --print-backend` returns `whispercpp_metal` |
| Permissions | Prints reminder (cannot test programmatically) |

All checks green? You're ready.

---

## 6. Run the daemon

```bash
./run.sh                   # auto-detects Mac → whisper.cpp + Metal
WHISPER_LANG=fr ./run.sh   # French
WHISPER_LANG=hu ./run.sh   # Hungarian
```

Hold **Ctrl + Option + Space** to start recording.  
Release **Ctrl** to stop and transcribe.  
The text is pasted automatically into the active window.

View logs:
```bash
tail -f ~/whisper_hotkey_mac.log
```

---

## Troubleshooting

### Hotkey doesn't respond
- Check Accessibility permission (step 4).
- Run the daemon from Terminal (not from a GUI launcher) so permissions attach
  to the right app.

### Recording starts but no text appears
- Check Microphone permission (step 4).
- Watch `~/whisper_hotkey_mac.log` for errors.
- Verify the server is running: `curl -s http://localhost:4444/v1/audio/transcriptions`
  (should return a 400 or 422, not "connection refused").

### Transcription is very slow (>10s)
- Check that Metal is active: `whisper-server --help 2>&1 | grep -i metal`
- Make sure you ran `brew install whisper-cpp` (the brew binary includes Metal).
  If you built from source, verify `-DWHISPER_METAL=ON` was passed to cmake.
- Check `~/whisper_hotkey_mac.log` for "GGML_METAL" lines on startup.

### `brew: command not found` after install
Add Homebrew to your PATH. For Apple Silicon Macs:
```bash
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
source ~/.zprofile
```

### Model not found
Re-run `./install.sh` — it will download just the missing model without
rebuilding anything.

---

## For developers continuing in Claude Code (Phase 2)

The repository follows a living-documentation convention. Before writing any
code, read:

- [`01_plan.md`](../01_plan.md) — checklist of what's done and what's next.
  **Phase 2** is the on-device Mac work.
- [`02_progress.md`](../02_progress.md) — current state and what's blocked.
- [`03_decisions.md`](../03_decisions.md) — key architectural decisions and why.
- [`04_learnings.md`](../04_learnings.md) — non-obvious gotchas (read this
  before touching anything).

**Phase 1 was completed on Linux.** Everything in `src/`, `scripts/lib/`, and
`tests/` is verified. Phase 2 is Mac-only work:

1. **Verify whisper.cpp Metal** — run `./scripts/test_mac_setup.sh`. All checks
   should pass. If they do, the backend is already working.
2. **Polish `src/whisper_hotkey_mac_experimental.py`** — the hotkey + recording
   + paste logic. Test the golden path manually: hold Ctrl+Option+Space in a
   text editor, speak, release Ctrl, confirm text is pasted.
3. **mlx-whisper eval (optional)** — see `01_plan.md` Phase 2.3. Benchmark
   whisper.cpp vs mlx-whisper on this machine. Record the winner in
   `03_decisions.md`.

**Running tests:**
```bash
uv run pytest            # 8 tests — 6 unit + 2 integration (whisper.cpp contract)
bash tests/test_run_dispatch.sh   # 5 shell dispatch tests
```

**TDD convention:** write the failing test first, then the minimum code to pass
it. The repo's `CLAUDE.md` has the full rules. Never mock internal code; the
whisper.cpp contract test uses a real server and a real audio fixture
(`tests/fixtures/sample_speech.wav`).
