# Mac Bootstrap Handoff — 2026-05-29

This document hands off the Mac-side work to an agent running on the MacBook Air M1.

---

## What this project is

`whisper-hotkey-daemon` — hold **Ctrl+Option+Space**, speak, release Ctrl → text
is transcribed locally and pasted into the active window. The repo lives at:
`https://github.com/danieljelinko/whisper-hotkey-daemon`
Active branch: `main`

The Mac backend is **mlx-whisper** (Apple-Silicon native, installs as Python
wheels in a Pixi environment, no Homebrew, no compiler). The default model is
`mlx-community/whisper-large-v3-turbo-q4`; it downloads from HuggingFace on
first transcription. The CLI entry point is `./run.sh`; the user-facing entry
point is the generated `~/Applications/Whisper Hotkey.app`.

---

## Current situation

The no-Xcode Mac install path is now on `main` and has been verified over SSH on
an M1 Air:

- bootstrap falls back to a GitHub tarball when only the macOS `/usr/bin/git`
  developer-tool stub is present
- installer uses Pixi and avoids macOS `python3`, Homebrew, and
  `install_name_tool`
- `ffmpeg` is provided by the Pixi environment
- `scripts/test_mac_setup.sh` passes against real audio and real mlx-whisper
- installer creates `~/Applications/Whisper Hotkey.app`
- launching the app with `open ~/Applications/Whisper\ Hotkey.app` starts the
  daemon and writes logs to `~/Library/Logs/Whisper Hotkey/daemon.log`

The remaining on-device work is the GUI-only path: double-click the app, grant
Microphone + Accessibility to **Whisper Hotkey**, then confirm hotkey-to-paste in
a real text field.

To re-test from a clean Mac install, run:

```bash
curl -fsSL https://raw.githubusercontent.com/danieljelinko/whisper-hotkey-daemon/main/bootstrap.sh | bash
```

Expected output after the directory prompt:
```
git not available — downloading tarball with curl (no Xcode CLT needed)…
✓ Downloaded to /Users/.../Developer/whisper-hotkey-daemon
Running installer…
```

If you still see a CLT dialog, check:
- Is there a third-party git at a non-`/usr/bin/git` path? (`which git` → if not
  `/usr/bin/git`, the function treats it as real and tries to use it)
- Check the `git_works()` function in `bootstrap.sh` — the path check may need
  adjusting for this machine.

---

## After bootstrap succeeds

### Step 1 — Grant macOS permissions (required before daemon runs)

```
System Settings → Privacy & Security → Microphone    → enable Whisper Hotkey
System Settings → Privacy & Security → Accessibility → enable Whisper Hotkey
```

If testing `./run.sh` directly instead of the app, grant both permissions to the
terminal app used to launch it.

### Step 2 — Run the smoke test

```bash
cd ~/Developer/whisper-hotkey-daemon
./scripts/test_mac_setup.sh
```

This starts the mlx-whisper server, **downloads the Whisper model (~1.5 GB on
first run** — wait for it), POSTs a real WAV, and asserts you get text back.
Checks all pass? The backend works.

### Step 3 — Manual hotkey test

```bash
open ~/Applications/Whisper\ Hotkey.app
```

Open any text editor, click in it, then hold **Ctrl+Option+Space**, speak a
sentence, release Ctrl. Text should be pasted. Watch the log:
```bash
tail -f ~/Library/Logs/Whisper\ Hotkey/daemon.log
```

---

## Repo orientation

```
run.sh                          CLI entry point (auto-detects Mac → mlx)
install.sh                      one-stop installer (called by bootstrap.sh)
bootstrap.sh                    curl-installable; tarball fallback for no-git Macs
src/
  mlx_whisper_server.py         Flask wrapper: POST /v1/audio/transcriptions → mlx
  whisper_hotkey_mac_experimental.py  hotkey + record + paste daemon (Mac)
  backend_select.py             pure dispatch logic (Darwin → "mlx")
scripts/
  create_mac_app.sh             generates ~/Applications/Whisper Hotkey.app
  lib/backend_mlx.sh            launches the mlx server
  test_mac_setup.sh             smoke test (run this first)
  101_install_whispercpp.sh     optional: builds whisper.cpp Metal as fallback
tests/
  test_mlx_server.py            contract test (mocks mlx boundary; runs anywhere)
  test_backend_select.py        unit tests for dispatch logic
  test_run_dispatch.sh          shell dispatch smoke tests
docs/
  mac_setup.md                  full Mac setup guide
01_plan.md                      what's done / what's next
03_decisions.md                 key decisions + rationale
04_learnings.md                 non-obvious gotchas (read before touching things)
```

**Running tests (Linux-safe, all green as of this handoff):**
```bash
uv run pytest -q            # 11 tests
bash tests/test_run_dispatch.sh  # 6 tests
```

---

## Phase 2 remaining work (on-device only)

From `01_plan.md`:

- **2.4** Manual hotkey→paste works; permissions granted; model/RAM tuned if needed
- **4.4** Double-click `Whisper Hotkey.app`, grant permissions to that app,
  confirm manual hotkey→paste

8 GB is tight for non-quantized `large-v3-turbo`; keep the default at
`mlx-community/whisper-large-v3-turbo-q4` unless a later on-device test proves a
better tradeoff. Record any later model changes in `03_decisions.md`.

Phase 3 (Windows, Parakeet, Voxtral) is future work, not committed.

---

## Known constraints (from 04_learnings.md)

- `mlx_whisper` only imports on Apple Silicon — the contract test mocks the boundary
- First transcription downloads model lazily and can take minutes; pre-warm with `test_mac_setup.sh`
- macOS `/usr/bin/git` is a stub — **do not call git without checking the path**
- The daemon uses `pbcopy` + AppleScript paste on macOS to avoid `pyautogui`
- Microphone and Accessibility permission must be granted to **Whisper Hotkey**
  when launched as the app, or to the terminal app when launched manually
