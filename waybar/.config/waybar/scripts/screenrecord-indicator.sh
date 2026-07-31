#!/bin/bash
# Waybar: show while wf-recorder is running. Click stops recording.

if pgrep -x wf-recorder >/dev/null 2>&1; then
  tip="Recording — click to stop"
  file="${XDG_RUNTIME_DIR:-/tmp}/sway-screenrecord-filename"
  if [[ -f "$file" ]]; then
    tip="Recording $(basename "$(cat "$file")") — click to stop"
  fi
  echo "{\"text\": \"\", \"tooltip\": \"$tip\", \"class\": \"recording\"}"
else
  echo '{"text": "", "tooltip": ""}'
fi
