# Mac Bootstrap Handoff — 2026-05-29

This document hands off the Mac-side work to an agent running on the MacBook Air M1.

---

## What this project is

`whisper-hotkey-daemon` — hold **Ctrl+Option+Space**, speak, release Ctrl → text
is transcribed locally and pasted into the active window. The repo lives at:
`https://github.com/danieljelinko/whisper-hotkey-daemon`
Active branch: `feat/multi-platform-backends`

The Mac backend is **mlx-whisper** (Apple-Silicon native, installs as Python
wheels via uv, no Homebrew, no compiler). The Whisper model (~1.5 GB) downloads
from HuggingFace on first transcription. The entry point is `./run.sh`.

---

## Current situation

### Bootstrap bugs (just fixed — verify they work)

**Symptom:** running the one-liner on a fresh Mac without Xcode CLT still
triggered the Xcode CLT install dialog.

**Root cause:** macOS ships `/usr/bin/git` as a stub. Two earlier guards both
failed:
1. `command -v git` — found the stub, returned true.
2. `xcode-select -p` — returned 0 because `/Library/Developer/CommandLineTools`
   exists as a placeholder path even without CLT installed.

**Fix applied (commit `98c408c` → `<latest>` on this branch):** `git_works()`
now checks the binary **path** — the macOS stub is always exactly `/usr/bin/git`;
a real git (from CLT or Homebrew) lands elsewhere. If the path is the stub, skip
to the tarball. The tarball path uses `curl` + `tar` (both built into macOS, no
CLT needed).

**Second symptom:** bootstrap reached `Running installer…`, then failed with:
`bash: install.sh: No such file or directory`.

**Root cause:** the raw bootstrap script was loaded from `feat/multi-platform-backends`,
but its internal `REPO_REF` default still pointed at `main`. The current `main`
branch does not contain `install.sh`, so bootstrap downloaded the wrong archive.

**Fix applied:** `bootstrap.sh` now checks that `install.sh` exists before
running it, so this failure mode reports the wrong-ref/archive problem clearly.
Once this branch is merged to `main`, the normal `main` one-liner is correct.

**First thing to do:** re-run the one-liner and confirm it goes straight to the
tarball download without touching git or triggering any CLT dialog:

```bash
curl -fsSL https://raw.githubusercontent.com/danieljelinko/whisper-hotkey-daemon/feat/multi-platform-backends/bootstrap.sh | bash
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
System Settings → Privacy & Security → Microphone    → enable Terminal (or your terminal app)
System Settings → Privacy & Security → Accessibility → enable Terminal (or your terminal app)
```

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
./run.sh
```

Open any text editor, click in it, then hold **Ctrl+Option+Space**, speak a
sentence, release Ctrl. Text should be pasted. Watch the log:
```bash
tail -f ~/whisper_hotkey_mac.log
```

---

## Repo orientation

```
run.sh                          single entry point (auto-detects Mac → mlx)
install.sh                      one-stop installer (called by bootstrap.sh)
bootstrap.sh                    curl-installable; tarball fallback for no-git Macs
src/
  mlx_whisper_server.py         Flask wrapper: POST /v1/audio/transcriptions → mlx
  whisper_hotkey_mac_experimental.py  hotkey + record + paste daemon (Mac)
  backend_select.py             pure dispatch logic (Darwin → "mlx")
scripts/
  lib/backend_mlx.sh            launches the mlx server
  test_mac_setup.sh             smoke test (run this first)
  101_install_whispercpp.sh     optional: builds whisper.cpp Metal as fallback
tests/
  test_mlx_server.py            contract test (mocks mlx boundary; runs anywhere)
  test_backend_select.py        unit tests for dispatch logic
  test_run_dispatch.sh          shell dispatch smoke tests
docs/
  mac_setup.md                  full Mac setup guide
01_plan.md                      what's done / what's next (Phase 2.3–2.4 still open)
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

- **2.3** `scripts/test_mac_setup.sh` passes green on the Air (model downloads, transcribes)
- **2.4** Manual hotkey→paste works; permissions granted; model/RAM tuned if needed
  - 8 GB is tight for `large-v3-turbo`; try `WHISPER_MLX_MODEL=mlx-community/whisper-large-v3-turbo-q4` if too slow
  - Record the chosen default model in `03_decisions.md`

Phase 3 (Windows, Parakeet, Voxtral) is future work, not committed.

---

## Known constraints (from 04_learnings.md)

- `mlx_whisper` only imports on Apple Silicon — the contract test mocks the boundary
- First transcription downloads model lazily (~1.5 GB); pre-warm with `test_mac_setup.sh`
- macOS `/usr/bin/git` is a stub — **do not call git without checking the path**
- `pynput` + `pyautogui` both need Accessibility permission granted in System Settings
- Microphone permission is requested silently on first recording; if it fails, check System Settings
