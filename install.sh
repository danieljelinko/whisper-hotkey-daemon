#!/usr/bin/env bash
set -euo pipefail

# One-stop installer for whisper-hotkey-daemon.
# Detects the OS and backend, installs all system dependencies, then sets up
# the whisper.cpp server and downloads the default model.
#
# Usage:
#   ./install.sh                  # auto-detect
#   WHISPER_BACKEND=docker_cuda ./install.sh   # force Docker path (Linux only)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OS="$(uname -s)"
WHISPER_BACKEND="${WHISPER_BACKEND:-}"

# ─── Detect backend ───────────────────────────────────────────────────────────
if [ -z "$WHISPER_BACKEND" ]; then
    if [ "$OS" = "Darwin" ]; then
        WHISPER_BACKEND="whispercpp_metal"
    elif command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L >/dev/null 2>&1; then
        WHISPER_BACKEND="docker_cuda"
    else
        WHISPER_BACKEND="whispercpp_cpu"
    fi
fi

echo "=== whisper-hotkey-daemon installer ==="
echo "OS: $OS | Backend: $WHISPER_BACKEND"
echo ""

# ─── macOS ────────────────────────────────────────────────────────────────────
if [ "$OS" = "Darwin" ]; then
    echo "── macOS dependencies ──"

    # Xcode Command Line Tools — required for git, clang, make.
    # The Homebrew installer below triggers the CLT install dialog automatically,
    # but if Homebrew is already present and CLT is missing, catch it here.
    if ! xcode-select -p >/dev/null 2>&1; then
        echo ""
        echo "Xcode Command Line Tools are not installed."
        echo "Starting the install dialog now — click 'Install' in the popup that appears."
        echo ""
        xcode-select --install 2>/dev/null || true
        echo "Waiting for Command Line Tools installation to complete…"
        until xcode-select -p >/dev/null 2>&1; do sleep 5; done
        echo "✓ Xcode Command Line Tools installed"
    else
        echo "✓ Xcode Command Line Tools: $(xcode-select -p)"
    fi

    # Homebrew — also installs CLT if somehow still missing
    if ! command -v brew >/dev/null 2>&1; then
        echo "Installing Homebrew…"
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        # Add brew to PATH for this session
        eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null)" || \
        eval "$(/usr/local/bin/brew shellenv 2>/dev/null)" || true
    else
        echo "✓ Homebrew: $(brew --version | head -1)"
    fi

    # uv
    if ! command -v uv >/dev/null 2>&1; then
        echo "Installing uv…"
        curl -LsSf https://astral.sh/uv/install.sh | sh
        # Source the env file uv's installer creates, or add common paths
        # shellcheck source=/dev/null
        [ -f "$HOME/.local/bin/env" ] && source "$HOME/.local/bin/env" || \
            export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
    else
        echo "✓ uv: $(uv --version)"
    fi

    # whisper.cpp (Metal) + model
    echo ""
    echo "── whisper.cpp (Metal) ──"
    bash "$SCRIPT_DIR/scripts/101_install_whispercpp.sh"

    echo ""
    echo "── Python dependencies ──"
    uv sync

    echo ""
    echo "✓ macOS installation complete."
    echo ""
    echo "IMPORTANT — grant two macOS permissions before running:"
    echo "  1. Microphone:   System Settings → Privacy & Security → Microphone → enable Terminal (or your terminal app)"
    echo "  2. Accessibility: System Settings → Privacy & Security → Accessibility → enable Terminal (or your terminal app)"
    echo ""
    echo "Verify setup:  ./scripts/test_mac_setup.sh"
    echo "Run daemon:    ./run.sh"

# ─── Linux ────────────────────────────────────────────────────────────────────
elif [ "$OS" = "Linux" ]; then
    echo "── Linux dependencies ──"

    if command -v apt-get >/dev/null 2>&1; then
        PKG_INSTALL="sudo apt-get install -y"
    elif command -v dnf >/dev/null 2>&1; then
        PKG_INSTALL="sudo dnf install -y"
    else
        echo "Warning: unknown package manager; install deps manually if needed."
        PKG_INSTALL=""
    fi

    if [ -n "$PKG_INSTALL" ]; then
        echo "Installing system packages (sox, libnotify, xdotool/wtype, curl)…"
        $PKG_INSTALL sox libnotify-bin curl

        # Display-server tools
        if [ -n "${WAYLAND_DISPLAY:-}" ]; then
            $PKG_INSTALL wtype wl-clipboard 2>/dev/null || \
                echo "Warning: wtype/wl-clipboard not found in repos; install manually for Wayland paste."
        else
            $PKG_INSTALL xdotool x11-xserver-utils xclip 2>/dev/null || true
        fi
    fi

    # uv
    if ! command -v uv >/dev/null 2>&1; then
        echo "Installing uv…"
        curl -LsSf https://astral.sh/uv/install.sh | sh
        export PATH="$HOME/.local/bin:$PATH"
    else
        echo "✓ uv already installed"
    fi

    echo ""
    echo "── Python dependencies ──"
    uv sync

    # Backend-specific
    if [ "$WHISPER_BACKEND" = "docker_cuda" ]; then
        echo ""
        echo "── Docker CUDA backend ──"
        command -v docker >/dev/null || {
            echo "Docker not found. Install Docker and the NVIDIA Container Toolkit, then re-run."
            echo "  See: scripts/100_install_nvidia_container_toolkit.sh"
            exit 1
        }
        echo "✓ Docker present. Build or pull the whisper-assistant image before running."
        echo "  See README.md → Installation → step 0."
    else
        echo ""
        echo "── whisper.cpp (CPU) ──"
        $PKG_INSTALL cmake build-essential 2>/dev/null || \
            { echo "Warning: could not install cmake/build-essential via package manager."; }
        bash "$SCRIPT_DIR/scripts/101_install_whispercpp.sh"
    fi

    echo ""
    echo "✓ Linux installation complete."
    echo "Run:  ./run.sh"

else
    echo "Error: unsupported OS '$OS'. Supported: Darwin, Linux."
    exit 1
fi
