#!/usr/bin/env bash
# bootstrap.sh — download and install whisper-hotkey-daemon from scratch.
#
# One-liner install (copy and paste into Terminal):
#
#   curl -fsSL https://raw.githubusercontent.com/danieljelinko/whisper-hotkey-daemon/main/bootstrap.sh | bash
#
# What this script does:
#   1. Installs Xcode Command Line Tools (macOS) — provides git, clang, make
#   2. Installs Homebrew (macOS) if not present
#   3. Installs git if not present
#   4. Clones the repo to ~/whisper-hotkey-daemon
#   5. Runs ./install.sh which handles everything else
#
# Re-running is safe — each step is skipped if already done.
# Supported OS: macOS (Apple Silicon or Intel), Linux (Ubuntu/Debian/Fedora).

set -euo pipefail

REPO_URL="https://github.com/danieljelinko/whisper-hotkey-daemon.git"
INSTALL_DIR="${WHISPER_INSTALL_DIR:-$HOME/whisper-hotkey-daemon}"
OS="$(uname -s)"

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║      whisper-hotkey-daemon  bootstrap            ║"
echo "║  Hold a key → speak → release → text is pasted  ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""
echo "Install directory: $INSTALL_DIR"
echo ""

# ─── macOS pre-requisites ─────────────────────────────────────────────────────
if [ "$OS" = "Darwin" ]; then

    # 1. Xcode Command Line Tools (provides git, clang, make)
    if ! xcode-select -p >/dev/null 2>&1; then
        echo "Step 1/5: Installing Xcode Command Line Tools…"
        echo "          A dialog box will pop up — click 'Install', then come back here."
        echo ""
        xcode-select --install 2>/dev/null || true
        echo "Waiting for Xcode CLT to finish (this can take a few minutes)…"
        until xcode-select -p >/dev/null 2>&1; do
            sleep 5; echo -n "."
        done
        echo ""
        echo "✓ Xcode Command Line Tools installed"
    else
        echo "✓ Xcode Command Line Tools already installed"
    fi

    # 2. Homebrew
    if ! command -v brew >/dev/null 2>&1; then
        echo ""
        echo "Step 2/5: Installing Homebrew…"
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        # Add brew to PATH for this shell session
        eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null)" || \
        eval "$(/usr/local/bin/brew shellenv 2>/dev/null)" || true
        echo "✓ Homebrew installed"
    else
        echo "✓ Homebrew already installed"
    fi

    # 3. git (should be present after CLT, but belt-and-suspenders)
    if ! command -v git >/dev/null 2>&1; then
        echo "Step 3/5: Installing git via Homebrew…"
        brew install git
    else
        echo "✓ git: $(git --version)"
    fi

# ─── Linux pre-requisites ─────────────────────────────────────────────────────
elif [ "$OS" = "Linux" ]; then
    if ! command -v git >/dev/null 2>&1; then
        echo "Installing git…"
        if   command -v apt-get >/dev/null 2>&1; then sudo apt-get install -y git
        elif command -v dnf     >/dev/null 2>&1; then sudo dnf install -y git
        else echo "Error: git not found and no supported package manager detected."; exit 1
        fi
    else
        echo "✓ git: $(git --version)"
    fi
else
    echo "Error: unsupported OS '$OS'. Supported: macOS (Darwin) and Linux."
    exit 1
fi

# ─── Clone repo ───────────────────────────────────────────────────────────────
echo ""
if [ -d "$INSTALL_DIR/.git" ]; then
    echo "✓ Repo already cloned at $INSTALL_DIR — pulling latest…"
    git -C "$INSTALL_DIR" pull --ff-only
else
    echo "Cloning whisper-hotkey-daemon to $INSTALL_DIR…"
    git clone "$REPO_URL" "$INSTALL_DIR"
fi

# ─── Run installer ────────────────────────────────────────────────────────────
echo ""
echo "Running installer…"
echo ""
cd "$INSTALL_DIR"
bash install.sh

# ─── Done ─────────────────────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════"
if [ "$OS" = "Darwin" ]; then
    echo ""
    echo "  Before first run — grant two macOS permissions:"
    echo ""
    echo "  1. Microphone:"
    echo "     System Settings → Privacy & Security → Microphone"
    echo "     ✦ enable your terminal app"
    echo ""
    echo "  2. Accessibility (for the hotkey and paste):"
    echo "     System Settings → Privacy & Security → Accessibility"
    echo "     ✦ enable your terminal app"
    echo ""
    echo "  Then verify everything works:"
    echo "    cd $INSTALL_DIR && ./scripts/test_mac_setup.sh"
    echo ""
fi
echo "  Start the daemon:"
echo "    cd $INSTALL_DIR && ./run.sh"
echo ""
echo "  Hold  Ctrl + Option + Space  to record"
echo "  Release Ctrl  to transcribe and paste"
echo "═══════════════════════════════════════════"
