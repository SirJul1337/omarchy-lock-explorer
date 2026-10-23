#!/bin/bash
# Rank the lock screen designs by how hard they work the CPU and GPU.
#
# Each design runs alone in a Quickshell window (tests/bench/shell.qml). After
# a warm-up the script samples that process for a while: CPU from
# /proc/<pid>/stat, GPU from the DRM engine time in /proc/<pid>/fdinfo (i915,
# xe and amdgpu report it per process, no root needed). Results print as a
# table, busiest first, and land in a CSV.
#
#   tests/bench-lock-load.sh                    # every design
#   tests/bench-lock-load.sh neon rain card     # just these ids
#   BENCH_SECONDS=20 BENCH_SIZE=2560x1440 tests/bench-lock-load.sh
#   BENCH_WALLPAPER=~/Pictures/Wallpapers/some.jpg tests/bench-lock-load.sh terminator
#
# It needs a running Wayland session and opens a window per design, one after
# another, so leave the machine alone while it runs. Figures are percent of one
# CPU core (100 = a core fully busy) and percent of one GPU engine.
set -uo pipefail
cd "$(dirname "$(realpath "$0")")/.." || exit 1
root=$PWD

WARMUP=${BENCH_WARMUP:-3}
SECONDS_PER=${BENCH_SECONDS:-10}
export BENCH_SIZE=${BENCH_SIZE:-1920x1080}
SHELL_DIR=${BENCH_SHELL_DIR:-/usr/share/omarchy/shell}
OUT=${BENCH_OUT:-${XDG_CACHE_HOME:-$HOME/.cache}/omarchy-lock-explorer/bench-$(date +%Y%m%d-%H%M%S).csv}

command -v quickshell >/dev/null || { echo "quickshell not found" >&2; exit 1; }
[[ -d $SHELL_DIR/Commons && -d $SHELL_DIR/Ui ]] || { echo "Omarchy shell not found at $SHELL_DIR (set BENCH_SHELL_DIR)" >&2; exit 1; }
[[ -n ${WAYLAND_DISPLAY:-} ]] || { echo "needs a Wayland session" >&2; exit 1; }

# Design ids from Designs.js, unless some were named.
if (( $# > 0 )); then
  ids=("$@")
else
  mapfile -t ids < <(grep -oP '^\s*\{ id: "\K[^"]+(?=", file:)' Designs.js)
fi

# A throwaway config: the harness, this plugin as "Lock" and the shell's own
# Commons and Ui, which the designs import as qs.Commons and qs.Ui.
cfg=$(mktemp -d)
trap 'rm -rf "$cfg"; [[ -n ${qs_pid:-} ]] && kill "$qs_pid" 2>/dev/null' EXIT
cp tests/bench/shell.qml "$cfg/shell.qml"
ln -s "$root" "$cfg/Lock"
ln -s "$SHELL_DIR/Commons" "$cfg/Commons"
ln -s "$SHELL_DIR/Ui" "$cfg/Ui"
mkdir -p "$(dirname "$OUT")"

ticks=$(getconf CLK_TCK)
cpu_ticks() { awk '{print $14 + $15}' "/proc/$1/stat" 2>/dev/null; }
# Total GPU engine nanoseconds across this process's DRM clients, each client
# counted once (several fds can share one).
gpu_ns() {
  local f total=0 seen=" " id
  for f in /proc/$1/fdinfo/*; do
    grep -q '^drm-driver:' "$f" 2>/dev/null || continue
    id=$(awk '/^drm-client-id:/ {print $2}' "$f")
    [[ $seen == *" $id "* ]] && continue
    seen+="$id "
    total=$(( total + $(awk '/^drm-engine-[a-z]+:|^drm-cycles-/ && $1 ~ /engine/ {s += $2} END {print s + 0}' "$f") ))
  done
  echo "$total"
}

echo "design,cpu_pct,gpu_pct,rss_mb" > "$OUT"
printf '%-16s %8s %8s %8s\n' design "cpu%" "gpu%" "rss MB"
for id in "${ids[@]}"; do
  BENCH_DESIGN=$id quickshell -p "$cfg" >"$cfg/$id.log" 2>&1 &
  qs_pid=$!
  sleep "$WARMUP"
  if ! kill -0 "$qs_pid" 2>/dev/null; then
    printf '%-16s %s\n' "$id" "failed to start (see $cfg/$id.log)"; qs_pid=; continue
  fi
  if grep -q "failed to load design" "$cfg/$id.log"; then
    printf '%-16s %s\n' "$id" "design failed to load (see $cfg/$id.log)"
    kill "$qs_pid" 2>/dev/null; wait "$qs_pid" 2>/dev/null; qs_pid=; continue
  fi
  c0=$(cpu_ticks "$qs_pid"); g0=$(gpu_ns "$qs_pid"); t0=$(date +%s.%N)
  sleep "$SECONDS_PER"
  c1=$(cpu_ticks "$qs_pid"); g1=$(gpu_ns "$qs_pid"); t1=$(date +%s.%N)
  rss=$(awk '/^VmRSS:/ {printf "%d", $2 / 1024}' "/proc/$qs_pid/status" 2>/dev/null)
  kill "$qs_pid" 2>/dev/null; wait "$qs_pid" 2>/dev/null; qs_pid=
  cpu=$(awk -v a="$c0" -v b="$c1" -v t0="$t0" -v t1="$t1" -v hz="$ticks" 'BEGIN {printf "%.1f", (b - a) / hz / (t1 - t0) * 100}')
  gpu=$(awk -v a="$g0" -v b="$g1" -v t0="$t0" -v t1="$t1" 'BEGIN {printf "%.1f", (b - a) / 1e9 / (t1 - t0) * 100}')
  echo "$id,$cpu,$gpu,${rss:-0}" >> "$OUT"
  printf '%-16s %8s %8s %8s\n' "$id" "$cpu" "$gpu" "${rss:-0}"
done

echo
echo "Busiest first (cpu% + gpu%):"
tail -n +2 "$OUT" | awk -F, '{printf "%s,%s,%s,%s,%.1f\n", $1, $2, $3, $4, $2 + $3}' | sort -t, -k5 -nr \
  | awk -F, '{printf "%-16s %8s %8s %8s\n", $1, $2, $3, $4}' | head -15
echo
echo "Full results: $OUT"
