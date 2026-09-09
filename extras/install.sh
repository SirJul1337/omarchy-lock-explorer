#!/bin/bash
# App launcher entry, icon and Omarchy menu entry (Style -> Lock Screen) for the
# explorer. A plugin cannot run anything when it is installed, so these are
# opt-in: the Settings tab's "Omarchy menu" row and `omarchy-shell lock
# setMenuEntry on` both come through here.
#   install.sh            add them
#   install.sh --remove   take them out again
#   install.sh --status   print "installed" or "missing"
set -e
here=$(cd "$(dirname "$0")" && pwd)
apps=$HOME/.local/share/applications
icons=$HOME/.local/share/icons/hicolor/scalable/apps
menu=$HOME/.config/omarchy/extensions/omarchy-menu.jsonc
key='"style.lockscreen"'

present() {
  [[ -f $apps/lock-screen-explorer.desktop && -f $menu ]] && grep -q "$key" "$menu"
}

refresh() {
  update-desktop-database "$apps" 2>/dev/null || true
  gtk-update-icon-cache -q "$HOME/.local/share/icons/hicolor" 2>/dev/null || true
  # Omarchy 4 re-reads the JSONC on request; older releases parse it on open.
  omarchy-menu refresh >/dev/null 2>&1 || true
}

case "${1:-}" in
  --status)
    if present; then echo installed; else echo missing; fi
    exit 0
    ;;
  --remove)
    rm -f "$apps/lock-screen-explorer.desktop" "$icons/lock-screen-explorer.svg"
    if [[ -f $menu ]] && grep -q "$key" "$menu"; then
      # Drop our line only; the rest of the file is the user's. The last entry
      # left before the closing brace loses its trailing comma.
      tmp=$(mktemp)
      awk -v k="$key" '
        { if (index($0, k) == 0) out[++n] = $0 }
        END {
          last = n; while (last > 0 && out[last] !~ /}/) last--
          prev = last - 1
          while (prev > 0 && (out[prev] ~ /^[[:space:]]*$/ || out[prev] ~ /^[[:space:]]*\/\//)) prev--
          if (prev > 0) sub(/,[[:space:]]*$/, "", out[prev])
          for (i = 1; i <= n; i++) print out[i]
        }' "$menu" > "$tmp" && mv "$tmp" "$menu"
    fi
    refresh
    echo "removed the launcher and Omarchy menu entries"
    exit 0
    ;;
  "") ;;
  *) echo "usage: install.sh [--remove|--status]" >&2; exit 2 ;;
esac

mkdir -p "$apps" "$icons"
cp "$here/lock-screen-explorer.desktop" "$apps/"
cp "$here/lock-screen-explorer.svg" "$icons/"

if [[ -f $menu ]] && grep -q "$key" "$menu"; then
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

refresh
echo "done. Open it from the app launcher (Lock Screen Explorer) or the Omarchy menu under Style."
