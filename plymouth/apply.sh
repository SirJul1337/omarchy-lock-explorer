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
# initrd ADDON on the ESP — omarchy_linux.efi.extra.d/*.addon.efi — which the
# stub concatenates after the baked-in initrd, so later cpio entries win and
# the theme applies with NO initramfs rebuild (proven on real hardware
# 2026-08-24, see extras/no-rebuild-boot-theme.md). Systems without the UKI
# or the addon stub fall back to the old bake-and-rebuild path.
#
# The privileged part (one file write to the ESP, or the legacy install +
# rebuild) runs through a single pkexec call, so the shell UI gets one polkit
# dialog. On success the applied design id is recorded in
# ~/.local/state/omarchy/lock-explorer-boot for the explorer to read.
set -euo pipefail
here="$(dirname "$(realpath "$0")")"

uki=/boot/EFI/Linux/omarchy_linux.efi
addon_stub=/usr/lib/systemd/boot/efi/addonx64.efi.stub

addon_capable() { [[ -f $uki && -f $addon_stub ]]; }

# Wrap a staged theme as a systemd-stub initrd addon: the theme dir, a
# plymouthd.conf pointing at it, and the mono font under the names the
# initramfs' label-freetype knows. Prints the addon path (in its own tmp dir).
build_addon() {
  local staging="$1" work overlay font vma
  work=$(mktemp -d)
  overlay="$work/overlay"
  install -d "$overlay/usr/share/plymouth/themes/omarchy-boot" \
    "$overlay/etc/plymouth" "$overlay/usr/share/fonts"
  cp -r "$staging/." "$overlay/usr/share/plymouth/themes/omarchy-boot/"
  printf '[Daemon]\nTheme=omarchy-boot\n' > "$overlay/etc/plymouth/plymouthd.conf"
  font=$(fc-match -f %{file} 'JetBrainsMono Nerd Font')
  cp "$font" "$overlay/usr/share/fonts/Plymouth.ttf"
  cp "$font" "$overlay/usr/share/fonts/Plymouth-monospace.ttf"
  (cd "$overlay" && find . -mindepth 1 | cpio -o -H newc -R 0:0 --quiet) > "$work/extra.cpio"
  vma=$(objdump -h "$addon_stub" | awk '$2 ~ /^\./ { end = strtonum("0x"$4) + strtonum("0x"$3) }
    END { printf "0x%x", and(end + 0xfff, compl(0xfff)) }')
  objcopy --add-section .initrd="$work/extra.cpio" --change-section-vma .initrd="$vma" \
    "$addon_stub" "$work/omarchy-lock-explorer.addon.efi"
  echo "$work/omarchy-lock-explorer.addon.efi"
}

target="${1:?usage: apply.sh <design|stock> [--stage-only]}"
stage_only="${2:-}"

state_dir="$HOME/.local/state/omarchy"
state_file="$state_dir/lock-explorer-boot"
mkdir -p "$state_dir"

if [[ $target == stock ]]; then
  stock_dir="${OMARCHY_PATH:-$HOME/.local/share/omarchy}/default/plymouth"
  if [[ ! -f $stock_dir/omarchy.plymouth ]]; then
    echo "Cannot find the stock Omarchy plymouth theme at $stock_dir" >&2
    exit 1
  fi
  pkexec bash "$here/install-root.sh" stock "$stock_dir"
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

# Spool mode: hand the staged theme to the root path unit rotate-setup.sh
# installed, instead of prompting through pkexec. Used by the rotation.
if [[ $stage_only == --spool ]]; then
  spool="$state_dir/lock-explorer-boot-spool"
  rm -rf "$spool"
  mv "$staging" "$spool"
  theme_name=$(cat "$HOME/.local/state/omarchy/current/theme.name" 2>/dev/null || echo unknown)
  echo "$target $theme_name" > "$state_file"
  [[ -f $spool/preview.png ]] && cp "$spool/preview.png" "$state_dir/lock-explorer-boot-preview.png"
  echo "$spool" > "$state_dir/lock-explorer-boot-request"
  echo "Boot screen queued: $target."
  exit 0
fi

# The theme background, so the bootloader screen matches the splash color.
# Anything that is not a plain hex color is dropped: the value crosses the
# pkexec boundary into a root sed on limine.conf, so it must never carry
# sed syntax.
theme_bg=$(awk -F= '/^[[:space:]]*background[[:space:]]*=/ {v=$2; gsub(/[[:space:]"]/,"",v); sub(/^#/,"",v); print v; exit}' \
  "$HOME/.local/state/omarchy/current/theme/colors.toml" 2>/dev/null || true)
[[ $theme_bg =~ ^[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$ ]] || theme_bg=""

trap 'rm -rf "$staging"' EXIT
if addon_capable; then
  addon=$(build_addon "$staging")
  addon_work=$(dirname "$addon")
  trap 'rm -rf "$staging" "$addon_work"' EXIT
  pkexec bash "$here/install-root.sh" addon "$addon" "$theme_bg" "$staging"
else
  pkexec bash "$here/install-root.sh" theme "$staging" "$theme_bg"
fi
# Record which Omarchy theme the colors were baked from, so the shell can
# offer to regenerate when the theme changes.
theme_name=$(cat "$HOME/.local/state/omarchy/current/theme.name" 2>/dev/null || echo unknown)
echo "$target $theme_name" > "$state_file"
[[ -f $staging/preview.png ]] && cp "$staging/preview.png" "$state_dir/lock-explorer-boot-preview.png"
echo "Boot screen set to $target."
