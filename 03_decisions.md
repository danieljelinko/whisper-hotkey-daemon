# 03 · Decisions

| Date | Title | Context | Decision | Consequences |
|---|---|---|---|---|
| 2026-05-29 | One launcher, swappable backend | Daemon only needs an OpenAI-shape `/v1/audio/transcriptions` HTTP endpoint; Docker dep lived only in launcher scripts | Add single `run.sh` that detects host and brings up a per-platform backend behind the same `WHISPER_API` | No client rewrite; backends are independent and individually testable |
| 2026-05-29 | Drop Docker on Mac | Docker on macOS can't reach the Apple-Silicon GPU → CPU-only in a RAM-heavy VM, bad on 8 GB | Mac uses native whisper.cpp + Metal, not Docker | Mac needs a native install path (brew/cmake) instead of `docker run` |
| 2026-05-29 | whisper.cpp = shared Linux+Mac artifact | Need to honor red/green TDD but dev box is Linux; Mac-specific runtimes can't be tested here | Linux-no-GPU backend uses whisper.cpp CPU — the *same* server Mac runs with Metal | Developing CPU backend here de-risks Mac to one build flag; mlx can't share this |
| 2026-05-29 | Keep Linux+NVIDIA on Docker | Existing CUDA container path is proven and in daily use | Leave it unchanged; `run.sh` routes Linux+GPU → Docker | No regression risk to the working path |
| 2026-05-29 | mlx-whisper deferred to Phase 2 | Fastest on Apple Silicon but `import mlx` fails on Linux and it ships no HTTP server | Evaluate on-device only; benchmark vs whisper.cpp on the real M1 before making it default | Phase 1 default stays whisper.cpp (safe drop-in); default revisited after benchmark |
| 2026-05-29 | Mac default model = large-v3-turbo q5 | M1 8 GB is tight; want best accuracy that still fits | `ggml-large-v3-turbo-q5_0` (~570 MB), fall back to `small` if too slow | Comfortable on 8 GB with Metal |
| 2026-05-29 | Candidate future backends (Parakeet / Voxtral / Windows) | User asked what it'd take to add NVIDIA models, Voxtral, and Windows | Defer to Phase 3; all reuse the `/v1/audio/transcriptions` plug-in pattern. Parakeet-0.6B = best Linux+GPU upgrade; Voxtral only via **4-bit quant** on this 8 GB-VRAM box; Windows easiest under WSL2 | No commitment now; tracked in `01_plan.md` Phase 3. None address the Mac goal |
