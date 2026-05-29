"""Integration test: the whisper.cpp server honors the same HTTP contract the
daemon relies on (`POST /v1/audio/transcriptions` → JSON with a `text` field).

Skipped unless the whisper-server binary and model are built (see
`101_install_whispercpp.sh`). This is the *exact* contract the macOS Metal build
will serve, so proving it here de-risks the Mac path.
"""
import os, socket, subprocess, time, pathlib
import pytest, requests

HERE      = pathlib.Path(__file__).parent
FIXTURE   = HERE / "fixtures" / "sample_speech.wav"
BIN       = pathlib.Path(os.getenv("WHISPERCPP_BIN",
              pathlib.Path.home() / ".cache/whisper.cpp/repo/build/bin/whisper-server"))
MODEL     = pathlib.Path(os.getenv("WHISPERCPP_MODEL",
              pathlib.Path.home() / ".cache/whisper.cpp/repo/models/ggml-large-v3-turbo-q5_0.bin"))
INFER_PATH = "/v1/audio/transcriptions"

pytestmark = pytest.mark.skipif(
    not (BIN.exists() and MODEL.exists()),
    reason=f"whisper-server or model not built (run 101_install_whispercpp.sh); BIN={BIN} MODEL={MODEL}")


def _free_port() -> int:
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0)); return s.getsockname()[1]


@pytest.fixture
def whisper_server():
    "Launch whisper-server on a free port, wait until it answers, tear it down."
    port = _free_port()
    proc = subprocess.Popen(
        [str(BIN), "-m", str(MODEL), "--host", "127.0.0.1", "--port", str(port),
         "--inference-path", INFER_PATH],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    base = f"http://127.0.0.1:{port}"
    try:
        for _ in range(120):                       # model load can take a while on CPU
            if proc.poll() is not None: pytest.fail("whisper-server exited during startup")
            try:
                requests.get(base, timeout=1); break
            except requests.ConnectionError:
                time.sleep(1)
        else:
            pytest.fail("whisper-server did not become ready in time")
        yield base + INFER_PATH
    finally:
        proc.terminate(); proc.wait()


def test_whispercpp_returns_json_with_text_field_for_wav(whisper_server):
    # Given a running whisper.cpp server and a real spoken WAV
    with FIXTURE.open("rb") as f:
        # When we POST it the way the daemon does
        r = requests.post(whisper_server,
                          files={"file": ("speech.wav", f, "audio/wav")}, timeout=120)

    # Then we get a 200 with a JSON body carrying a non-empty `text` string
    r.raise_for_status()
    body = r.json()
    assert "text" in body
    assert isinstance(body["text"], str) and body["text"].strip()


def test_whispercpp_transcribes_known_token(whisper_server):
    # Given the fixture says "Testing whisper transcription. One two three four five."
    with FIXTURE.open("rb") as f:
        # When transcribed
        r = requests.post(whisper_server,
                          files={"file": ("speech.wav", f, "audio/wav")}, timeout=120)
    text = r.json().get("text", "").lower()

    # Then at least one expected token survives (loose: TTS+ASR isn't exact)
    assert any(tok in text for tok in ("test", "whisper", "three", "transcription")), \
        f"no expected token in transcript: {text!r}"
