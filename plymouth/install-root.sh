#!/bin/bash
# Privileged half of apply.sh, run through pkexec.
#
#   addon <addon.efi>  install a stub initrd addon next to the UKI — the fast
#                      path: one file write, no initramfs rebuild. The first
#                      addon install also cleans up a theme baked by the old
#                      rebuild flow (one last rebuild) so the initramfs holds
#                      the stock theme as the permanent fallback.
#   theme <staging>    legacy path for non-UKI systems: bake the theme into
#                      the initramfs and rebuild.
#   stock <stock-dir>  remove the addon and/or the baked theme; only rebuilds
#                      if something was actually baked in.
set -euo pipefail

mode="${1:?usage: install-root.sh addon <addon.efi> | theme <staging-dir> | stock <stock-dir>}"
src="${2:?missing source}"
bg_hex="${3:-}"   # theme background, so the bootloader matches the splash

# The background lands in a sed expression run as root on limine.conf, so
# refuse anything that is not a plain hex color instead of trying to escape.
if [[ -n $bg_hex && ! ${bg_hex#\#} =~ ^[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$ ]]; then
  echo "Refusing background '$bg_hex': not a hex color" >&2
  exit 1
fi

theme_root=/usr/share/plymouth/themes
quit_dropin=/etc/systemd/system/plymouth-quit.service.d/omarchy-lock-explorer.conf
limine_conf=/boot/limine.conf
extra_dir=/boot/EFI/Linux/omarchy_linux.efi.extra.d
addon_name=omarchy-lock-explorer.addon.efi
need_rebuild=0

# Paint the Limine screen the same color as the splash so the bootloader ->
# plymouth handoff has no dark flash. Only the two color values are saved and
# restored -- never a whole copy of limine.conf: the rest of the file (hash
# pins, entries) moves on with every kernel update and rebuild, and restoring
# a stale copy brings back a wrong UKI hash.
limine_colors_save=$limine_conf.omarchy-lock-explorer.colors

sync_limine_backdrop() {
  local hex="$1"
  [[ -f $limine_conf ]] || return 0
  # Legacy full-file backup from older versions: keep only its color values.
  if [[ -f $limine_conf.omarchy-lock-explorer.bak && ! -f $limine_colors_save ]]; then
    grep -E "^[[:space:]]*(backdrop|term_background):" "$limine_conf.omarchy-lock-explorer.bak" > "$limine_colors_save" || true
  fi
  rm -f "$limine_conf.omarchy-lock-explorer.bak"
  [[ -f $limine_colors_save ]] || \
    grep -E "^[[:space:]]*(backdrop|term_background):" "$limine_conf" > "$limine_colors_save" || true
  sed -i -E \
    -e "s/^([[:space:]]*backdrop:[[:space:]]*).*/\\1$hex/" \
    -e "s/^([[:space:]]*term_background:[[:space:]]*).*/\\1$hex/" \
    "$limine_conf"
}
restore_limine_backdrop() {
  if [[ -f $limine_conf.omarchy-lock-explorer.bak && ! -f $limine_colors_save ]]; then
    grep -E "^[[:space:]]*(backdrop|term_background):" "$limine_conf.omarchy-lock-explorer.bak" > "$limine_colors_save" || true
  fi
  rm -f "$limine_conf.omarchy-lock-explorer.bak"
  [[ -f $limine_colors_save && -f $limine_conf ]] || { rm -f "$limine_colors_save"; return 0; }
  local backdrop term_bg
  backdrop=$(awk -F: '/^[[:space:]]*backdrop:/ {gsub(/[[:space:]]/,"",$2); print $2; exit}' "$limine_colors_save")
  term_bg=$(awk -F: '/^[[:space:]]*term_background:/ {gsub(/[[:space:]]/,"",$2); print $2; exit}' "$limine_colors_save")
  # Same rule as on install: only plain hex colors go into the sed below.
  [[ $backdrop =~ ^#?[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$ ]] || backdrop=""
  [[ $term_bg =~ ^#?[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$ ]] || term_bg=""
  [[ -n $backdrop ]] && sed -i -E "s/^([[:space:]]*backdrop:[[:space:]]*).*/\\1$backdrop/" "$limine_conf"
  [[ -n $term_bg ]] && sed -i -E "s/^([[:space:]]*term_background:[[:space:]]*).*/\\1$term_bg/" "$limine_conf"
  rm -f "$limine_colors_save"
}

# Keep the last frame on screen until the compositor's first frame takes
# over, instead of dropping to black between plymouth and the session.
install_quit_dropin() {
  mkdir -p "$(dirname "$quit_dropin")"
  printf '[Service]\nExecStart=\nExecStart=-/usr/bin/plymouth quit --retain-splash\n' > "$quit_dropin"
  systemctl daemon-reload
}

case $mode in
  addon)
    [[ -f $src ]] || { echo "Not an addon file: $src" >&2; exit 1; }
    install -Dm644 "$src" "$extra_dir/$addon_name"
    rm -f "$extra_dir/lock-explorer.addon.efi"   # pre-release test name
    install_quit_dropin
    [[ -n $bg_hex ]] && sync_limine_backdrop "${bg_hex#\#}"
    # One-time cleanup after the old rebuild flow: the addon carries the theme
    # now, so the initramfs goes back to the stock theme as the permanent
    # fallback (and stays there through kernel updates).
    if [[ -d $theme_root/omarchy-boot && -d $theme_root/omarchy ]]; then
      plymouth-set-default-theme omarchy
      rm -rf "$theme_root/omarchy-boot"
      need_rebuild=1
    fi
    ;;
  theme)
    [[ -f $src/omarchy-boot.plymouth ]] || { echo "Not a staged boot theme: $src" >&2; exit 1; }
    rm -rf "$theme_root/omarchy-boot"
    mkdir -p "$theme_root/omarchy-boot"
    cp -r --no-preserve=mode,ownership "$src/." "$theme_root/omarchy-boot/"
    chmod -R a+rX "$theme_root/omarchy-boot"
    plymouth-set-default-theme omarchy-boot
    install_quit_dropin
    [[ -n $bg_hex ]] && sync_limine_backdrop "${bg_hex#\#}"
    need_rebuild=1
    ;;
  stock)
    [[ -f $src/omarchy.plymouth ]] || { echo "Not the stock plymouth theme: $src" >&2; exit 1; }
    rm -f "$extra_dir/$addon_name" "$extra_dir/lock-explorer.addon.efi"
    rmdir "$extra_dir" 2>/dev/null || true
    mkdir -p "$theme_root/omarchy"
    cp -r --no-preserve=mode,ownership "$src/." "$theme_root/omarchy/"
    chmod -R a+rX "$theme_root/omarchy"
    plymouth-set-default-theme omarchy
    # Only rebuild when a theme was actually baked in by the old flow;
    # removing the addon alone restores stock instantly.
    if [[ -d $theme_root/omarchy-boot ]]; then
      rm -rf "$theme_root/omarchy-boot"
      need_rebuild=1
    fi
    rm -f "$quit_dropin"
    systemctl daemon-reload
    restore_limine_backdrop
    ;;
  *)
    echo "Unknown mode: $mode" >&2
    exit 1
    ;;
esac

if [[ $need_rebuild == 1 ]]; then
  if command -v limine-mkinitcpio >/dev/null 2>&1; then
    limine-mkinitcpio
  else
    mkinitcpio -P
  fi
fi
