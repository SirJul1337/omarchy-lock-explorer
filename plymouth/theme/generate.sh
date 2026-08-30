#!/bin/bash
# "Theme colors" boot screen: the stock Omarchy splash layout (logo, entry,
# progress bar), recolored from the active theme the same way
# omarchy-plymouth-set does, with the theme's unlock.png as the logo. For when
# you want the boot screen themed but not tied to a lock design. Stages the
# theme into the directory given as $1.
set -euo pipefail
source "$(dirname "$(realpath "$0")")/../common.sh"

staging="${1:?usage: generate.sh <staging-dir>}"
mkdir -p "$staging"

stock_dir="${OMARCHY_PATH:-$HOME/.local/share/omarchy}/default/plymouth"
theme_dir="$HOME/.local/state/omarchy/current/theme"

if [[ ! -f $stock_dir/omarchy.script ]]; then
  echo "Cannot find the stock Omarchy plymouth theme at $stock_dir" >&2
  exit 1
fi

bg=$(theme_color background)
fg=$(theme_color foreground)
bg_f=$(hex_floats "$bg")

find "$stock_dir" -maxdepth 1 -type f ! -name '*.plymouth' -exec cp -t "$staging/" {} +
mv "$staging/omarchy.script" "$staging/omarchy-boot.script"

sed -i \
  -e "s/^Window.SetBackgroundTopColor.*/Window.SetBackgroundTopColor($bg_f);/" \
  -e "s/^Window.SetBackgroundBottomColor.*/Window.SetBackgroundBottomColor($bg_f);/" \
  "$staging/omarchy-boot.script"

for asset in bullet.png entry.png lock.png progress_bar.png; do
  [[ -f $staging/$asset ]] && magick "$staging/$asset" -channel RGB +level-colors "#$fg","#$fg" "$staging/$asset"
done

[[ -f $theme_dir/unlock.png ]] && cp "$theme_dir/unlock.png" "$staging/logo.png"

cat > "$staging/omarchy-boot.plymouth" <<EOF
[Plymouth Theme]
Name=Omarchy Boot (Lock Explorer)
Description=The stock Omarchy splash in the active theme's colors.
ModuleName=script

[script]
ImageDir=/usr/share/plymouth/themes/omarchy-boot
ScriptFile=/usr/share/plymouth/themes/omarchy-boot/omarchy-boot.script
ConsoleLogBackgroundColor=0x$bg
Font=Cantarell 11
MonospaceFont=Cantarell 11
EOF
echo theme > "$staging/design"

# Thumbnail for the explorer's boot panel: logo over the background with the
# entry box under it, the same composition the real splash uses.
logo_h=$(magick identify -format '%h' "$staging/logo.png" 2>/dev/null || echo 100)
logo_scaled=$((logo_h > 120 ? 120 : logo_h))
magick -size 720x405 "xc:#$bg" \
  \( "$staging/logo.png" -resize x$logo_scaled \) -gravity center -geometry +0-30 -composite \
  \( "$staging/entry.png" -resize x26 \) -gravity center -geometry +0+60 -composite \
  "$staging/preview.png"
