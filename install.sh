#!/bin/bash
# Stow all desktop packages into $HOME.
# Usage:
#   ~/dotfiles/install.sh
#   bash /path/to/dotfiles/install.sh

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DOTFILES_DIR"

if ! command -v stow >/dev/null; then
  echo "error: stow is not installed (pacman -S stow)" >&2
  exit 1
fi

packages=(
  alacritty
  bash
  foot
  ghostty
  mako
  nvim
  starship
  sway
  swaylock
  tmux
  waybar
  wofi
  xdg-desktop-portal
)

echo "=== stow dotfiles from $DOTFILES_DIR ==="
for pkg in "${packages[@]}"; do
  if [[ -d "$pkg" ]]; then
    echo "stow $pkg"
    # --adopt can pull conflicting real files into the repo; avoid by default.
    # Restow refreshes links if package was partially linked.
    if ! stow -v --restow "$pkg" 2>/dev/null; then
      stow -v "$pkg"
    fi
  else
    echo "skip $pkg (missing)"
  fi
done

if [[ -d tmux-sessionizer ]]; then
  echo "stow tmux-sessionizer"
  stow -v --restow tmux-sessionizer 2>/dev/null || stow -v tmux-sessionizer || true
fi

echo "=== dotfiles install finished ==="
echo "Open a new shell (or: source ~/.bashrc) for starship/fzf."
