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
  ssh
  starship
  sway
  swaylock
  tmux
  waybar
  wofi
  xdg-desktop-portal
)

# Back up and remove any real (non-symlink) files a package would overwrite.
# A fresh Arch user has /etc/skel/.bashrc, .bash_profile, etc. in $HOME; stow
# silently refuses to link over them (rc=0, no symlink), so the config never
# applies. Clearing them first lets stow link cleanly. Existing stow symlinks
# are left alone.
preclean_conflicts() {
  local pkg=$1 rel target stamp
  stamp=$(date +%Y%m%d-%H%M%S)
  while IFS= read -r -d '' file; do
    rel=${file#"$pkg"/}
    target="$HOME/$rel"
    if [[ -e "$target" && ! -L "$target" ]]; then
      echo "  backup $target -> $target.bak.$stamp"
      mkdir -p "$(dirname "$target")"
      mv "$target" "$target.bak.$stamp"
    fi
  done < <(find "$pkg" -mindepth 1 \( -type f -o -type l \) -print0)
}

# Ensure ~/.ssh is a real directory before stowing. Otherwise stow "folds" a
# missing ~/.ssh into a symlink pointing at the repo, and generated keys would
# be written inside the repo. Pre-creating it makes stow link files *into* it.
mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"

echo "=== stow dotfiles from $DOTFILES_DIR ==="
for pkg in "${packages[@]}"; do
  if [[ -d "$pkg" ]]; then
    echo "stow $pkg"
    preclean_conflicts "$pkg"
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

# Enable the per-user ssh-agent. Keys are added to it on first use
# (AddKeysToAgent in ~/.ssh/config), so the passphrase is asked once per login.
if [[ -f "$HOME/.config/systemd/user/ssh-agent.service" ]] && command -v systemctl >/dev/null; then
  echo "enable ssh-agent.service (systemd --user)"
  systemctl --user enable ssh-agent.service >/dev/null 2>&1 || true
fi

echo "=== dotfiles install finished ==="
echo "Open a new shell (or: source ~/.bashrc) for starship/fzf."
