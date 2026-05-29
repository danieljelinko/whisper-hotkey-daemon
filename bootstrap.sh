#!/usr/bin/env bash
# bootstrap.sh — download and install whisper-hotkey-daemon from scratch.
#
# One-liner install (copy and paste into Terminal):
#
#   curl -fsSL https://raw.githubusercontent.com/danieljelinko/whisper-hotkey-daemon/main/bootstrap.sh | bash
#
# What this script does:
#   1. Asks where to install (default: ~/Developer/whisper-hotkey-daemon on Mac)
#   2. Fetches the repo — git clone if git exists, else a curl tarball (no Xcode CLT!)
#   3. Runs ./install.sh (installs uv + Python wheels incl. mlx-whisper)
#
# Notably, the default macOS path needs NO Xcode Command Line Tools and NO
# Homebrew: the tarball comes via curl (built in) and mlx-whisper installs as
# prebuilt wheels via uv. The only large download is the Whisper model itself
# (~1.5 GB), which mlx fetches on first transcription.
#
# Env overrides:
#   WHISPER_INSTALL_DIR=~/my-dir   skip the directory prompt
#   WHISPER_REF=some-branch        which git ref to fetch
#
# Re-running is safe — each step is skipped if already done.
# Supported OS: macOS (Apple Silicon), Linux (Ubuntu/Debian/Fedora).

set -euo pipefail

REPO_SLUG="danieljelinko/whisper-hotkey-daemon"
REPO_URL="https://github.com/${REPO_SLUG}.git"
REPO_REF="${WHISPER_REF:-main}"
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
# WHISPER_INSTALL_DIR env var skips the prompt. When piped via `curl | bash`,
# stdin is the script, so read the answer from /dev/tty.
if [ -n "${WHISPER_INSTALL_DIR:-}" ]; then
    INSTALL_DIR="$WHISPER_INSTALL_DIR"
elif [ -r /dev/tty ]; then
    printf "Where should it install? [%s]: " "$DEFAULT_DIR"
    read -r REPLY < /dev/tty || REPLY=""
    INSTALL_DIR="${REPLY:-$DEFAULT_DIR}"
else
    INSTALL_DIR="$DEFAULT_DIR"   # non-interactive (no terminal): use default
fi

# Expand a leading ~ (read does not expand it).
case "$INSTALL_DIR" in
    "~")    INSTALL_DIR="$HOME" ;;
    "~/"*)  INSTALL_DIR="$HOME/${INSTALL_DIR#\~/}" ;;
esac

echo ""
echo "Install directory: $INSTALL_DIR"
echo ""

# ─── Fetch the repo (git if available, else tarball — no Xcode CLT) ───────────
git_works() {
    # macOS ships /usr/bin/git as a stub: command -v finds it, xcode-select -p
    # can return 0 with a placeholder path, but running the stub triggers the
    # Xcode CLT install dialog. The only reliable check is the binary path itself —
    # the stub is always exactly /usr/bin/git; a real git (CLT or Homebrew) is
    # at /Library/Developer/CommandLineTools/usr/bin/git or /opt/homebrew/bin/git.
    local gp
    gp="$(command -v git 2>/dev/null || true)"
    [ -n "$gp" ] || return 1              # no git binary at all
    [ "$gp" = "/usr/bin/git" ] && return 1  # macOS stub — do not invoke
    git --version >/dev/null 2>&1         # real git: verify it actually works
}

fetch_repo() {
    if [ -d "$INSTALL_DIR/.git" ]; then
        echo "✓ git checkout already at $INSTALL_DIR — pulling latest…"
        git -C "$INSTALL_DIR" pull --ff-only && return 0
    fi

    if git_works; then
        echo "Cloning with git (ref: $REPO_REF)…"
        git clone --branch "$REPO_REF" "$REPO_URL" "$INSTALL_DIR"
    else
        # No working git (macOS stub or missing binary) → tarball via curl.
        echo "git not available — downloading tarball with curl (no Xcode CLT needed)…"
        local url="https://github.com/${REPO_SLUG}/archive/refs/heads/${REPO_REF}.tar.gz"
        if [ -e "$INSTALL_DIR" ] && [ -n "$(ls -A "$INSTALL_DIR" 2>/dev/null)" ]; then
            echo "Note: $INSTALL_DIR exists and is not empty; extracting into it."
        fi
        mkdir -p "$INSTALL_DIR"
        # --strip-components=1 drops the GitHub-added top-level dir name.
        curl -fsSL "$url" | tar -xz --strip-components=1 -C "$INSTALL_DIR"
        echo "✓ Downloaded to $INSTALL_DIR"
        echo "  (No git history — to update later, re-run this bootstrap. For development,"
        echo "   install git via 'xcode-select --install' and re-clone.)"
    fi
}
fetch_repo

# ─── Run installer ────────────────────────────────────────────────────────────
echo ""
echo "Running installer…"
echo ""
cd "$INSTALL_DIR"
if [ ! -f install.sh ]; then
    echo "Error: install.sh is missing from $INSTALL_DIR."
    echo "Fetched ref: $REPO_REF"
    echo "This usually means bootstrap downloaded the wrong branch or an old install directory is in the way."
    echo "Try:"
    echo "  WHISPER_REF=main bash bootstrap.sh"
    exit 1
fi
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
