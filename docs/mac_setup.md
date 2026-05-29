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

## 1. One-line install

Open **Terminal** (search Spotlight → "Terminal"), paste this, and press Enter:

```bash
curl -fsSL https://raw.githubusercontent.com/danieljelinko/whisper-hotkey-daemon/main/bootstrap.sh | bash
```

That's it. The bootstrap script handles everything in order:

| Step | What happens |
|---|---|
| Xcode CLT | A dialog pops up — click **Install**, then wait ~5 min |
| Homebrew | Installed automatically if missing |
| git | Installed via Homebrew if missing |
| Clone | Repo cloned to `~/whisper-hotkey-daemon` |
| whisper.cpp | `brew install whisper-cpp` (Metal-accelerated, ~30 sec) |
| Model | `ggml-large-v3-turbo-q5_0` downloaded (~570 MB) |
| Python deps | `uv sync` installs all Python packages |

Total time: ~5–10 minutes on a good connection (mostly the Xcode CLT and model download).

**If you already have Xcode CLT, Homebrew, and git**, the script skips those steps and finishes in ~3 minutes.

> **Prefer manual steps?** See the [manual install section](#manual-install) at the bottom.

---

## 2. Grant macOS permissions

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

## 3. Verify with the smoke test

```bash
cd ~/whisper-hotkey-daemon   # or wherever the repo was cloned
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

## 4. Run the daemon

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

## Manual install

If you prefer to run steps yourself instead of the bootstrap one-liner:

```bash
# 1. Install Xcode Command Line Tools (opens a dialog — click Install)
xcode-select --install

# 2. Install Homebrew (follow the PATH instructions it prints at the end)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/opt/homebrew/bin/brew shellenv)"   # Apple Silicon path

# 3. Install uv
curl -LsSf https://astral.sh/uv/install.sh | sh
source ~/.local/bin/env   # or restart Terminal

# 4. Clone and install
git clone https://github.com/danieljelinko/whisper-hotkey-daemon.git
cd whisper-hotkey-daemon
./install.sh
```

Then continue from step 2 (Grant permissions) above.

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
