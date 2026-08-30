#!/bin/bash
# Renders a preview thumbnail for every boot screen option into
# ~/.local/state/omarchy/lock-explorer-boot-previews/, one per option and
# theme, so the explorer can show what each would look like before applying
# anything. Existing previews for the current theme are kept, other themes'
# are pruned. Safe to re-run; does nothing privileged.
set -euo pipefail
here="$(dirname "$(realpath "$0")")"

outdir="${1:-$HOME/.local/state/omarchy/lock-explorer-boot-previews}"
mkdir -p "$outdir"
theme=$(cat "$HOME/.local/state/omarchy/current/theme.name" 2>/dev/null || echo unknown)

find "$outdir" -name '*.png' ! -name "*-$theme.png" -delete 2>/dev/null || true

# The stock splash ships with its own colors, but the thumbnail still gets a
# per-theme name so pruning and cache busting stay uniform.
if [[ ! -f $outdir/stock-$theme.png ]]; then
  stock="${OMARCHY_PATH:-$HOME/.local/share/omarchy}/default/plymouth"
  if [[ -f $stock/logo.png ]]; then
    magick -size 720x405 xc:'#1a1b26' \
      \( "$stock/logo.png" -resize x120 \) -gravity center -geometry +0-30 -composite \
      \( "$stock/entry.png" -resize x26 \) -gravity center -geometry +0+60 -composite \
      "$outdir/stock-$theme.png" || true
  fi
fi

render() {
  local out="$1"; shift
  [[ -f $out ]] && return 0
  local staging; staging=$(mktemp -d)
  if PREVIEW_ONLY=1 "$@" "$staging" >/dev/null 2>&1 && [[ -f $staging/preview.png ]]; then
    cp "$staging/preview.png" "$out"
  fi
  rm -rf "$staging"
}

for gen in "$here"/*/generate.sh; do
  id=$(basename "$(dirname "$gen")")
  [[ $id == custom ]] && continue
  render "$outdir/$id-$theme.png" bash "$gen"
done

# The user's own clips and boot layouts. Preview filenames swap ':' for '-'
# to stay filesystem friendly; the explorer does the same lookup.
for clip in "$HOME"/.config/omarchy/lock-videos/*.mp4 "$HOME"/.config/omarchy/lock-videos/*.webm \
            "$HOME"/.config/omarchy/lock-videos/*.mkv "$HOME"/.config/omarchy/lock-videos/*.mov; do
  [[ -f $clip ]] || continue
  name=$(basename "$clip")
  staging=$(mktemp -d)
  out="$outdir/video-$name-$theme.png"
  if [[ ! -f $out ]]; then
    if PREVIEW_ONLY=1 bash "$here/cliptwin.sh" "$staging" "video:$name" "$name" >/dev/null 2>&1 && [[ -f $staging/preview.png ]]; then
      cp "$staging/preview.png" "$out"
    fi
  fi
  rm -rf "$staging"
done

for conf in "$HOME"/.config/omarchy/boot-designs/*.conf; do
  [[ -f $conf ]] || continue
  name=$(basename "$conf" .conf)
  out="$outdir/custom-$name-$theme.png"
  if [[ ! -f $out || $out -ot $conf ]]; then
    staging=$(mktemp -d)
    if bash "$here/custom/generate.sh" "$staging" "$conf" "custom:$name" >/dev/null 2>&1 && [[ -f $staging/preview.png ]]; then
      cp "$staging/preview.png" "$out"
    fi
    rm -rf "$staging"
  fi
  # The matching lock screen QML + its preview from the same layout.
  lock_out="$outdir/custom-$name-lock-$theme.png"
  if [[ ! -f $lock_out || $lock_out -ot $conf ]]; then
    bash "$here/custom/genlock.sh" "$conf" "$name" "$lock_out" >/dev/null 2>&1 || true
  fi
done

echo done
