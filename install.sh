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
  quickshell
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
    # If a parent dir is already a stow-folded symlink (e.g. ~/.config/nvim ->
    # ../dotfiles/nvim/.config/nvim), $target resolves back *into* the repo.
    # The -L test below only inspects the leaf, so without this guard we would
    # "back up" the repo's own tracked files and blow away the working tree.
    if [[ "$(readlink -f "$target" 2>/dev/null)" == "$DOTFILES_DIR"/* ]]; then
      continue
    fi
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

# Same folding hazard for ~/.local: the tmux-sessionizer package only ships
# .local/scripts/, so on a machine where ~/.local is missing stow links all of
# ~/.local at the repo and every program writing there (nvim state, mason,
# plugin checkouts) lands inside the working tree. Pre-create the standard
# XDG user dirs so there is nothing left for stow to fold.
mkdir -p "$HOME/.local"/{bin,share,state,scripts}

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
  # --no-folding: link the individual scripts, never the parent directory.
  stow -v --no-folding --restow tmux-sessionizer 2>/dev/null \
    || stow -v --no-folding tmux-sessionizer || true
fi

# Enable the per-user ssh-agent. Keys are added to it on first use
# (AddKeysToAgent in ~/.ssh/config), so the passphrase is asked once per login.
if [[ -f "$HOME/.config/systemd/user/ssh-agent.service" ]] && command -v systemctl >/dev/null; then
  echo "enable ssh-agent.service (systemd --user)"
  systemctl --user enable ssh-agent.service >/dev/null 2>&1 || true
fi

echo "=== dotfiles install finished ==="
echo "Open a new shell (or: source ~/.bashrc) for starship/fzf."

# Deliberately not run here: this script stays sudo-free so it is safe to run
# at any time. Point at it instead, and only when it has not been done, so the
# power-profile buttons do not fail silently on a fresh machine.
if [[ ! -x /usr/local/bin/cpu-power-profile ]]; then
  echo
  echo "System files are not installed yet (polkit rule + CPU helper, needed"
  echo "for the power-profile buttons to do anything):"
  echo "  sudo $DOTFILES_DIR/system/install-system.sh"
fi
