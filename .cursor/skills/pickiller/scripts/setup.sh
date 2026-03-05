#!/usr/bin/env bash
set -euo pipefail

echo "=== Pickiller dependency installer ==="

OS="$(uname -s)"

install_pkg() {
    local cmd="$1" pkg="$2"
    if command -v "$cmd" &>/dev/null; then
        echo "✓ $cmd already installed"
    else
        echo "Installing $pkg..."
        case "$OS" in
            Darwin) brew install "$pkg" ;;
            Linux)  sudo apt-get update -qq && sudo apt-get install -y "$pkg" ;;
        esac
    fi
}

case "$OS" in
    Darwin)
        if ! command -v brew &>/dev/null; then
            echo "Error: Homebrew not found. Install from https://brew.sh" >&2
            exit 1
        fi
        ;;
    Linux) ;;
    *)
        echo "Unsupported OS: $OS. Please install imagemagick and potrace manually." >&2
        exit 1
        ;;
esac

install_pkg magick imagemagick
install_pkg potrace potrace
install_pkg pdfinfo poppler
install_pkg rsvg-convert librsvg

echo ""
echo "=== All dependencies ready ==="
