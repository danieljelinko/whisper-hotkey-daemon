#!/usr/bin/env python3
import pathlib, subprocess, tempfile, requests, os, logging, time
from pynput.keyboard import Key, Listener
import pyperclip

# ─── Configuration ────────────────────────────────────────────────────────────

API        = os.getenv("WHISPER_API",
                       "http://localhost:4444/v1/audio/transcriptions")
SOX        = [                          
    "sox", "-t", "alsa", "default",
    "-r", "16000", "-c", "1", "-b", "16", "-e", "signed-integer",
    "-t", "wav"
]
LOG_FILE   = pathlib.Path.home() / ".local/share/whisper_hotkey.log"
TMP_WAV    = pathlib.Path(tempfile.gettempdir()) / "whisper_tmp.wav"
IS_WAYLAND = bool(os.getenv("WAYLAND_DISPLAY"))
PASTE_CMD  = ["wtype"] if IS_WAYLAND else \
            ["xdotool", "key", "--clearmodifiers", "ctrl+v"]

# ─── Logging ───────────────────────────────────────────────────────────────────

LOG_FILE.parent.mkdir(parents=True, exist_ok=True)
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s: %(message)s",
    handlers=[logging.FileHandler(LOG_FILE), logging.StreamHandler()]
)
log = logging.getLogger("whisper_hotkey")

def notify(title, body="", silent=False):
    try:
        cmd = ["notify-send", "Whisper Hotkey"]
        if silent:
            cmd.append("--hint=boolean:suppress-sound:true")
        cmd.append(f"{title}\n{body}" if body else title)
        subprocess.run(cmd)
    except FileNotFoundError:
        log.debug("notify-send not found")

def set_cursor(name):
    if not IS_WAYLAND:
        subprocess.run(["xsetroot", "-cursor_name", name],
                       stderr=subprocess.DEVNULL)

# ─── Recorder state ───────────────────────────────────────────────────────────

recording = None                                    # active Popen or None

def start():
    global recording
    set_cursor("watch")
    notify("Listening…")
    recording = subprocess.Popen(SOX + [str(TMP_WAV)])
    log.info("Recording started (PID %s)", recording.pid)

def stop():
    global recording
    if recording is None:                # safety check
        return
    recording.terminate(); recording.wait()
    recording = None
    log.info("Recording stopped, %d B", TMP_WAV.stat().st_size)
    notify("Transcribing…", silent=True)
    set_cursor("watch")

    try:
        with TMP_WAV.open("rb") as f:
            t0 = time.time()
            r = requests.post(API,
                              files={"file": ("speech.wav", f, "audio/wav")})
            r.raise_for_status()
            log.info("API call %.2fs", time.time() - t0)
            text = r.json().get("text", "").strip()
    except Exception as e:
        log.error("Transcription failed: %s", e)
        notify("Transcription error", str(e))
        set_cursor("left_ptr")
        return

    pyperclip.copy(text)
    log.info("Transcript copied: %s", text)
    try:
        if PASTE_CMD[0] == "wtype":
            subprocess.run(PASTE_CMD, input=text.encode())
        else:
            subprocess.Popen(PASTE_CMD)
        log.info("Pasted with %s", PASTE_CMD[0])
    except FileNotFoundError:
        log.warning("Paste helper %s not available", PASTE_CMD[0])

    set_cursor("left_ptr")
    notify("Done", text[:197] + ("…" if len(text) > 200 else ""), silent=True)

# ─── Hot-key logic: start on Ctrl+Alt+Space ↓, stop on Ctrl ↑ ────────────────

CTRL_KEYS = {Key.ctrl_l, Key.ctrl_r}
ALT_KEYS  = {Key.alt_l, Key.alt_r}
pressed   = set()                                     # currently-held keys

log.info("Daemon up (Wayland=%s). Hold Ctrl + Alt + Space to record; "
         "release Ctrl to stop.", IS_WAYLAND)

def on_press(key):
    if key in CTRL_KEYS | ALT_KEYS | {Key.space}:
        pressed.add(key)

    if (recording is None and Key.space in pressed
            and pressed & CTRL_KEYS and pressed & ALT_KEYS):
        start()                                       # start once per combo

def on_release(key):
    if key in pressed:
        pressed.remove(key)
    if key in CTRL_KEYS and recording is not None:    # any Ctrl released → stop
        stop()

try:
    with Listener(on_press=on_press, on_release=on_release) as listener:
        listener.join()
except KeyboardInterrupt:
    log.info("Shutting down")
