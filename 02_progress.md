# 02 · Progress

## In flight
- Phase 4.4: manual GUI test — double-click **tigris-whisper.app**, grant
  Microphone + Accessibility, confirm hotkey→paste in a real text field.

## Next
- On the Air: install generated app → double-click → grant Mic + Accessibility
  to **tigris-whisper** → manual hotkey→paste check.

## Blocked
- Manual permission/hotkey validation still requires the Mac UI session. SSH can
  verify install and smoke tests, but not the TCC prompts/user gesture path.

## Done
| Date | Task | Verified by |
|---|---|---|
| 2026-05-30 | Phase 4.7: bootstrap runs smoke test/model warmup automatically | `tests/test_install_uninstall.sh` → 20 passed; covers fake-mac bootstrap invoking smoke test, warning that model download can take several minutes, and final numbered `WHAT TO DO NEXT` app-launch instructions |
| 2026-05-30 | Phase 4.6: renamed user-facing product/repo to `tigris-whisper` | GitHub repo renamed first; source now uses `danieljelinko/tigris-whisper`, `~/Developer/tigris-whisper`, `tigris-whisper.app`, `com.danieljelinko.tigris-whisper`; `tests/test_install_uninstall.sh` covers renamed app/install paths |
| 2026-05-30 | Phase 4.5: uninstall script added with tests | `tests/test_install_uninstall.sh` covers fake-mac install wrapper creation and temp-HOME uninstall of app/logs/state/model cache/install dir |
| 2026-05-30 | Phase 4.1–4.3: generated app wrapper | SSH to M1 Air verified the app-wrapper launch path before rename; current `tigris-whisper.app` bundle name, id, logs, and state paths are covered by `tests/test_install_uninstall.sh` |
| 2026-05-30 | Clean Mac tarball install + mlx q4 smoke test green | SSH to M1 Air: clean install from GitHub `main`; `scripts/test_mac_setup.sh` → 10 passed / 0 failed; transcript fixture recognized |
| 2026-05-30 | Mac install path switched to Pixi + ffmpeg | SSH clean install: Pixi env created without Xcode CLT/Homebrew; `ffmpeg` available; mlx-whisper transcribes |
| 2026-05-29 | Switch Mac default to mlx-whisper | 11 pytest + 6 dispatch green on Linux; mlx server contract tested with mocked boundary; real inference deferred to the Air |
| 2026-05-29 | Phase 1 complete (1.2–1.6) | 8 pytest + 5 bash dispatch tests green; whisper.cpp server transcribes real WAV via contract test |
| 2026-05-29 | Phase 1.1: `backend_select.py` + 6 unit tests | `uv run pytest test_backend_select.py` → 6 passed; CLI seam verified for all platforms |
| 2026-05-29 | Phase 0: L4 living-docs scaffold created | files present at repo root |
| 2026-05-29 | Branch `feat/multi-platform-backends` created off main | `git branch --show-current` |
