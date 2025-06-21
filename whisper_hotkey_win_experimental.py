#!/usr/bin/env python
# whisper_hotkey_win.py
# requirements : pip install sounddevice soundfile numpy pynput requests pyperclip pyautogui win10toast
import os, pathlib, logging, time, tempfile, queue, wave
import requests, numpy as np, pyperclip
import sounddevice as sd, soundfile as sf
from pynput.keyboard import Key, Listener
import pyautogui

# ── Configuration ──────────────────────────────────────────────────────────
API         = os.getenv("WHISPER_API", "http://localhost:4444/v1/audio/transcriptions")
RATE        = 16_000                # Hz
CHANNELS    = 1
KEY_COMBO   = (Key.ctrl_l, Key.ctrl_r)  # stop on release of either Ctrl
LOG_FILE    = pathlib.Path.home() / "whisper_hotkey_win.log"
TMP_WAV     = pathlib.Path(tempfile.gettempdir()) / "whisper_tmp.wav"

# ── Logging  ───────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s: %(message)s",
    handlers=[logging.FileHandler(LOG_FILE), logging.StreamHandler()]
)
log = logging.getLogger("whisper_hotkey")

# ── Optional Windows toast notifications ──────────────────────────────────
try:
    from win10toast import ToastNotifier
    _notifier = ToastNotifier()
    def notify(title, msg=""): _notifier.show_toast(title, msg, threaded=True)
except Exception:
    def notify(*a, **k): pass        # silently noop if win10toast absent

# ── Recorder state  ───────────────────────────────────────────────────────
audio_q: "queue.Queue[np.ndarray]" = queue.Queue()
stream  = None
pressed = set()

def _audio_cb(indata, frames, time_info, status):
    """Store raw mic frames in a queue."""
    audio_q.put(indata.copy())

def start_recording():
    global stream
    if stream: return
    audio_q.queue.clear()
    stream = sd.InputStream(samplerate=RATE, channels=CHANNELS,
                            dtype='int16', callback=_audio_cb)
    stream.start()
    notify("Listening…")
    log.info("Recording started")

def stop_recording():
    global stream
    if not stream: return
    stream.stop(); stream.close(); stream = None
    log.info("Recording stopped; assembling WAV")

    # dump queue → WAV
    with wave.open(str(TMP_WAV), 'wb') as wf:
        wf.setnchannels(CHANNELS)
        wf.setsampwidth(2)           # int16 = 2 bytes
        wf.setframerate(RATE)
        while not audio_q.empty():
            wf.writeframes(audio_q.get().tobytes())

    notify("Transcribing…")
    try:
        with TMP_WAV.open('rb') as f:
            r = requests.post(API, files={'file': ('audio.wav', f, 'audio/wav')})
            r.raise_for_status()
        text = r.json().get("text", "").strip()
        log.info("Transcript: %s", text)
    except Exception as e:
        notify("Transcription error", str(e))
        log.error("Transcription failed: %s", e)
        return

    pyperclip.copy(text)
    try:
        pyautogui.hotkey('ctrl', 'v')
    except Exception:
        pass
    notify("Done", text[:200] + ("…" if len(text) > 200 else ""))

# ── Hot-key logic  (Ctrl+Alt+Space ↓ → start, Ctrl ↑ → stop) ─────────────
CTRL_KEYS = {Key.ctrl_l, Key.ctrl_r}
ALT_KEYS  = {Key.alt_l, Key.alt_r}

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

log.info("Whisper hot-key daemon running. Hold Ctrl+Alt+Space to record; "
         "release Ctrl to stop.  API=%s", API)
try:
    with Listener(on_press=on_press, on_release=on_release) as listener:
        listener.join()
except KeyboardInterrupt:
    log.info("Interrupted, exiting")
