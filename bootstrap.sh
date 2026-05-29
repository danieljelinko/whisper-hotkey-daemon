#!/usr/bin/env bash
# bootstrap.sh — download and install whisper-hotkey-daemon from scratch.
#
# One-liner install (copy and paste into Terminal):
#
#   curl -fsSL https://raw.githubusercontent.com/danieljelinko/whisper-hotkey-daemon/main/bootstrap.sh | bash
#
# What this script does:
#   1. Asks where to install (default: ~/Developer/whisper-hotkey-daemon on Mac)
#   2. Installs Xcode Command Line Tools (macOS) — provides git, clang, make
#   3. Installs Homebrew (macOS) if not present
#   4. Installs git if not present
#   5. Clones the repo to the chosen directory
#   6. Runs ./install.sh which handles everything else
#
# Skip the prompt by setting the directory up front:
#   curl -fsSL .../bootstrap.sh | WHISPER_INSTALL_DIR=~/my-dir bash
#
# Re-running is safe — each step is skipped if already done.
# Supported OS: macOS (Apple Silicon or Intel), Linux (Ubuntu/Debian/Fedora).

set -euo pipefail

REPO_URL="https://github.com/danieljelinko/whisper-hotkey-daemon.git"
OS="$(uname -s)"

# On macOS the Apple-recognised folder for dev projects is ~/Developer (Finder
# gives it a hammer icon). On Linux, ~ keeps it simple. Either is a fine default.
if [ "$OS" = "Darwin" ]; then DEFAULT_DIR="$HOME/Developer/whisper-hotkey-daemon"
else                          DEFAULT_DIR="$HOME/whisper-hotkey-daemon"; fi

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║      whisper-hotkey-daemon  bootstrap            ║"
echo "║  Hold a key → speak → release → text is pasted   ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

# ─── Choose install directory ─────────────────────────────────────────────────
# WHISPER_INSTALL_DIR env var skips the prompt (useful for non-interactive runs).
# When piped via `curl | bash`, stdin is the script, so read from /dev/tty.
if [ -n "${WHISPER_INSTALL_DIR:-}" ]; then
    INSTALL_DIR="$WHISPER_INSTALL_DIR"
elif [ -r /dev/tty ]; then
    printf "Where should it install? [%s]: " "$DEFAULT_DIR"
    read -r REPLY < /dev/tty || REPLY=""
    INSTALL_DIR="${REPLY:-$DEFAULT_DIR}"
else
    INSTALL_DIR="$DEFAULT_DIR"   # non-interactive (no terminal): use default
fi

# Expand a leading ~ (read does not expand it) and any env vars.
case "$INSTALL_DIR" in
    "~")    INSTALL_DIR="$HOME" ;;
    "~/"*)  INSTALL_DIR="$HOME/${INSTALL_DIR#\~/}" ;;
esac

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
