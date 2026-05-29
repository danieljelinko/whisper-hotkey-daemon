# 01 · Plan — Multi-platform Whisper backends

**Objective.** One self-dispatching launcher `run.sh` that runs the *same* hotkey→transcribe→paste
feature on Linux (NVIDIA & no-GPU) and Mac (M1), by swapping the transcription backend behind the
existing `WHISPER_API` HTTP contract. The daemon is already backend-agnostic, so no client rewrite.

**Dispatch.**
```
Darwin              → mlx-whisper (wheels)           (Mac-only verify; whispercpp_metal = fallback)
Linux + NVIDIA GPU  → Docker + --gpus all            (existing, regression-tested here)
Linux, no GPU       → whisper.cpp server, CPU build  (primary dev target here)
```

**TDD note.** whisper.cpp is the shared Linux artifact (CPU here, Metal fallback on Mac). The Mac
*default* is now mlx-whisper (chosen to avoid Homebrew/Xcode-CLT/binary distribution — see
`03_decisions.md`), which cannot run on Linux; its HTTP wrapper is tested here with the mlx call
mocked, and the real inference is verified on-device.

## Phase 0 — L4 scaffold
- [x] Create 01_plan / 02_progress / 03_decisions / 04_learnings

## Phase 1 — Testable on this Linux+GPU box (red/green TDD)
- [x] 1.1 `backend_select.py` + `test_backend_select.py` (Darwin→metal, Linux+GPU→docker, Linux−GPU→cpu, env override)
- [x] 1.2 `101_install_whispercpp.sh` (Linux CPU build + model dl) + `lib/backend_whispercpp.sh` + `test_whispercpp_contract.py` (real sample WAV)
- [x] 1.3 extract Docker bring-up → `lib/backend_docker.sh`; regress GPU path
- [x] 1.4 `run.sh` dispatcher + `--print-backend` dry-run + `test_run_dispatch.sh`
- [x] 1.5 old `00/01/02/03_*.sh` → thin wrappers calling `run.sh`
- [x] 1.6 README "Backends by platform"

## Phase 2 — mlx-whisper Mac backend
- [x] 2.0 `mlx_whisper_server.py` (Flask, lazy mlx import) + `test_mlx_server.py` (mocked boundary)
- [x] 2.1 `lib/backend_mlx.sh` + `run.sh` mlx case; `backend_select` Darwin→`mlx`
- [x] 2.2 installer/bootstrap drop Homebrew on Mac (uv wheels only); `scripts/test_mac_setup.sh` for mlx
- [ ] 2.3 **on-device (the Air):** run `scripts/test_mac_setup.sh` → model downloads + transcribes
- [ ] 2.4 **on-device:** manual hotkey→paste check; grant Mic + Accessibility; tune model/RAM on 8 GB
- [ ] 2.5 (optional) tarball-based bootstrap to avoid `git`/Xcode-CLT entirely for end users

## Phase 3 — Optional future backends / platforms (not committed; see 03_decisions)
All slot into the same pluggable pattern: serve OpenAI-shape `/v1/audio/transcriptions` on :4444, no
client change. All GPU options below are **Linux+NVIDIA only** — none help the Mac.
- [ ] 3.1 Windows support: `backend_select` "Windows" case + either WSL2 (run.sh as-is, Docker+CUDA works) or native `run.ps1`; win client paste = `ctrl+v`, notify via `win10toast`
- [ ] 3.2 NVIDIA Parakeet-TDT-0.6B v3 backend (NeMo FastAPI wrapper) — fastest on this box, fits 8 GB VRAM easily
- [ ] 3.3 Voxtral-Mini-4B backend via vLLM (OpenAI-compatible) — **needs a 4-bit quantized (AWQ/GPTQ) build to fit this box's 8 GB VRAM**; bf16 wants ≥16 GB
