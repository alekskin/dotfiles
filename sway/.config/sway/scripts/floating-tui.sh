#!/bin/bash
# Overlay TUI in a floating alacritty (sway: app_id=floating-tui).
exec alacritty --class floating-tui -e "$@"
