# Whisper Hotkey Daemon

A lightweight Python daemon that records audio from your microphone on a global hot-key (`Ctrl + Alt + Space`), sends it to a Docker-hosted Whisper transcription server, and places the resulting text in your clipboard (optionally pasting it into the active window).

Inspired by [MartinOpenSky's Whisper Assistant VSCode extension](https://github.com/martin-opensky/whisper-assistant-vscode) (Dockerfile)

---

## Features

* **Global hot-key listener**: Start recording when you press **Ctrl + Alt + Space**, stop when you release **Ctrl**.
* **Clipboard integration**: Automatically copies transcript to clipboard and pastes it if possible.
* **Structured logging**: Logs events, errors, and timings to `~/.local/share/whisper_hotkey.log`.

## Prerequisites

* **Operating System**:
  * Ubuntu, Linux Mint (Cinnamon or Xfce), or any X11-based Linux desktop. Wayland is partially supported (clipboard and notifications, but no cursor change).
  * Windows 10 or 11 (experimental)
  * macOS (experimental)

### System & Python Dependencies

```bash
sudo apt install sox xclip xdotool libnotify-bin python3-pip  # linux system deps
pip install pynput pyperclip requests sounddevice soundfile numpy pyautogui win10toast # python deps  

(On Linux/macOS you can omit win10toast; on Windows it gives toast notifications.)
```

*For Wayland users*: replace `xdotool`/`xclip` with `wtype` and `wl-clipboard`.

## Installation

0. **Prepare the Whisper Docker container (CPU or GPU)**

   The daemon talks to the Docker backend shipped in [danieljelinko/whisper-assistant-vscode](https://github.com/danieljelinko/whisper-assistant-vscode). Clone that repo and run the helper scripts it provides:

   ```bash
   git clone https://github.com/danieljelinko/whisper-assistant-vscode
   cd whisper-assistant-vscode
   ./00_install_docker_buildx.sh                     # one-time buildx prerequisites
   # Optional: only if you actually have an NVIDIA GPU on this host
   ./00_install_nvidia_container_toolkit.sh
   ./01_build_whisper_docker_container_linux.sh -t whisper-assistant-local
   ```

   *The `-t` flag picks the Docker image tag; feel free to use separate tags if you maintain CPU and GPU variants.*

   After the image is built you can either launch it manually or let the hotkey daemon script do it for you:

   ```bash
   # Manual start (choose the variant that matches your host)
   docker run -d -p 4444:4444 whisper-assistant-local                # CPU
   docker run -d -p 4444:4444 --gpus all whisper-assistant-local     # GPU
   ```

   On macOS you can keep using the published image:

   ```bash
   docker run -d -p 4444:4444 --name whisper-assistant martinopensky/whisper-assistant:latest
   ```

1. **Clone or download** this repository to `~/.local/bin`:

   ```bash
   mkdir -p ~/.local/bin && git clone https://github.com/danieljelinko/whisper-hotkey-daemon.git ~/.local/bin/whisper-hotkey
   cd ~/.local/bin/whisper-hotkey
   chmod +x whisper_hotkey_linux.py
   ```

2. **Configure environment** (if needed):

   * If docker port changed set `WHISPER_API` to your transcription endpoint. Default is `http://localhost:4444/v1/audio/transcriptions`.

3. **Run the launcher or daemon directly**

   The script `01_run_whisper_hotkey_daemon.sh` both ensures the container is up (creating it if missing) and runs the Python daemon through `uv`. It now accepts an optional `USE_GPU` flag so you can explicitly request CPU mode:

   ```bash
   ./01_run_whisper_hotkey_daemon.sh      # default, requests --gpus all
   USE_GPU=0 ./01_run_whisper_hotkey_daemon.sh   # force CPU container launch
   ```

   When a Docker container is already running you can launch the daemon alone:

   ```bash
   uv run whisper_hotkey_linux.py
   ```

   Sample log output:

   ```bash
   2025-06-21 00:58:02,490 INFO: Daemon up (Wayland=False). Hold Ctrl + Alt + Space to record; release Ctrl to stop.
   2025-06-21 00:58:05,108 INFO: Recording started (PID 74070)

   Input File     : 'default' (alsa)
   Channels       : 2
   Sample Rate    : 48000
   Precision      : 16-bit
   Sample Encoding: 16-bit Signed Integer PCM

   In:0.00% 00:00:02.90 [00:00:00.00] Out:43.6k [      |      ]        Clip:0
   Aborted.
   2025-06-21 00:58:08,051 INFO: Recording stopped, 87146 B
   2025-06-21 00:58:09,227 INFO: API call 1.05s
   2025-06-21 00:58:09,239 INFO: Transcript copied: Hello world!
   2025-06-21 00:58:09,241 INFO: Pasted with xdotool
   ```

## Usage

* **Start recording**: Press `Ctrl + Alt + Space` and hold **`Ctrl`** until you finish speaking.
* **Stop recording**: Release **Ctrl**. Recording stops.
* **Paste**: If a text field is focused, the daemon attempts to paste automatically, but you can also paste manually from the clipboard.
* **Logs**: View real-time logs:

  ```bash
  tail -f ~/.local/share/whisper_hotkey.log
  ```

## Troubleshooting

* **No notifications**:

  * Ensure `libnotify-bin` is installed and your desktop daemon is running.

* **Cursor not changing**: Only supported on X11 (`xsetroot`). Wayland sessions will skip this step.

* **Hot-key not responding**: Verify no other application is capturing `Ctrl + Alt + Space`. Run the script in a terminal to see any logged errors.

## Credits

* **Dockerfile & API**: [MartinOpenSky](https://github.com/martin-opensky) (whisper-assistant-vscode)
* **Scripts**: Dani Helinko & o4-mini
