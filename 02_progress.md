# 02 · Progress

## In flight
- (Phase 2 code complete on Linux — awaiting on-device verification on the Air)

## Next
- On the Air: `./install.sh` → `./scripts/test_mac_setup.sh` (downloads model, transcribes) →
  manual hotkey→paste check (grant Mic + Accessibility).
- Optional: tarball bootstrap to avoid Xcode CLT for pure end users (Phase 2.5).

## Blocked
- Phase 2 (Metal accel, Mac client paste, mlx-whisper) — blocked on access to the MacBook Air M1.
  Cannot be developed/tested on this Linux box: MLX won't import; Metal/⌘V/macOS perms unavailable.

## Done
| Date | Task | Verified by |
|---|---|---|
| 2026-05-29 | Switch Mac default to mlx-whisper | 11 pytest + 6 dispatch green on Linux; mlx server contract tested with mocked boundary; real inference deferred to the Air |
| 2026-05-29 | Phase 1 complete (1.2–1.6) | 8 pytest + 5 bash dispatch tests green; whisper.cpp server transcribes real WAV via contract test |
| 2026-05-29 | Phase 1.1: `backend_select.py` + 6 unit tests | `uv run pytest test_backend_select.py` → 6 passed; CLI seam verified for all platforms |
| 2026-05-29 | Phase 0: L4 living-docs scaffold created | files present at repo root |
| 2026-05-29 | Branch `feat/multi-platform-backends` created off main | `git branch --show-current` |
