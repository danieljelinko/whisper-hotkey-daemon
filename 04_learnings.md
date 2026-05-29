# 04 · Learnings

| Date | Title | Non-obvious truth | Implication |
|---|---|---|---|
| 2026-05-29 | Docker can't use the M1 GPU | Docker Desktop on macOS runs a Linux VM with no passthrough to Apple Silicon GPU/ANE; `--gpus all` is NVIDIA-only | Containerized Whisper on Mac is always CPU-only — don't ship Docker as the Mac backend |
| 2026-05-29 | MLX is untestable on Linux | `mlx`/`mlx-whisper` require Apple Silicon; they won't import on this dev box | Any mlx work cannot be TDD'd here — it's strictly on-device (Phase 2) |
| 2026-05-29 | `WHISPER_API` is the whole contract | Client only POSTs a WAV and reads `{"text": ...}`; it neither knows nor cares about the backend | New backends just need to serve `/v1/audio/transcriptions` on :4444 — no client changes |
| 2026-05-29 | whisper.cpp server has an OpenAI-shape endpoint | `whisper-server --inference-path /v1/audio/transcriptions` is a drop-in for the existing client | Lets us reuse the exact same daemon + tests across Docker and whisper.cpp |
| 2026-05-29 | macOS paste needs Accessibility + Mic perms | `pyautogui` ⌘V and the mic capture both prompt for TCC permissions on first run; silent failure otherwise | Mac client setup must document granting these or paste/recording fails quietly |
| 2026-05-29 | This dev box GPU = 8 GB VRAM (RTX 5070 Laptop) | bf16 Voxtral-Mini-4B needs ≥16 GB; won't load here unquantized | A GPU LLM-ASR backend on this machine must be ≤~4-bit quantized; Parakeet-0.6B fits with room to spare |
| 2026-05-29 | Windows can keep the Docker+CUDA backend | Docker Desktop on Windows does NVIDIA CUDA passthrough via WSL2; `run.sh` (bash) runs as-is under WSL2 | Windows support is mostly a `backend_select` case + client paste tweak; native (no-WSL) needs a `run.ps1` port |
| 2026-05-29 | Parakeet/Canary have no native OpenAI endpoint | NeMo/Riva expose gRPC/their own HTTP, not `/v1/audio/transcriptions` | Adding them needs a ~30-line FastAPI wrapper to match the contract; Voxtral-via-vLLM does have it natively |
| 2026-05-29 | `curl \| bash` scripts can't `read` from stdin | When piped, fd 0 is the script text, not the keyboard — a plain `read` returns empty instantly | Read interactive prompts from `/dev/tty` (with a default fallback when no tty); `bootstrap.sh` does this for the install-dir prompt |
| 2026-05-29 | Xcode CLT is a hard prereq even with Homebrew | The ~1–2 GB CLT package provides clang, ld, make, git, and the macOS SDK headers that whisper.cpp's compile/link step needs | `bootstrap.sh`/`install.sh` must trigger `xcode-select --install` and wait for it before brew/build steps |
