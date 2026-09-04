#!/bin/bash
# Install the parts of this repo that live outside $HOME. Run as root:
#   sudo ~/dotfiles/system/install-system.sh
# Everything else is user-level and handled by ../install.sh (stow).

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "error: run as root (sudo $0)" >&2
  exit 1
fi

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# pkexec refuses to run a program that is not owned by root or is writable by
# anyone else, so install a copy rather than symlinking into the repo.
install -o root -g root -m 0755 \
  "$SRC/usr/local/bin/cpu-power-profile" /usr/local/bin/cpu-power-profile
install -o root -g root -m 0644 \
  "$SRC/etc/polkit-1/rules.d/49-cpu-power-profile.rules" \
  /etc/polkit-1/rules.d/49-cpu-power-profile.rules

echo "installed:"
echo "  /usr/local/bin/cpu-power-profile"
echo "  /etc/polkit-1/rules.d/49-cpu-power-profile.rules"
echo "polkit picks up rules.d changes automatically; no restart needed."
