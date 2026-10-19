#!/bin/bash
# Privileged half of apply.sh, run through pkexec.
#
#   addon [bg]         build a stub initrd addon from the theme and install it
#                      next to every Omarchy UKI -- the fast path: one small
#                      file write per kernel image, no initramfs rebuild. The
#                      theme is also copied to the root fs and made the
#                      default: plymouth-reboot and poweroff run plymouthd
#                      from the root, which never sees the addon, so this
#                      copy is what the shutdown splash shows. The
#                      addon still overrides whatever a later kernel-update
#                      rebuild bakes in on the way up. When no Omarchy UKI
#                      is on the ESP this falls through to the theme path
#                      below: only root can tell, since /boot is commonly
#                      mounted root-only and apply.sh runs as the user.
#   theme [bg]         legacy path for non-UKI systems: bake the theme into
#                      the initramfs and rebuild.
#   stock              remove the addon and/or the baked theme; only rebuilds
#                      if something was actually baked in.
#
# Every mode reads one tar file made by apply.sh on stdin -- the theme, or for
# stock the stock theme -- never a path or a directory: see receive_theme.
# What is in it is checked, and the parts root acts on -- the .plymouth, and
# the addon -- are root's own: see root-theme.sh.
set -euo pipefail
# shellcheck source=plymouth/root-theme.sh
source "$(dirname "$0")/root-theme.sh"

mode="${1:?usage: install-root.sh addon|theme [bg] | stock  (the theme tar on stdin)}"
bg_hex="${2:-}"   # theme background, so the bootloader matches the splash

# The background lands in a sed expression run as root on limine.conf, so
# refuse anything that is not a plain hex color instead of trying to escape.
if [[ -n $bg_hex && ! ${bg_hex#\#} =~ ^[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$ ]]; then
  echo "Refusing background '$bg_hex': not a hex color" >&2
  exit 1
fi

# Only ever run on behalf of an ordinary account through pkexec (or sudo, when
# testing); a direct root run has no caller and is refused.
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

# A theme never arrives as a path or a directory for root to open: a path is
# resolved again after the password dialog, and a caller-owned tree can have
# any part of it swapped for a symlink while it is being read. It arrives as
# one tar file on stdin instead, which root copies, up to a cap, into a
# directory of its own before looking at a single member. The listing is
# checked before anything is unpacked -- only plain files and directories,
# a bounded count and total size -- and the unpacked tree again: plain files
# and directories, each with one link, and tar itself leaves out members
# that name a parent directory. Anything else refuses the whole theme before
# any of it reaches $theme_root.
max_theme_bytes=$((1024 * 1024 * 1024))
max_theme_members=4096
work=""
cleanup_work() { [[ -n $work ]] && rm -rf "$work"; return 0; }
trap cleanup_work EXIT

# receive_theme <marker file>: the tar on stdin, unpacked into $work/theme
# and sealed (seal_theme): root writes the .plymouth, and anything but the
# files a generator makes refuses the theme.
receive_theme() {
  local marker="$1"
  work=$(mktemp -d -p /var/tmp omarchy-lock-explorer.XXXXXX)
  head -c "$((max_theme_bytes + 1))" > "$work/theme.tar"
  (( $(stat -c %s "$work/theme.tar") <= max_theme_bytes )) || return 1
  # tar -tv prints one line per member, type first and size third, with
  # unusual characters in names escaped, so a name cannot add a line.
  LC_ALL=C tar -tvf "$work/theme.tar" 2>"$work/tar.err" > "$work/theme.list" || return 1
  [[ ! -s $work/tar.err ]] || return 1
  awk -v max_bytes="$max_theme_bytes" -v max_members="$max_theme_members" '
    { kind = substr($1, 1, 1); if (kind != "-" && kind != "d") bad = 1; total += $3; n++ }
    END { exit (bad || n > max_members || total > max_bytes) }' "$work/theme.list" || return 1
  mkdir "$work/theme"
  # Anything tar has to complain about -- a member it had to rename or
  # leave out -- is not a theme apply.sh made, so a word on stderr refuses.
  # Timestamps are not restored, so a clock that moved cannot cause one.
  tar -xmf "$work/theme.tar" -C "$work/theme" --no-same-owner --no-same-permissions \
    --warning=no-timestamp 2>"$work/tar.err" || return 1
  [[ ! -s $work/tar.err ]] || return 1
  rm -f "$work/theme.tar" "$work/theme.list"
  [[ -f $work/theme/$marker && ! -L $work/theme/$marker ]] || return 1
  [[ -z $(find "$work/theme" -mindepth 1 \( \( ! -type f -a ! -type d \) -o \( -type f -a -links +1 \) \) -print -quit) ]] || return 1
  seal_theme "$work/theme" "${marker%.plymouth}"
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
    receive_theme omarchy-boot.plymouth || { echo "Refusing the theme: not a boot theme as the plugin makes them" >&2; exit 1; }
    installed=0
    if [[ -n $(extra_dirs) ]]; then
      build_addon "$work/theme" "$work/$addon_name" || { echo "Could not build the boot screen addon" >&2; exit 1; }
      while IFS= read -r extra_dir; do
        [[ -n $extra_dir ]] || continue
        install -Dm644 "$work/$addon_name" "$extra_dir/$addon_name"
        rm -f "$extra_dir/lock-explorer.addon.efi"   # pre-release test name
        installed=1
      done < <(extra_dirs)
    fi
    if [[ $installed == 0 ]]; then
      # Not a UKI boot: bake the theme in and rebuild, as the theme mode does.
      echo "No Omarchy UKI under $uki_dir; baking the boot screen into the initramfs instead" >&2
      need_rebuild=1
    fi
    install_quit_dropin
    [[ -n $bg_hex ]] && sync_limine_backdrop "${bg_hex#\#}"
    # The shutdown half: plymouth-reboot/poweroff run plymouthd from the root
    # fs, which never sees the addon, so a live copy of the theme goes there
    # too and becomes the default. plymouthd reads it directly -- no rebuild.
    install_theme "$theme_root/omarchy-boot" replace
    plymouth-set-default-theme omarchy-boot
    ;;
  theme)
    receive_theme omarchy-boot.plymouth || { echo "Refusing the theme: not a boot theme as the plugin makes them" >&2; exit 1; }
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
    receive_theme omarchy.plymouth || { echo "Refusing the theme: not the stock theme as the plugin packs it" >&2; exit 1; }
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
