# Mac Setup — whisper-hotkey-daemon

This is the complete guide to running the whisper-hotkey daemon on a Mac
(Apple Silicon — M1, M2, M3, M4). It covers setup from scratch and includes a
smoke test script you can run to verify everything works before touching the
daemon itself.

---

## What you'll end up with

Hold **Ctrl + Option + Space** → speak → release Ctrl → transcribed text is
pasted into whatever app is in front of you. The transcription runs entirely
locally on your Mac using **mlx-whisper** (Apple's MLX framework, GPU-accelerated
on Apple Silicon). No network call, no API key, no data leaving your machine.

---

## 1. One-line install

Open **Terminal** (search Spotlight → "Terminal"), paste this, and press Enter:

```bash
curl -fsSL https://raw.githubusercontent.com/danieljelinko/whisper-hotkey-daemon/main/bootstrap.sh | bash
```

That's it. The bootstrap script handles everything in order:

| Step | What happens |
|---|---|
| Install dir | Asks where to install — press Enter for the default `~/Developer/whisper-hotkey-daemon` |
| Fetch | Uses `git clone` if git exists, otherwise downloads a tarball with `curl` — **no Xcode CLT required** |
| Pixi | Installed via its standalone installer (no compiler needed) |
| Python deps | `pixi install` creates a Python 3.12 env and installs prebuilt wheels, **including mlx-whisper** |

> `~/Developer` is Apple's recognised folder for development projects (Finder shows it with a hammer icon). To install elsewhere without being prompted:
> ```bash
> curl -fsSL https://raw.githubusercontent.com/danieljelinko/whisper-hotkey-daemon/main/bootstrap.sh | WHISPER_INSTALL_DIR=~/my-dir bash
> ```

**No Xcode Command Line Tools, no Homebrew, no compiling.** The repo comes as a
`curl` tarball (curl is built into macOS) and Pixi provides Python without
touching macOS developer-tool stubs such as `python3` or `install_name_tool`.
The only large download is the **Whisper model (~1.5 GB), fetched automatically
from HuggingFace the first time you transcribe** — so your *first* dictation has
a one-time delay, everything after is instant.

> **Developers:** if you want a real git checkout (to pull/commit, e.g. continuing
> in Claude Code), install git first with `xcode-select --install` — the bootstrap
> then uses `git clone` instead of the tarball.

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
cd ~/Developer/whisper-hotkey-daemon   # or wherever you chose to install
./scripts/test_mac_setup.sh
```

This script checks every component:

| Check | What it verifies |
|---|---|
| Hardware | Apple Silicon chip detected |
| Python | `pixi install` succeeds; `mlx_whisper` and `flask` import |
| **End-to-end** | Starts the mlx server, POSTs a real WAV, asserts text comes back (downloads the model on first run) |
| Dispatch | `run.sh --print-backend` returns `mlx` |
| Permissions | Prints reminder (cannot test programmatically) |

All checks green? You're ready. (The first run downloads the model, so this
test may take a few minutes the very first time.)

---

## 4. Run the daemon

```bash
./run.sh                   # auto-detects Mac → mlx-whisper
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

### First transcription hangs for a long time
That's the one-time model download (~1.5 GB from HuggingFace). Watch progress in
the server log: `tail -f ~/.cache/whisper.cpp/mlx_server.log`. Once cached, later
runs are instant. To pre-download, just run `./scripts/test_mac_setup.sh` once.

### Transcription is slow even after the model is cached
- Confirm you're on Apple Silicon (`uname -m` → `arm64`). mlx only accelerates there.
- 8 GB Macs are tight; close memory-hungry apps. To try a smaller/faster model:
  `WHISPER_MLX_MODEL=mlx-community/whisper-large-v3-turbo-q4 ./run.sh` (4-bit).
- As a fallback you can switch to whisper.cpp: run `./scripts/101_install_whispercpp.sh`
  then `WHISPER_BACKEND=whispercpp_metal ./run.sh`.

### `mlx_whisper` import fails
You're almost certainly not on Apple Silicon, or `pixi install` didn't run. mlx is
Apple-Silicon-only. Re-run `./install.sh` on an M-series Mac.

---

## Manual install

If you prefer to run steps yourself instead of the bootstrap one-liner:

```bash
# 1. Install Xcode Command Line Tools (opens a dialog — click Install). Gives you git.
xcode-select --install

# 2. Install Pixi
curl -fsSL https://pixi.sh/install.sh | sh
source ~/.pixi/env   # or restart Terminal

# 3. Clone and install (Pixi pulls Python and mlx-whisper wheels — no compiler, no brew)
git clone https://github.com/danieljelinko/whisper-hotkey-daemon.git
cd whisper-hotkey-daemon
./install.sh
```

Then continue from step 2 (Grant permissions) above. No Homebrew required for the
default mlx backend.

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

1. **Verify the mlx backend** — run `./scripts/test_mac_setup.sh`. The
   end-to-end check starts `src/mlx_whisper_server.py`, downloads the model, and
   transcribes a real WAV. If it's green, the backend works.
2. **Polish `src/whisper_hotkey_mac_experimental.py`** — the hotkey + recording
   + paste logic. Test the golden path manually: hold Ctrl+Option+Space in a
   text editor, speak, release Ctrl, confirm text is pasted.
3. **Tune the model / RAM** — on 8 GB, try `WHISPER_MLX_MODEL=...q4` variants and
   measure latency + peak RSS. Record the chosen default in `03_decisions.md`.

**Running tests:**
```bash
uv run pytest            # 11 tests — backend_select unit + mlx-server contract
                         # (mlx-server test mocks the mlx boundary, so it runs anywhere)
bash tests/test_run_dispatch.sh   # 6 shell dispatch tests
```

**TDD convention:** write the failing test first, then the minimum code to pass
it (see `CLAUDE.md`). mlx-whisper only runs on Apple Silicon, so the contract
test for `mlx_whisper_server.py` mocks `transcribe_audio` (the hardware boundary)
and exercises the real Flask route. The *actual* mlx transcription is only
verified on-device via `scripts/test_mac_setup.sh`.
