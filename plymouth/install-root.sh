#!/bin/bash
# Privileged half of apply.sh, run through pkexec.
#
#   addon <addon.efi> [bg] [theme.tar]
#                      install a stub initrd addon next to every Omarchy UKI —
#                      the fast path: one small file write per kernel image,
#                      no initramfs rebuild. The staged theme is also copied
#                      to the root fs and made the default: plymouth-reboot
#                      and poweroff run plymouthd from the root, which never
#                      sees the addon, so this copy is what the shutdown
#                      splash shows (same as the rotation helper does). The
#                      addon still overrides whatever a later kernel-update
#                      rebuild bakes in on the way up.
#   theme <theme.tar>  legacy path for non-UKI systems: bake the theme into
#                      the initramfs and rebuild.
#   stock <stock.tar>  remove the addon and/or the baked theme; only rebuilds
#                      if something was actually baked in.
#
# A theme arrives as one tar file made by apply.sh, never as a directory for
# this script to walk: see receive_theme.
set -euo pipefail

mode="${1:?usage: install-root.sh addon <addon.efi> | theme <theme.tar> | stock <stock.tar>}"
src="${2:?missing source}"
bg_hex="${3:-}"   # theme background, so the bootloader matches the splash
theme_tar="${4:-}"   # staged theme, for the root-fs shutdown copy (addon mode)

# The background lands in a sed expression run as root on limine.conf, so
# refuse anything that is not a plain hex color instead of trying to escape.
if [[ -n $bg_hex && ! ${bg_hex#\#} =~ ^[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$ ]]; then
  echo "Refusing background '$bg_hex': not a hex color" >&2
  exit 1
fi

# The account that authenticated to pkexec (or sudo, when testing). Everything
# this script reads from the unprivileged side has to belong to it.
caller_uid=${PKEXEC_UID:-${SUDO_UID:-}}
[[ $caller_uid =~ ^[0-9]+$ && $caller_uid != 0 ]] ||
  { echo "Cannot tell which account asked for this (no PKEXEC_UID)" >&2; exit 1; }

theme_root=/usr/share/plymouth/themes
quit_dropin=/etc/systemd/system/plymouth-quit.service.d/omarchy-lock-explorer.conf
limine_conf=/boot/limine.conf
addon_name=omarchy-lock-explorer.addon.efi
need_rebuild=0

# Each kernel's UKI is named after its package (omarchy_linux.efi for `linux`,
# omarchy_linux-omarchy.efi for the Omarchy kernel that 4.0.4 migrated to,
# omarchy_linux-t2.efi on T2 Macs), and 4.0.4 leaves the replaced kernel
# installed as a fallback. Pinning the old name attached the addon to a UKI
# the machine no longer boots (issue #33), so every Omarchy UKI is covered.
uki_dir=/boot/EFI/Linux
uki_glob='omarchy_linux*.efi'

# The addon directory beside every UKI that is currently installed.
extra_dirs() {
  find "$uki_dir" -maxdepth 1 -name "$uki_glob" -type f -printf '%p.extra.d\n' 2>/dev/null
}

# Every addon directory on the ESP, including ones whose kernel has since been
# removed: a leftover addon there would come back with that kernel.
stale_extra_dirs() {
  find "$uki_dir" -maxdepth 1 -name "$uki_glob.extra.d" -type d 2>/dev/null
}

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
  sed -i -E "s/^([[:space:]]*backdrop:[[:space:]]*).*/\\1$hex/" "$limine_conf"          # sec-ok: hex validated on entry
  sed -i -E "s/^([[:space:]]*term_background:[[:space:]]*).*/\\1$hex/" "$limine_conf"   # sec-ok: hex validated on entry
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
  [[ -n $backdrop ]] && sed -i -E "s/^([[:space:]]*backdrop:[[:space:]]*).*/\\1$backdrop/" "$limine_conf"   # sec-ok: hex validated above
  [[ -n $term_bg ]] && sed -i -E "s/^([[:space:]]*term_background:[[:space:]]*).*/\\1$term_bg/" "$limine_conf"   # sec-ok: hex validated above
  rm -f "$limine_colors_save"
}

# Root reads from the unprivileged side through handles it has already
# checked, never through a path a second time. Between the password dialog
# and the copy, anything running as that account could swap the path for a
# symlink into a root-only directory, and the copies below make their
# contents world-readable.

# open_caller_file <path>: open fd 3 on a regular file owned by the caller.
# Reads then go through /dev/fd/3, the file already open, whatever the path
# turns into afterwards.
open_caller_file() {
  exec 3<"$1" || return 1
  [[ -f /dev/fd/3 && $(stat -L -c %u /dev/fd/3) == "$caller_uid" ]]
}

# A theme never arrives as a directory for root to walk: a caller-owned tree
# can have any part of it swapped for a symlink while it is being read, and
# the copy into $theme_root makes whatever it then reaches world-readable.
# It arrives as one tar file instead, which root opens once, checks as the
# open file it is, and copies in full into a directory of its own before
# looking at a single member. From there on nothing the caller can rename or
# replace is read again. The unpacked tree has to be plain files and
# directories, each with one link, and tar itself leaves out members that
# name a parent directory; anything else refuses the whole theme before any
# of it reaches $theme_root.
max_theme_bytes=$((2 * 1024 * 1024 * 1024))
work=""
cleanup_work() { [[ -n $work ]] && rm -rf "$work"; return 0; }
trap cleanup_work EXIT

# receive_theme <tar path> <marker file>: unpack into $work/theme.
receive_theme() {
  local path="$1" marker="$2"
  work=$(mktemp -d -p /var/tmp omarchy-lock-explorer.XXXXXX)
  exec 4<"$path" || return 1
  [[ -f /dev/fd/4 && $(stat -L -c %u /dev/fd/4) == "$caller_uid" ]] || return 1
  (( $(stat -L -c %s /dev/fd/4) <= max_theme_bytes )) || return 1
  head -c "$max_theme_bytes" /dev/fd/4 > "$work/theme.tar"
  exec 4<&-
  mkdir "$work/theme"
  # Anything tar has to complain about -- a member it had to rename or
  # leave out -- is not a theme apply.sh made, so a word on stderr refuses.
  # Timestamps are not restored, so a clock that moved cannot cause one.
  tar -xmf "$work/theme.tar" -C "$work/theme" --no-same-owner --no-same-permissions \
    --warning=no-timestamp 2>"$work/tar.err" || return 1
  [[ ! -s $work/tar.err ]] || return 1
  rm -f "$work/theme.tar"
  [[ -f $work/theme/$marker && ! -L $work/theme/$marker ]] || return 1
  [[ -z $(find "$work/theme" -mindepth 1 \( \( ! -type f -a ! -type d \) -o \( -type f -a -links +1 \) \) -print -quit) ]]
}

# install_theme <dest> <replace|merge>: the unpacked theme into $theme_root.
install_theme() {
  local dest="$1" how="$2"
  [[ $how == merge ]] || rm -rf "$dest"
  mkdir -p "$dest"
  cp -r --no-preserve=mode,ownership "$work/theme/." "$dest/"
  find "$dest" -type d -exec chmod 0755 {} + -o -type f -exec chmod 0644 {} +
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
    open_caller_file "$src" || { echo "Not an addon file owned by the caller: $src" >&2; exit 1; }
    installed=0
    while IFS= read -r extra_dir; do
      [[ -n $extra_dir ]] || continue
      install -Dm644 /dev/fd/3 "$extra_dir/$addon_name"
      rm -f "$extra_dir/lock-explorer.addon.efi"   # pre-release test name
      installed=1
    done < <(extra_dirs)
    if [[ $installed == 0 ]]; then
      echo "No Omarchy UKI under $uki_dir to attach the boot screen to" >&2
      exit 1
    fi
    install_quit_dropin
    [[ -n $bg_hex ]] && sync_limine_backdrop "${bg_hex#\#}"
    # The shutdown half: plymouth-reboot/poweroff run plymouthd from the root
    # fs, which never sees the addon, so a live copy of the theme goes there
    # too and becomes the default. plymouthd reads it directly -- no rebuild.
    # (This replaces the old reset-to-stock cleanup: the root copy is now
    # refreshed on every apply, so nothing baked can go stale.)
    if [[ -n $theme_tar ]]; then
      receive_theme "$theme_tar" omarchy-boot.plymouth || { echo "Refusing $theme_tar: not a plain theme owned by the caller" >&2; exit 1; }
      install_theme "$theme_root/omarchy-boot" replace
      plymouth-set-default-theme omarchy-boot
    fi
    ;;
  theme)
    receive_theme "$src" omarchy-boot.plymouth || { echo "Refusing $src: not a plain theme owned by the caller" >&2; exit 1; }
    install_theme "$theme_root/omarchy-boot" replace
    plymouth-set-default-theme omarchy-boot
    install_quit_dropin
    [[ -n $bg_hex ]] && sync_limine_backdrop "${bg_hex#\#}"
    need_rebuild=1
    ;;
  stock)
    while IFS= read -r extra_dir; do
      [[ -n $extra_dir ]] || continue
      rm -f "$extra_dir/$addon_name" "$extra_dir/lock-explorer.addon.efi"
      rmdir "$extra_dir" 2>/dev/null || true
    done < <(stale_extra_dirs)
    receive_theme "$src" omarchy.plymouth || { echo "Refusing $src: not the stock theme as a plain tar owned by the caller" >&2; exit 1; }
    install_theme "$theme_root/omarchy" merge
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
