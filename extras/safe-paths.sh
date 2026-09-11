#!/bin/bash
# Shared by every script in this plugin that writes a file the user owns:
# design copies, imported clips, boot previews, the launcher and menu entries.
# Source it, then use safe_dir and put_file instead of mkdir -p, cp and `>`.
#
# The rules, in one place:
#   - a target lives under $HOME, and every directory from $HOME down to it is
#     a real directory (never a symlink) owned by the calling user; a missing
#     one is created, anything else stops the script before it writes;
#   - a file is replaced by writing a temporary file inside the target
#     directory and renaming it into place, with that directory held as the
#     working directory in between, so a link swapped in after the check
#     cannot redirect the write;
#   - a symlink sitting where our file should be is refused, never followed.

fail() { echo "${0##*/}: $*" >&2; exit 1; }

# safe_dir DIR: ensure DIR exists under $HOME through a chain we own.
safe_dir() {
  local target=$1 cur=$HOME rel part parts
  [[ -n $HOME && -d $HOME && ! -L $HOME && -O $HOME ]] || fail "\$HOME is not a directory we own"
  [[ $target == "$HOME"/* ]] || fail "refusing to write outside \$HOME: $target"
  rel=${target#"$HOME"/}
  IFS=/ read -r -a parts <<< "$rel"
  for part in "${parts[@]}"; do
    [[ -n $part && $part != . && $part != .. ]] || fail "bad path component in $target"
    cur=$cur/$part
    [[ ! -L $cur ]] || fail "refusing to go through a symlink: $cur"
    if [[ ! -e $cur ]]; then
      mkdir -m 0755 "$cur" 2>/dev/null || fail "cannot create $cur"
    fi
    [[ -d $cur && ! -L $cur && -O $cur ]] || fail "not a directory we own: $cur"
  done
}

# put_file DIR NAME [MODE]: replace DIR/NAME with stdin, atomically, from
# inside DIR. NAME is a bare file name, never a path.
put_file() {
  local dir=$1 name=$2 mode=${3:-0644}
  [[ $name != */* && $name != . && $name != .. && -n $name ]] || fail "bad file name: $name"
  safe_dir "$dir"
  (
    cd -P -- "$dir" || exit 1
    [[ ! -L ./$name ]] || { echo "${0##*/}: refusing to replace a symlink: $dir/$name" >&2; exit 1; }
    tmp=$(mktemp "./.$name.XXXXXX") || exit 1
    trap 'rm -f -- "$tmp"' EXIT
    cat > "$tmp" && chmod "$mode" "$tmp" && mv -T -- "$tmp" "./$name"
  ) || fail "could not write $dir/$name"
}

# drop_file DIR NAME: remove DIR/NAME when it is our plain file; a symlink in
# its place is left alone, and a directory we do not own is not entered.
drop_file() {
  local dir=$1 name=$2
  [[ $name != */* && -n $name ]] || return 0
  [[ -d $dir && ! -L $dir && -O $dir ]] || return 0
  ( cd -P -- "$dir" && [[ ! -L ./$name ]] && rm -f -- "./$name" ) || true
}
