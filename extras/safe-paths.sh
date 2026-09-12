#!/bin/bash
# Shared by every script in this plugin that writes a file the user owns:
# design copies, imported clips, boot previews, the launcher and menu entries.
# Source it, then use safe_dir and put_file instead of mkdir -p, cp and `>`.
#
# The rules, in one place:
#   - a target lives under $HOME, and every directory from $HOME down to it is
#     a real directory (never a symlink) that the calling user owns and that
#     no one else can write to; a missing one is created, anything else stops
#     the script before it writes;
#   - a file is replaced by writing a temporary file inside the target
#     directory and renaming it into place, both relative to a descriptor held
#     open on that directory, so a link swapped in after the check cannot
#     redirect the write;
#   - a symlink sitting where our file should be is refused, never followed.
#
# The walk itself lives in safe-paths.py, because holding a directory open and
# working relative to it needs openat/renameat, which bash has no way to call.
# Checking a pathname and then reopening it by name -- what this file used to
# do with `cd -P` -- leaves the checked directory and the written-to directory
# two different lookups, with room to swap a component in between.

_safe_paths_py="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/safe-paths.py"

fail() { echo "${0##*/}: $*" >&2; exit 1; }

# Fail closed rather than fall back to a path-based walk: python3 is already
# required elsewhere in the plugin (plymouth/cliptwin.sh reads the monitor
# list with it), so a missing one is a broken system, not a supported mode.
_safe_paths() {
  command -v python3 >/dev/null 2>&1 ||
    fail "python3 is required to write files safely and was not found"
  [[ -f $_safe_paths_py ]] || fail "missing helper: $_safe_paths_py"
  python3 "$_safe_paths_py" "$@"
}

# safe_dir DIR: ensure DIR exists under $HOME through a chain we own.
safe_dir() {
  _safe_paths dir "$1" || fail "unsafe directory: $1"
}

# put_file DIR NAME [MODE]: replace DIR/NAME with stdin, atomically, relative
# to a descriptor held on DIR. NAME is a bare file name, never a path.
put_file() {
  _safe_paths put "$1" "$2" "${3:-0644}" || fail "could not write $1/$2"
}

# drop_file DIR NAME: remove DIR/NAME when it is our plain file; a symlink in
# its place is left alone, and a directory we do not own is not entered.
drop_file() {
  _safe_paths drop "$1" "$2" || true
}
