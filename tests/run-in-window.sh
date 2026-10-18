#!/bin/bash
# Run one lock screen design in a normal window, without locking anything.
#
#   tests/run-in-window.sh list                  # print the design ids and names
#   tests/run-in-window.sh terminator
#   BENCH_SIZE=1920x1080 BENCH_WALLPAPER=~/Pictures/Wallpapers/x.jpg tests/run-in-window.sh lightspeed
#
# It uses the same harness as the benchmark (tests/bench/shell.qml). Close the
# window or press Ctrl+C to stop. A tiling compositor may ignore BENCH_SIZE and
# tile the window instead. Only designs enabled in Designs.js load.
set -uo pipefail
cd "$(dirname "$(realpath "$0")")/.." || exit 1
root=$PWD

id=${1:-}
[[ -n $id ]] || { echo "usage: tests/run-in-window.sh <design-id | list>" >&2; exit 1; }

# The enabled designs from Designs.js, as "id  name".
if [[ $id == list ]]; then
  grep -oP '^\s*\{ id: "\K[^"]+", file: "[^"]+", name: "[^"]+' Designs.js \
    | sed -E 's/", file: "[^"]+", name: "/\t/' | column -t -s $'\t'
  exit 0
fi

SHELL_DIR=${BENCH_SHELL_DIR:-/usr/share/omarchy/shell}
command -v quickshell >/dev/null || { echo "quickshell not found" >&2; exit 1; }
[[ -d $SHELL_DIR/Commons && -d $SHELL_DIR/Ui ]] || { echo "Omarchy shell not found at $SHELL_DIR (set BENCH_SHELL_DIR)" >&2; exit 1; }
[[ -n ${WAYLAND_DISPLAY:-} ]] || { echo "needs a Wayland session" >&2; exit 1; }
grep -qP "^\s*\{ id: \"$id\", file:" Designs.js || { echo "design '$id' is not enabled in Designs.js" >&2; exit 1; }

# A throwaway config: the harness, this plugin as "Lock" and the shell's own
# Commons and Ui, which the designs import as qs.Commons and qs.Ui.
cfg=$(mktemp -d)
trap 'rm -rf "$cfg"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
cp tests/bench/shell.qml "$cfg/shell.qml"
ln -s "$root" "$cfg/Lock"
ln -s "$SHELL_DIR/Commons" "$cfg/Commons"
ln -s "$SHELL_DIR/Ui" "$cfg/Ui"

export BENCH_SIZE=${BENCH_SIZE:-1280x720}
BENCH_DESIGN=$id quickshell -p "$cfg"
