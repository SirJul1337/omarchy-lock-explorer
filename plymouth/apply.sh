#!/bin/bash
# Apply a lock design's boot screen twin as the Plymouth theme used for the
# LUKS decrypt prompt (and the rest of the boot splash).
#
#   apply.sh <design>              generate + install (instant, see below)
#   apply.sh stock                 restore the stock Omarchy boot theme
#   apply.sh <design> --stage-only generate only, print the staging dir
#                                  (handy for testing in a VM, no root needed)
#
# On Omarchy's UKI boot (Limine -> systemd-stub) the theme ships as a stub
# initrd ADDON on the ESP — omarchy_linux*.efi.extra.d/*.addon.efi — which the
# stub concatenates after the baked-in initrd, so later cpio entries win and
# the theme applies with NO initramfs rebuild (proven on real hardware
# 2026-08-24, see extras/no-rebuild-boot-theme.md). Systems without a UKI
# or the addon stub fall back to the old bake-and-rebuild path; whether a
# UKI is there is decided on the root side (see addon_capable).
#
# The privileged part (one file write to the ESP, or the legacy install +
# rebuild) runs through a single pkexec call, so the shell UI gets one polkit
# dialog. On success the applied design id is recorded in
# ~/.local/state/omarchy/lock-explorer-boot for the explorer to read.
set -euo pipefail
here="$(dirname "$(realpath "$0")")"

# Limine's entry tool names every kernel's UKI after its package, so there is
# no single fixed filename: omarchy_linux.efi for `linux`, omarchy_linux-t2.efi
# on T2 Macs, and omarchy_linux-omarchy.efi since Omarchy 4.0.4 moved to the
# linux-omarchy kernel. That update leaves the old kernel installed as a
# fallback, so omarchy_linux.efi is still on the ESP while the machine boots a
# different image: matching only that name parked the addon next to a UKI
# nothing boots and the boot screen silently stopped changing (issue #33).
# Every Omarchy UKI gets the addon instead, which also matches the legacy
# bake-and-rebuild path — limine-mkinitcpio with no argument rebuilds every
# kernel — so the boot screen is the same whichever entry is picked.
addon_stub=/usr/lib/systemd/boot/efi/addonx64.efi.stub

# Whether there is a UKI to attach to is for the root side to say. /boot is
# commonly mounted root-only (fmask/dmask=0077), and this script runs as the
# user: a find on /boot/EFI/Linux from here then sees nothing, which used to
# pass for "no UKI" and quietly took the bake-and-rebuild path instead, while
# the shell went on reporting the design as applied (issue #59). So with the
# stub installed the theme always goes over in addon mode, and install-root.sh
# builds the addon and attaches it next to every UKI it finds, baking the
# theme in only when there is none. Root builds the addon itself, from the
# theme it has checked (see root-theme.sh): an addon's initrd is laid over
# the boot image's own, so this side never hands one over.
addon_capable() { [[ -f $addon_stub ]]; }

# A theme crosses to the privileged side as one tar file on stdin, never as a
# path or a directory for root to open: root copies the bytes into a place of
# its own before it reads them (see install-root.sh), so nothing in here can
# be swapped underneath it. Prints the tar's path.
pack_theme() {
  local dir="$1" tar
  tar=$(mktemp --suffix=.tar)
  tar -C "$dir" -cf "$tar" --owner=0 --group=0 .
  echo "$tar"
}

target="${1:?usage: apply.sh <design|stock> [--stage-only]}"
stage_only="${2:-}"

# The target names a generator directory or a file under one of the plugin's
# folders, and is written into the generated script and the state file: it
# comes from the shell's saved settings, so it is held to a name pattern
# rather than trusted. No path separators, no leading dot.
case $target in
  custom:* | video:* | snapshot:*)
    [[ ${target#*:} =~ ^[A-Za-z0-9_-][A-Za-z0-9._\ -]{0,127}$ ]] ;;
  *) [[ $target =~ ^[a-z0-9-]{1,32}$ ]] ;;
esac || { echo "Refusing boot screen target: $target" >&2; exit 1; }

state_dir="$HOME/.local/state/omarchy"
state_file="$state_dir/lock-explorer-boot"
mkdir -p "$state_dir"

if [[ $target == stock ]]; then
  stock_dir="${OMARCHY_PATH:-$HOME/.local/share/omarchy}/default/plymouth"
  if [[ ! -f $stock_dir/omarchy.plymouth ]]; then
    echo "Cannot find the stock Omarchy plymouth theme at $stock_dir" >&2
    exit 1
  fi
  stock_tar=$(pack_theme "$stock_dir")
  trap 'rm -f "$stock_tar"' EXIT
  pkexec bash "$here/install-root.sh" stock < "$stock_tar"
  echo stock > "$state_file"
  rm -f "$state_dir/lock-explorer-boot-preview.png"
  echo "Restored the stock boot screen."
  exit 0
fi

staging=$(mktemp -d)

case $target in
  video:*)
    # A clip of the user's own from ~/.config/omarchy/lock-videos.
    bash "$here/cliptwin.sh" "$staging" "$target" "${target#video:}"
    ;;
  custom:*)
    # A layout made in the explorer's boot editor.
    bash "$here/custom/generate.sh" "$staging" \
      "$HOME/.config/omarchy/boot-designs/${target#custom:}.conf" "$target"
    ;;
  snapshot:*)
    # A full-screen snapshot of a lock design (grabbed by the explorer),
    # used as the boot background with a passphrase field on top.
    snap="$HOME/.local/state/omarchy/lock-explorer-snapshots/${target#snapshot:}.png"
    [[ -f $snap ]] || { echo "No snapshot for ${target#snapshot:}" >&2; exit 1; }
    # The box-free companion grab (see the explorer's snapshot flow): shown
    # whenever no prompt is up. Trusted only when newer than the snapshot
    # itself -- an older file is a leftover from a previous grab.
    plain="$HOME/.local/state/omarchy/lock-explorer-snapshots/${target#snapshot:}-plain.png"
    [[ -f $plain && $plain -nt $snap ]] || plain=""
    tmpconf=$(mktemp)
    if [[ -n ${SNAPSHOT_ENTRY:-} ]]; then
      # The design's own input box is in the snapshot; put the bullets inside
      # its text area instead of drawing a pill.
      # SNAPSHOT_ENTRY = "cx,cy,w,h,align" (percent, align left|center|right).
      IFS=, read -r ex ey ew eh ea <<< "$SNAPSHOT_ENTRY"
      # The fields become layout values; layout_val holds them to its
      # patterns again, but a malformed rect is dropped here as a whole.
      num='^-?[0-9]{1,4}(\.[0-9]{1,3})?$'
      [[ $ex =~ $num && $ey =~ $num && $ew =~ $num && $eh =~ $num && ${ea:-center} =~ ^(left|center|right)$ ]] ||
        { echo "Refusing SNAPSHOT_ENTRY: $SNAPSHOT_ENTRY" >&2; exit 1; }
      printf 'background = %s\nbackground_plain = %s\nlogo = none\ntitle =\nsubtitle =\nclock = off\nentry = embedded\nentry_x = %s\nentry_y = %s\nentry_wp = %s\nentry_hp = %s\nentry_align = %s\nhint =\n' \
        "$snap" "$plain" "$ex" "$ey" "$ew" "$eh" "${ea:-center}" > "$tmpconf"
    else
      printf 'background = %s\nbackground_plain = %s\nlogo = none\ntitle =\nsubtitle =\nclock = off\nentry = pill\nentry_y = 82\nhint =\n' "$snap" "$plain" > "$tmpconf"
    fi
    bash "$here/custom/generate.sh" "$staging" "$tmpconf" "$target"
    rm -f "$tmpconf"
    ;;
  *)
    generator="$here/$target/generate.sh"
    if [[ ! -f $generator ]]; then
      echo "No boot screen twin for design '$target'" >&2
      exit 1
    fi
    bash "$generator" "$staging"
    ;;
esac

if [[ $stage_only == --stage-only ]]; then
  echo "$staging"
  exit 0
fi

# The theme background, so the bootloader screen matches the splash color.
# Anything that is not a plain hex color is dropped: the value crosses the
# pkexec boundary into a root sed on limine.conf, so it must never carry
# sed syntax.
theme_bg=$(awk -F= '/^[[:space:]]*background[[:space:]]*=/ {v=$2; gsub(/[[:space:]"]/,"",v); sub(/^#/,"",v); print v; exit}' \
  "$HOME/.local/state/omarchy/current/theme/colors.toml" 2>/dev/null || true)
[[ $theme_bg =~ ^[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$ ]] || theme_bg=""

theme_tar=$(pack_theme "$staging")
trap 'rm -rf "$staging" "$theme_tar"' EXIT
if addon_capable; then
  pkexec bash "$here/install-root.sh" addon "$theme_bg" < "$theme_tar"
else
  pkexec bash "$here/install-root.sh" theme "$theme_bg" < "$theme_tar"
fi
# Record which Omarchy theme the colors were baked from, so the shell can
# offer to regenerate when the theme changes.
# One line in the state file the shell reads back: held to a name pattern.
theme_name=$(f="$HOME/.local/state/omarchy/current/theme.name"; [[ -f $f && ! -L $f ]] && head -c 128 -- "$f" | head -n 1) || true
[[ $theme_name =~ ^[A-Za-z0-9._-]{1,64}$ && $theme_name != *..* ]] || theme_name=unknown
echo "$target $theme_name" > "$state_file"
[[ -f $staging/preview.png ]] && cp "$staging/preview.png" "$state_dir/lock-explorer-boot-preview.png"
echo "Boot screen set to $target."
