#!/bin/bash
# The lock in the bar: a custom QML module in the bar layout of
# ~/.config/omarchy/shell.json that loads this plugin's BarWidget.qml, edited
# the way `omarchy bar` edits the layout. A plugin cannot add a widget to the
# bar when it is installed, so it is opt-in: the Settings tab's "Bar icon" row
# and `omarchy-shell lock setBarIcon on` both come through here.
#   bar-icon.sh            put it on the bar, at the end of the right section
#   bar-icon.sh --remove   take it off again
#   bar-icon.sh --status   print "installed" or "missing"
#
# The file is written through safe-paths.sh: an owner-checked directory chain
# with no symlinks, and atomic replacement from inside the target directory.
set -e
here=$(cd "$(dirname "$0")" && pwd)
plugin=$(cd "$here/.." && pwd)
config_dir=$HOME/.config/omarchy
config=$config_dir/shell.json
defaults=${OMARCHY_PATH:-/usr/share/omarchy}/config/omarchy/shell.json
id=lock-explorer

# shellcheck source=extras/safe-paths.sh
source "$here/safe-paths.sh"

command -v jq >/dev/null 2>&1 || fail "jq is not installed"

# Where the bar finds the widget. Under $HOME it is written with ~, the way
# the bar's own docs show a module source, so the file still reads right if
# the home directory moves.
case $plugin in
  "$HOME"/*) widget="~${plugin#"$HOME"}/BarWidget.qml" ;;
  *) widget="$plugin/BarWidget.qml" ;;
esac

# The user's file when there is one, else the defaults the shell runs on
# without it: the shell has no deep merge, so the first customization has
# to carry the whole layout, which is what `omarchy bar position` does too.
read_config() {
  if [[ -s $config ]]; then
    [[ -f $config && ! -L $config && -O $config ]] || fail "refusing to edit $config: not a plain file we own"
    cat -- "$config"
  elif [[ -f $defaults ]]; then
    cat -- "$defaults"
  else
    echo '{}'
  fi
}

# Every edit goes through the same shape the shell's own tools give the file.
normalize='
  def object_or_empty: if type == "object" then . else {} end;
  def array_or_empty: if type == "array" then . else [] end;
  object_or_empty
  | .version = 1
  | .bar = (.bar | object_or_empty)
  | .bar.layout = (.bar.layout | object_or_empty)
  | .bar.layout.left = (.bar.layout.left | array_or_empty)
  | .bar.layout.center = (.bar.layout.center | array_or_empty)
  | .bar.layout.right = (.bar.layout.right | array_or_empty)
  | .plugins = (.plugins | array_or_empty)
'
without='del(.bar.layout[][] | select(type == "object" and .id == $id))'

present() {
  read_config | jq -e --arg id "$id" \
    '[.bar.layout // {} | .[]? | .[]? | select(type == "object" and .id == $id)] | length > 0' >/dev/null 2>&1
}

write_config() {
  local next
  next=$(read_config | jq -S --arg id "$id" --arg src "$widget" "$normalize | $1") || fail "could not update $config"
  safe_dir "$config_dir"
  printf '%s\n' "$next" | put_file "$config_dir" shell.json
  # The shell keeps the config it read in memory; ask it to read again.
  omarchy-shell shell reloadConfig >/dev/null 2>&1 || omarchy-shell -q shell rescanPlugins >/dev/null 2>&1 || true
}

case "${1:-}" in
  --status)
    if present; then echo installed; else echo missing; fi
    exit 0
    ;;
  --remove)
    if present; then write_config "$without"; fi
    echo "The lock is off the bar"
    ;;
  "")
    write_config "$without | .bar.layout.right += [{ id: \$id, type: \"qml\", source: \$src }]"
    echo "The lock is on the bar"
    ;;
  *)
    echo "usage: bar-icon.sh [--remove | --status]" >&2
    exit 2
    ;;
esac
