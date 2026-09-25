#!/bin/bash
# Check an install of this plugin and say what to do about anything wrong.
#   doctor.sh           the checks, one line each, with the fix under a failure
#   doctor.sh --fix     the same, then the fixes that are safe to do unasked:
#                       a second copy of the plugin is moved out of the plugins
#                       folder (to ~/.local/share/omarchy/lock-explorer-backups,
#                       never deleted), and Omarchy's own lock is switched back
#                       on when neither lock screen is
#
# Runs on its own, not through the shell: the problem it is most often needed
# for is Omarchy's own lock still answering `omarchy-shell lock`, and then
# nothing this plugin registers can be reached that way. Without --fix it only
# reads; nothing here needs root.
set -uo pipefail

FIX=0
case "${1:-}" in
  --fix) FIX=1 ;;
  "") ;;
  *) echo "usage: doctor.sh [--fix]" >&2; exit 2 ;;
esac
restore_stock=0

ID="io.github.sirjul1337.lock-explorer"
PLUGINS="$HOME/.config/omarchy/plugins"
SHELL_JSON="$HOME/.config/omarchy/shell.json"
HERE="$(cd "$(dirname "$(realpath "$0")")/.." && pwd)"

problems=0
ok() { printf '  \033[32mok\033[0m    %s\n' "$1"; }
warn() { printf '  \033[33mnote\033[0m  %s\n' "$1"; }
fail() {
  problems=$((problems + 1))
  printf '  \033[31mfix\033[0m   %s\n' "$1"
  shift
  local line
  for line in "$@"; do printf '          %s\n' "$line"; done
}

version="unknown"
if command -v jq >/dev/null 2>&1 && [[ -f $HERE/manifest.json ]]; then
  version="$(jq -r '.version // "unknown"' "$HERE/manifest.json" 2>/dev/null)"
fi
echo "Lock Screen Explorer $version ($HERE)"
echo

# --- Which lock is in charge -------------------------------------------------
echo "Lock service"

plugin_state=""
stock_state=""
if command -v omarchy >/dev/null 2>&1; then
  list="$(omarchy plugin list 2>/dev/null || true)"
  plugin_state="$(awk -v id="$ID" '$1 == id { print $2 }' <<<"$list")"
  stock_state="$(awk '$1 == "omarchy.lock" { print $2 }' <<<"$list")"
fi

case "$plugin_state" in
  enabled) ok "the plugin is enabled" ;;
  "") fail "the plugin is not installed where Omarchy looks for it" \
        "omarchy plugin add https://github.com/SirJul1337/omarchy-lock-explorer.git --enable" ;;
  *) fail "the plugin is $plugin_state" "omarchy plugin enable $ID" ;;
esac

stock_disabled=0
if command -v jq >/dev/null 2>&1 && [[ -f $SHELL_JSON ]] \
   && jq -e '(.disabledPlugins // []) | index("omarchy.lock")' "$SHELL_JSON" >/dev/null 2>&1; then
  stock_disabled=1
fi
if [[ $plugin_state != enabled && ( $stock_disabled == 1 || $stock_state == disabled ) ]]; then
  # Omarchy switches its own lock off for this plugin and does not always
  # switch it back on when the plugin is disabled or removed.
  restore_stock=1
  fail "nothing locks the screen: this plugin is not enabled and Omarchy's own lock is switched off"        "Either enable this plugin: omarchy plugin enable $ID"        "or go back to Omarchy's lock: omarchy plugin enable omarchy.lock (--fix does this)"
elif [[ $stock_disabled == 1 || $stock_state == disabled ]]; then
  ok "Omarchy's own lock screen is switched off"
else
  fail "Omarchy's own lock screen is still switched on (${stock_state:-state unknown})" \
       "The shell switches it off when this plugin is enabled. Enable it again, then restart the shell:" \
       "omarchy plugin enable $ID && omarchy restart shell"
fi

answer="$(timeout 5 omarchy-shell lock status 2>&1 || true)"
if [[ $answer == \{* && $answer == *'"wakeGraceMs"'* ]]; then
  ok "omarchy-shell lock is answered by this plugin"
elif [[ $answer == \{* || $answer == *"Function not found"* ]]; then
  fail "omarchy-shell lock is answered by Omarchy's own lock screen, not this plugin" \
       "Restart the shell so it hands the lock over: omarchy restart shell" \
       "If this line is still here afterwards, include this whole report in an issue."
elif [[ $answer == *"Target not found"* ]]; then
  fail "no lock service is loaded at all" \
       "The shell log says why: journalctl --user -b | grep -i lock-explorer" \
       "omarchy plugin validate $HERE"
else
  warn "could not ask the running shell (${answer:-no answer}); is omarchy-shell running?"
fi

others=()
if [[ -d $PLUGINS ]]; then
  while IFS= read -r manifest; do
    dir="$(dirname "$manifest")"
    [[ $(realpath "$dir") == "$(realpath "$HERE")" ]] && continue
    grep -q "\"id\"[[:space:]]*:[[:space:]]*\"$ID\"" "$manifest" 2>/dev/null && others+=("$dir")
  done < <(find "$PLUGINS" -mindepth 2 -maxdepth 2 -name manifest.json 2>/dev/null)
fi
if (( ${#others[@]} == 0 )); then
  ok "no second copy of the plugin under $PLUGINS"
else
  fail "another copy with the same id may load instead of this one:" "${others[@]}" \
       "Move it out of $PLUGINS (a backup belongs anywhere else), then: omarchy restart shell"        "--fix moves it to ${XDG_DATA_HOME:-$HOME/.local/share}/omarchy/lock-explorer-backups"
fi

# --- Packages ----------------------------------------------------------------
echo
echo "Packages"

if pacman -Q qt6-multimedia >/dev/null 2>&1; then
  ok "qt6-multimedia (video designs, clip designs, the unlock clip)"
else
  fail "qt6-multimedia is missing: video designs fall back to Classic" \
       "omarchy pkg add qt6-multimedia && omarchy restart shell"
fi

wallpaper="$(readlink -f "${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/current/background" 2>/dev/null || true)"
if pacman -Q qt6-imageformats >/dev/null 2>&1; then
  ok "qt6-imageformats (WebP wallpapers)"
elif [[ ${wallpaper,,} == *.webp ]]; then
  fail "qt6-imageformats is missing and your wallpaper is WebP: designs show the theme color instead" \
       "omarchy pkg add qt6-imageformats && omarchy restart shell"
else
  warn "qt6-imageformats is not installed; only needed for a WebP wallpaper"
fi

# --- Sign-in -----------------------------------------------------------------
echo
echo "Sign-in"

if [[ -f /etc/pam.d/omarchy-lock-password ]]; then
  ok "password (/etc/pam.d/omarchy-lock-password)"
else
  fail "/etc/pam.d/omarchy-lock-password is missing: the lock screen refuses to lock without it" \
       "It ships with Omarchy; omarchy update puts it back."
fi

if [[ -f /etc/pam.d/omarchy-lock-fido2 ]]; then
  ok "security key (/etc/pam.d/omarchy-lock-fido2)"
else
  warn "no security key service; bash $HERE/extras/setup-fido2.sh adds one after enrolling a key"
fi

if command -v fprintd-list >/dev/null 2>&1; then
  ok "fingerprint reader software is installed"
fi

if (( FIX )); then
  echo
  echo "Fixing"
  fixed=0
  if (( restore_stock )); then
    if omarchy plugin enable omarchy.lock >/dev/null 2>&1; then
      ok "switched Omarchy's own lock screen back on"
      fixed=$((fixed + 1))
    else
      warn "could not switch Omarchy's own lock screen on; run: omarchy plugin enable omarchy.lock"
    fi
  fi
  if (( ${#others[@]} > 0 )); then
    dest="${XDG_DATA_HOME:-$HOME/.local/share}/omarchy/lock-explorer-backups"
    mkdir -p -- "$dest"
    moved=0
    for dir in "${others[@]}"; do
      # Only what the check found: a directory right under the plugins folder.
      [[ $(dirname "$dir") == "$PLUGINS" && -d $dir && ! -L $dir ]] || continue
      name="$(basename "$dir")"
      if [[ -e $dest/$name ]]; then
        warn "left $dir where it is: $dest/$name already exists"
        continue
      fi
      if mv -- "$dir" "$dest/$name"; then
        ok "moved $dir to $dest/"
        moved=$((moved + 1))
      fi
    done
    if (( moved > 0 )); then
      fixed=$((fixed + 1))
      echo "          omarchy restart shell  loads the copy that is left"
    fi
  fi
  problems=$((problems - fixed))
  (( problems < 0 )) && problems=0
fi

echo
if (( problems == 0 )); then
  echo "Nothing to fix."
else
  echo "$problems thing(s) to fix, see above."
fi
exit $(( problems > 0 ? 1 : 0 ))
