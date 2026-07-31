#!/bin/bash
# Start clipboard history watchers if they are not already running.
# Safe to call on every sway reload (exec_always).

start_one() {
  local pattern="$1"
  shift
  if pgrep -f "$pattern" >/dev/null 2>&1; then
    return 0
  fi
  "$@" &
}

# Persist clipboard after the source app exits
start_one 'wl-clip-persist --clipboard regular' \
  wl-clip-persist --clipboard regular

# Store text + images into cliphist
start_one 'wl-paste --type text --watch cliphist store' \
  wl-paste --type text --watch cliphist store

start_one 'wl-paste --type image --watch cliphist store' \
  wl-paste --type image --watch cliphist store
