#!/bin/bash
# Pick an entry from cliphist and put it back on the clipboard.
# Images: thumbnail preview in wofi (metadata burned into the thumb).
# Bound to Ctrl+Shift+V.
#
# Thumbnails: ${XDG_CACHE_HOME:-$HOME/.cache}/cliphist/thumbs/<id>.png
# Clipboard images have no original filesystem path — only this cache + cliphist db.

set -u

if ! command -v cliphist >/dev/null || ! command -v wl-copy >/dev/null; then
  notify-send "Clipboard history" "Install: cliphist wl-clipboard" -u critical 2>/dev/null || true
  exit 1
fi

~/.config/sway/scripts/clipboard-daemon.sh

thumb_dir="${XDG_CACHE_HOME:-$HOME/.cache}/cliphist/thumbs"
mkdir -p "$thumb_dir"

# cliphist list can contain NUL bytes (UTF-16 text from browsers). Strip them.
tmp_list=$(mktemp)
tmp_menu=$(mktemp)
trap 'rm -f "$tmp_list" "$tmp_menu"' EXIT

cliphist list 2>/dev/null | tr -d '\0' >"$tmp_list" || true

if [[ ! -s "$tmp_list" ]]; then
  notify-send "Clipboard history" "Empty — copy something first, then try again" -t 3000 2>/dev/null || true
  exit 0
fi

# Drop thumbnails for entries that no longer exist
shopt -s nullglob
ids=()
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  ids+=("${line%%$'\t'*}")
done <"$tmp_list"
for thumb in "$thumb_dir"/*; do
  base=$(basename "$thumb")
  id=${base%.*}
  keep=false
  for x in "${ids[@]}"; do
    [[ "$x" == "$id" ]] && { keep=true; break; }
  done
  $keep || rm -f "$thumb"
done
shopt -u nullglob

parse_meta() {
  # Sets: meta_size meta_dims meta_fmt from cliphist preview string
  local preview=$1
  meta_size=""; meta_dims=""; meta_fmt=""
  if [[ "$preview" =~ ([0-9]+([.][0-9]+)?[[:space:]]*[KMG]?i?B) ]]; then
    meta_size="${BASH_REMATCH[1]}"
  fi
  if [[ "$preview" =~ ([0-9]+x[0-9]+) ]]; then
    meta_dims="${BASH_REMATCH[1]}"
  fi
  if [[ "$preview" =~ (png|jpe?g|bmp|gif|webp) ]]; then
    meta_fmt="${BASH_REMATCH[1]}"
  fi
}

make_thumb() {
  local id=$1 ext=$2 preview=$3
  # Always use .png for thumbs (ffmpeg output) so wofi loads reliably
  local thumb="$thumb_dir/${id}.png"
  [[ -f "$thumb" && -s "$thumb" ]] && { printf '%s' "$thumb"; return 0; }

  parse_meta "$preview"
  local label="${meta_fmt:-img}"
  [[ -n "$meta_size" ]] && label+=" ${meta_size}"
  [[ -n "$meta_dims" ]] && label+=" ${meta_dims}"
  label+=" #${id}"
  # Escape for ffmpeg drawtext
  local label_esc=${label//\\/\\\\}
  label_esc=${label_esc//:/\\:}
  label_esc=${label_esc//\'/\'\\\'\'}

  rm -f "$thumb"
  if command -v ffmpeg >/dev/null; then
    # Scale, then pad a caption bar with format / size / dims / id
    if printf '%s\t\n' "$id" | cliphist decode 2>/dev/null \
      | ffmpeg -hide_banner -loglevel error -y -i pipe:0 \
          -vf "scale=320:180:force_original_aspect_ratio=decrease,
               pad=320:200:(ow-iw)/2:0:color=0x1e1e2e,
               drawtext=text='${label_esc}':fontcolor=0xcdd6f4:fontsize=12:x=8:y=h-16" \
          "$thumb" \
      && [[ -s "$thumb" ]]; then
      printf '%s' "$thumb"
      return 0
    fi
    # Retry without drawtext (fontconfig may be missing)
    if printf '%s\t\n' "$id" | cliphist decode 2>/dev/null \
      | ffmpeg -hide_banner -loglevel error -y -i pipe:0 \
          -vf "scale=320:180:force_original_aspect_ratio=decrease" \
          "$thumb" \
      && [[ -s "$thumb" ]]; then
      printf '%s' "$thumb"
      return 0
    fi
  fi

  # Raw dump fallback
  local raw="$thumb_dir/${id}.raw.${ext}"
  if printf '%s\t\n' "$id" | cliphist decode >"$raw" 2>/dev/null && [[ -s "$raw" ]]; then
    mv "$raw" "$thumb_dir/${id}.${ext}"
    printf '%s' "$thumb_dir/${id}.${ext}"
    return 0
  fi
  rm -f "$raw" "$thumb"
  return 1
}

while IFS= read -r line || [[ -n "${line:-}" ]]; do
  [[ -z "${line:-}" ]] && continue
  id=${line%%$'\t'*}
  preview=${line#*$'\t'}
  [[ "$line" != *$'\t'* ]] && continue

  if [[ "$preview" == \<meta\ http-equiv=* || "$preview" == \<html* || "$preview" == \<!DOCTYPE* ]]; then
    continue
  fi

  # cliphist image line: "[[ binary data 44 KiB png 665x188 ]]"
  if [[ "$preview" =~ \[\[.*binary.*(png|jpe?g|bmp|gif|webp) ]]; then
    ext=$(grep -oE 'png|jpeg|jpg|bmp|gif|webp' <<<"$preview" | head -1)
    [[ "$ext" == jpeg ]] && ext=jpg
    if thumb=$(make_thumb "$id" "$ext" "$preview"); then
      # IMPORTANT: wofi treats everything after "img:" as the file path (no caption).
      printf 'img:%s\n' "$thumb" >>"$tmp_menu"
      continue
    fi
  fi

  printf '%s\n' "$line" >>"$tmp_menu"
done <"$tmp_list"

if [[ ! -s "$tmp_menu" ]]; then
  notify-send "Clipboard history" "Empty — copy something first, then try again" -t 3000 2>/dev/null || true
  exit 0
fi

wofi_conf="${XDG_CONFIG_HOME:-$HOME/.config}/wofi/clipboard-config"
if [[ -f "$wofi_conf" ]]; then
  chosen=$(wofi --dmenu --conf "$wofi_conf" --allow-images <"$tmp_menu" 2>/dev/null || true)
else
  chosen=$(wofi --dmenu --allow-images --prompt "Clipboard" --width 640 --height 420 \
    --cache-file /dev/null --define=image_size=128 <"$tmp_menu" 2>/dev/null || true)
fi

[[ -z "${chosen:-}" ]] && exit 0

# Always restore by cliphist id (full list lines may be NUL-stripped / truncated).
if [[ "$chosen" == img:* ]]; then
  path=${chosen#img:}
  path=${path%%[[:space:]]*}
  base=$(basename "$path")
  id=${base%%.*}
else
  # "id\tpreview…" or just "id"
  id=${chosen%%$'\t'*}
  id=${id%% *}
fi

if [[ ! "$id" =~ ^[0-9]+$ ]]; then
  notify-send "Clipboard history" "Could not resolve entry id" -u critical 2>/dev/null || true
  exit 1
fi

# Normalize UTF-16 browser text → UTF-8, set proper MIME (text/plain or image/*)
printf '%s\t\n' "$id" | cliphist decode \
  | python3 ~/.config/sway/scripts/cliphist-to-clipboard.py
