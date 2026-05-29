# 01 · Plan — Multi-platform Whisper backends

**Objective.** One self-dispatching launcher `run.sh` that runs the *same* hotkey→transcribe→paste
feature on Linux (NVIDIA & no-GPU) and Mac (M1), by swapping the transcription backend behind the
existing `WHISPER_API` HTTP contract. The daemon is already backend-agnostic, so no client rewrite.

**Dispatch.**
```
Darwin              → whisper.cpp server + Metal     (Mac-only verify)
Linux + NVIDIA GPU  → Docker + --gpus all            (existing, regression-tested here)
Linux, no GPU       → whisper.cpp server, CPU build  (primary dev target here)
```

**TDD leverage.** whisper.cpp is the shared artifact — CPU on Linux, Metal on Mac. Developing the
CPU backend here de-risks Mac down to one build flag (`-DWHISPER_METAL=1`) + the Mac client.

## Phase 0 — L4 scaffold
- [x] Create 01_plan / 02_progress / 03_decisions / 04_learnings

## Phase 1 — Testable on this Linux+GPU box (red/green TDD)
- [x] 1.1 `backend_select.py` + `test_backend_select.py` (Darwin→metal, Linux+GPU→docker, Linux−GPU→cpu, env override)
- [x] 1.2 `101_install_whispercpp.sh` (Linux CPU build + model dl) + `lib/backend_whispercpp.sh` + `test_whispercpp_contract.py` (real sample WAV)
- [x] 1.3 extract Docker bring-up → `lib/backend_docker.sh`; regress GPU path
- [x] 1.4 `run.sh` dispatcher + `--print-backend` dry-run + `test_run_dispatch.sh`
- [x] 1.5 old `00/01/02/03_*.sh` → thin wrappers calling `run.sh`
- [x] 1.6 README "Backends by platform"

## Phase 2 — Mac on-device only (cannot TDD here)
- [ ] 2.1 whisper.cpp Metal branch in install helper; re-run contract test on the Air
- [ ] 2.2 polish `whisper_hotkey_mac_experimental.py` + document Accessibility/Mic permissions
- [ ] 2.3 mlx-whisper backend (`mlx_whisper_server.py` + `lib/backend_mlx.sh`) + on-device benchmark → set Mac default in 03_decisions

## Phase 3 — Optional future backends / platforms (not committed; see 03_decisions)
All slot into the same pluggable pattern: serve OpenAI-shape `/v1/audio/transcriptions` on :4444, no
client change. All GPU options below are **Linux+NVIDIA only** — none help the Mac.
- [ ] 3.1 Windows support: `backend_select` "Windows" case + either WSL2 (run.sh as-is, Docker+CUDA works) or native `run.ps1`; win client paste = `ctrl+v`, notify via `win10toast`
- [ ] 3.2 NVIDIA Parakeet-TDT-0.6B v3 backend (NeMo FastAPI wrapper) — fastest on this box, fits 8 GB VRAM easily
- [ ] 3.3 Voxtral-Mini-4B backend via vLLM (OpenAI-compatible) — **needs a 4-bit quantized (AWQ/GPTQ) build to fit this box's 8 GB VRAM**; bf16 wants ≥16 GB
