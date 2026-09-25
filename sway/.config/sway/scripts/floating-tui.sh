#!/bin/bash
# Overlay TUI in a floating alacritty (sway: app_id=floating-tui-<program>).
#
# One window per program: if it is already open, focus it instead of starting
# another. The lock is held by alacritty for as long as the window lives (it
# inherits fd 9 through exec), so rapid double-clicks cannot race past it.

id="floating-tui-$(basename "$1")"
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/$id.lock"
if ! flock -n 9; then
  swaymsg -q "[app_id=\"^$id\$\"] focus"
  exit 0
fi
exec alacritty --class "$id" -e "$@"
