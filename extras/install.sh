#!/bin/bash
# Optional: app launcher entry, icon and Omarchy menu entry for the explorer.
set -e
here=$(cd "$(dirname "$0")" && pwd)

mkdir -p ~/.local/share/applications ~/.local/share/icons/hicolor/scalable/apps
cp "$here/lock-screen-explorer.desktop" ~/.local/share/applications/
cp "$here/lock-screen-explorer.svg" ~/.local/share/icons/hicolor/scalable/apps/
update-desktop-database ~/.local/share/applications 2>/dev/null || true
gtk-update-icon-cache -q ~/.local/share/icons/hicolor 2>/dev/null || true

menu=~/.config/omarchy/extensions/omarchy-menu.jsonc
if [[ -f $menu ]] && grep -q '"style.lockscreen"' "$menu"; then
  echo "menu entry already present"
else
  mkdir -p "$(dirname "$menu")"
  [[ -f $menu ]] || echo '{' > "$menu"
  # insert before the final closing brace
  tmp=$(mktemp)
  entry='  "style.lockscreen": {"icon":"󰌾","label":"Lock Screen","aliases":["lockscreen","lock-screen"],"description":"Preview and choose a lock screen design","action":"omarchy-shell lock explore"}'
  awk -v e="$entry" '
    { lines[NR]=$0 }
    END {
      last=NR; while (last>0 && lines[last] !~ /}/) last--
      prev=last-1; while (prev>0 && (lines[prev] ~ /^[[:space:]]*$/ || lines[prev] ~ /^[[:space:]]*\/\//)) prev--
      if (prev>0 && lines[prev] !~ /[{,][[:space:]]*$/) lines[prev]=lines[prev] ","
      for (i=1;i<last;i++) print lines[i]
      print e
      for (i=last;i<=NR;i++) print lines[i]
    }' "$menu" > "$tmp" && mv "$tmp" "$menu"
  echo "added Style -> Lock Screen to the Omarchy menu"
fi

echo "done. Open it from the app launcher (Lock Screen Explorer) or the Omarchy menu under Style."
