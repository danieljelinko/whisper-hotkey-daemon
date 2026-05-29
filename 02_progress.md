# 02 · Progress

## In flight
- (Phase 1 complete — awaiting user review / commit)

## Next
- Phase 2 requires the MacBook Air M1 on-device.

## Blocked
- Phase 2 (Metal accel, Mac client paste, mlx-whisper) — blocked on access to the MacBook Air M1.
  Cannot be developed/tested on this Linux box: MLX won't import; Metal/⌘V/macOS perms unavailable.

## Done
| Date | Task | Verified by |
|---|---|---|
| 2026-05-29 | Phase 1 complete (1.2–1.6) | 8 pytest + 5 bash dispatch tests green; whisper.cpp server transcribes real WAV via contract test |
| 2026-05-29 | Phase 1.1: `backend_select.py` + 6 unit tests | `uv run pytest test_backend_select.py` → 6 passed; CLI seam verified for all platforms |
| 2026-05-29 | Phase 0: L4 living-docs scaffold created | files present at repo root |
| 2026-05-29 | Branch `feat/multi-platform-backends` created off main | `git branch --show-current` |
