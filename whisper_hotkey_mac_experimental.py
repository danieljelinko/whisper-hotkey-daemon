#!/usr/bin/env python3
# whisper_hotkey_mac.py
"""
Hold Ctrl + Option + Space to start dictation, release *either* Ctrl key to stop.
The captured audio is sent to a Whisper server and the transcription is copied
to the clipboard and pasted (⌘-V) into the front-most application.

Prereqs (Python ≥ 3.10):
    pip install sounddevice soundfile numpy pynput requests pyperclip pyautogui
    # sounddevice wheels already bundle PortAudio on macOS; no Homebrew needed.
"""

import os, pathlib, logging, time, tempfile, queue, wave, subprocess
import requests, numpy as np, pyperclip, sounddevice as sd, soundfile as sf
from pynput.keyboard import Key, Listener
import pyautogui

# ── Settings ──────────────────────────────────────────────────────────────
API          = os.getenv("WHISPER_API",
                         "http://localhost:4444/v1/audio/transcriptions")
RATE         = 16_000           # Hz
CHANNELS     = 1
LOG_FILE     = pathlib.Path.home() / "whisper_hotkey_mac.log"
TMP_WAV      = pathlib.Path(tempfile.gettempdir()) / "whisper_tmp.wav"
CTRL_KEYS    = {Key.ctrl_l, Key.ctrl_r}
ALT_KEYS     = {Key.alt_l, Key.alt_r}

# ── Logging ───────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s: %(message)s",
    handlers=[logging.FileHandler(LOG_FILE), logging.StreamHandler()]
)
log = logging.getLogger("whisper_hotkey")

# ── macOS notification helper (osa-script)─────────────────────────────────
def _escape(text: str) -> str:
    return text.replace('"', '\\"')

def notify(title: str, body: str = "") -> None:
    try:
        osa = f'display notification "{_escape(body)}" with title "{_escape(title)}"'
        subprocess.run(["osascript", "-e", osa], check=True)
    except Exception as e:
        log.debug("Notification failed: %s", e)

# ── Recorder state ────────────────────────────────────────────────────────
stream       = None                   # active sounddevice.InputStream
queue_frames: "queue.Queue[np.ndarray]" = queue.Queue()
pressed      = set()

def _audio_cb(indata, frames, t, status):
    queue_frames.put(indata.copy())

def start_recording():
    global stream
    if stream is not None:
        return
    queue_frames.queue.clear()
    stream = sd.InputStream(samplerate=RATE, channels=CHANNELS,
                            dtype="int16", callback=_audio_cb)
    stream.start()
    notify("Listening…")
    log.info("Recording started")

def stop_recording():
    global stream
    if stream is None:
        return
    stream.stop(); stream.close(); stream = None
    log.info("Recording stopped; assembling WAV")

    with wave.open(str(TMP_WAV), "wb") as wf:
        wf.setnchannels(CHANNELS)
        wf.setsampwidth(2)           # int16
        wf.setframerate(RATE)
        while not queue_frames.empty():
            wf.writeframes(queue_frames.get().tobytes())

    notify("Transcribing…")
    try:
        with TMP_WAV.open("rb") as f:
            r = requests.post(API, files={"file": ("speech.wav", f, "audio/wav")})
            r.raise_for_status()
        text = r.json().get("text", "").strip()
        log.info("Transcript: %s", text)
    except Exception as e:
        notify("Transcription error", str(e))
        log.error("Transcription failed: %s", e)
        return

    # clipboard + paste
    pyperclip.copy(text)
    try:
        pyautogui.hotkey("command", "v")      # requires Accessibility permission the first time
    except Exception:
        pass
    notify("Done", text[:200] + ("…" if len(text) > 200 else ""))

# ── Hot-key logic ─────────────────────────────────────────────────────────
def on_press(key):
    pressed.add(key)
    if (stream is None
        and Key.space in pressed
        and pressed & CTRL_KEYS
        and pressed & ALT_KEYS):
        start_recording()

def on_release(key):
    if key in CTRL_KEYS and stream is not None:
        stop_recording()
    pressed.discard(key)

log.info("Whisper hot-key daemon (macOS) ready. "
         "Hold Ctrl+Option+Space to record; release Ctrl to stop.  API=%s", API)

try:
    with Listener(on_press=on_press, on_release=on_release) as listener:
        listener.join()
except KeyboardInterrupt:
    log.info("Interrupted, exiting")
