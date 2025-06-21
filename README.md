# Whisper Hotkey Daemon

A lightweight Python daemon that records audio from your microphone on a global hot-key (`Ctrl + Alt + Space`), sends it to a Docker-hosted Whisper transcription server, and places the resulting text in your clipboard (optionally pasting it into the active window).

Inspired by [MartinOpenSky's Whisper Assistant VSCode extension](https://github.com/martin-opensky/whisper-assistant-vscode) (Dockerfile)

---

## Features

* **Global hot-key listener**: Start recording when you press **Ctrl + Alt + Space**, stop when you release **Ctrl**.
* **Clipboard integration**: Automatically copies transcript to clipboard and pastes it if possible.
* **Structured logging**: Logs events, errors, and timings to `~/.local/share/whisper_hotkey.log`.

## Prerequisites

* **Operating System**: Ubuntu, Linux Mint (Cinnamon or Xfce), or any X11-based Linux desktop. Wayland is partially supported (clipboard and notifications, but no cursor change).
* **Hardware**: Any microphone input supported by ALSA.

### System Dependencies

```bash
sudo apt install sox xclip xdotool libnotify-bin python3-pip  # linux
pip install sounddevice soundfile numpy pynput requests pyperclip pyautogui win10toast # windows
pip install sounddevice soundfile numpy pynput requests pyperclip pyautogui # macOS
```

*For Wayland users*: replace `xdotool`/`xclip` with `wtype` and `wl-clipboard`.

### Python Dependencies

```bash
pip3 install --user pynput requests pyperclip
```

## Installation

0. **Install Whisper Docker container**

* Must build Docker container for x86_64 architecture

* Mac:

    ```bash
    docker run -d -p 4444:4444 --name whisper-assistant martinopensky/whisper-assistant:latest
    ```

* Linux, windows:

    ```bash
    git clone https://github.com/martin-opensky/whisper-assistant-vscode
    cd whisper-assistant-vscode
    DOCKER_BUILDKIT=1 docker build -t whisper-assistant-local .

    docker run -d -p 4444:4444 whisper-assistant-local # cpu
    docker run -d -p 4444:4444 --gpus all whisper-assistant-local # gpu support
    ```

1. **Clone or download** this repository to `~/.local/bin`:

   ```bash
   mkdir -p ~/.local/bin && git clone https://github.com/danieljelinko/whisper-hotkey-daemon.git ~/.local/bin/whisper-hotkey
   cd ~/.local/bin/whisper-hotkey
   chmod +x whisper_hotkey_linux.py
   ```

2. **Configure environment** (if needed):

   * If docker port changed set `WHISPER_API` to your transcription endpoint. Default is `http://localhost:4444/v1/audio/transcriptions`.

3. **Run as script in terminal or systemd user service**

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
* **Daemon script**: Dani Helinko & o4-mini
