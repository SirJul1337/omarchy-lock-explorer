#!/bin/bash
# App launcher entry, icon and Omarchy menu entry (Style -> Lock Screen) for the
# explorer. A plugin cannot run anything when it is installed, so these are
# opt-in: the Settings tab's "Omarchy menu" row and `omarchy-shell lock
# setMenuEntry on` both come through here.
#   install.sh            add them
#   install.sh --remove   take them out again
#   install.sh --status   print "installed" or "missing"
#
# Everything written lands under $HOME through safe-paths.sh: an owner-checked
# directory chain with no symlinks, and atomic replacement from inside the
# target directory. A symlink sitting where one of our files should be is
# refused, never followed.
set -e
here=$(cd "$(dirname "$0")" && pwd)
apps=$HOME/.local/share/applications
icons=$HOME/.local/share/icons/hicolor/scalable/apps
extensions=$HOME/.config/omarchy/extensions
menu_name=omarchy-menu.jsonc
key='"style.lockscreen"'

# shellcheck source=extras/safe-paths.sh
source "$here/safe-paths.sh"

present() {
  [[ -f $apps/lock-screen-explorer.desktop && ! -L $apps/lock-screen-explorer.desktop ]] || return 1
  [[ -f $extensions/$menu_name && ! -L $extensions/$menu_name ]] || return 1
  grep -q "$key" "$extensions/$menu_name"
}

refresh() {
  update-desktop-database "$apps" 2>/dev/null || true
  gtk-update-icon-cache -q "$HOME/.local/share/icons/hicolor" 2>/dev/null || true
  # Omarchy 4 re-reads the JSONC on request; older releases parse it on open.
  omarchy-menu refresh >/dev/null 2>&1 || true
}

# The menu file is read only when it is a plain file of ours.
read_menu() {
  local file=$extensions/$menu_name
  [[ -e $file ]] || { printf '{\n}\n'; return 0; }
  [[ -f $file && ! -L $file && -O $file ]] || fail "refusing to edit $file: not a plain file we own"
  cat -- "$file"
}

case "${1:-}" in
  --status)
    if present; then echo installed; else echo missing; fi
    exit 0
    ;;
  --remove)
    drop_file "$apps" lock-screen-explorer.desktop
    drop_file "$icons" lock-screen-explorer.svg
    if [[ -e $extensions/$menu_name ]] && read_menu | grep -q "$key"; then
      # Drop our line only; the rest of the file is the user's. The last entry
      # left before the closing brace loses its trailing comma.
      read_menu | awk -v k="$key" '
        { if (index($0, k) == 0) out[++n] = $0 }
        END {
          last = n; while (last > 0 && out[last] !~ /}/) last--
          prev = last - 1
          while (prev > 0 && (out[prev] ~ /^[[:space:]]*$/ || out[prev] ~ /^[[:space:]]*\/\//)) prev--
          if (prev > 0) sub(/,[[:space:]]*$/, "", out[prev])
          for (i = 1; i <= n; i++) print out[i]
        }' | put_file "$extensions" "$menu_name"
    fi
    refresh
    echo "removed the launcher and Omarchy menu entries"
    exit 0
    ;;
  "") ;;
  *) echo "usage: install.sh [--remove|--status]" >&2; exit 2 ;;
esac

put_file "$apps" lock-screen-explorer.desktop < "$here/lock-screen-explorer.desktop"
put_file "$icons" lock-screen-explorer.svg < "$here/lock-screen-explorer.svg"

if [[ -e $extensions/$menu_name ]] && read_menu | grep -q "$key"; then
  echo "menu entry already present"
else
  # insert before the final closing brace
  entry='  "style.lockscreen": {"icon":"󰌾","label":"Lock Screen","aliases":["lockscreen","lock-screen"],"description":"Preview and choose a lock screen design","action":"omarchy-shell lock explore"}'
  read_menu | awk -v e="$entry" '
    { lines[NR]=$0 }
    END {
      last=NR; while (last>0 && lines[last] !~ /}/) last--
      prev=last-1; while (prev>0 && (lines[prev] ~ /^[[:space:]]*$/ || lines[prev] ~ /^[[:space:]]*\/\//)) prev--
      if (prev>0 && lines[prev] !~ /[{,][[:space:]]*$/) lines[prev]=lines[prev] ","
      for (i=1;i<last;i++) print lines[i]
      print e
      for (i=last;i<=NR;i++) print lines[i]
    }' | put_file "$extensions" "$menu_name"
  echo "added Style -> Lock Screen to the Omarchy menu"
fi

refresh
echo "done. Open it from the app launcher (Lock Screen Explorer) or the Omarchy menu under Style."
