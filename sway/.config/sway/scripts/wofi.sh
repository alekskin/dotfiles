#!/bin/bash
# One wofi at a time. Same menu again closes it; a different menu replaces it.

set -u

runtime="${XDG_RUNTIME_DIR:-/tmp}"
sig_file="$runtime/wofi-${UID}.sig"
lock_file="$runtime/wofi-${UID}.lock"
this_sig=$(printf '%s\0' "$@" | cksum)

exec 9>"$lock_file"
if ! flock -n 9; then
  prev=$(cat "$sig_file" 2>/dev/null || true)
  pkill -u "$UID" -x wofi 2>/dev/null || true
  [[ "$prev" == "$this_sig" ]] && exit 0
  flock -w 2 9 || exit 1
fi

printf '%s\n' "$this_sig" >"$sig_file"
trap 'rm -f "$sig_file"' EXIT
wofi "$@"
