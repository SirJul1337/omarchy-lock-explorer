#!/bin/bash
# One time root setup for boot screen rotation (run through pkexec): installs
# a systemd path unit that watches the user's request file and applies the
# staged boot theme without a prompt, so the rotation can advance in the
# background after every boot.
#
# Worth knowing: with this installed, your user account can update the boot
# splash and rebuild the boot image without being asked again. On a single
# user machine that is usually fine; remove with `rotate-setup.sh remove`.
#
#   rotate-setup.sh install
#   rotate-setup.sh remove
#
# The home directory is read from the account that authenticated to pkexec,
# never from an argument or from $HOME: this script writes a root-owned helper
# that systemd runs unprompted, so a value that reached the text of that
# helper would be persistent root code execution, and $HOME is settable by
# whatever invoked us.
set -euo pipefail

mode="${1:?usage: rotate-setup.sh install | remove}"
helper=/usr/local/lib/omarchy-lock-explorer-rotate.sh
unit_base=/etc/systemd/system/omarchy-lock-explorer-boot

# The account on whose behalf pkexec (or sudo, when testing) elevated us.
caller_uid=${PKEXEC_UID:-${SUDO_UID:-}}

resolve_home() {
  [[ $caller_uid =~ ^[0-9]+$ ]] ||
    { echo "Cannot tell which account asked for this (no PKEXEC_UID)" >&2; exit 1; }
  [[ $caller_uid != 0 ]] || { echo "Refusing to install a rotation for root" >&2; exit 1; }
  local entry
  entry=$(getent passwd "$caller_uid") ||
    { echo "No account with uid $caller_uid" >&2; exit 1; }
  home=$(printf '%s' "$entry" | cut -d: -f6)
  # Everything below is pasted into a root-owned script and a unit file, so
  # the path is held to a whitelist rather than escaped: anything outside it
  # is refused. A home directory has no business carrying shell or unit syntax.
  [[ $home == /* && $home =~ ^[A-Za-z0-9._/+-]+$ ]] ||
    { echo "Refusing an unusual home directory: $home" >&2; exit 1; }
  [[ -d $home && ! -L $home ]] || { echo "Not a home directory: $home" >&2; exit 1; }
  local owner
  owner=$(stat -c %u "$home")
  [[ $owner == "$caller_uid" ]] ||
    { echo "Home directory is not owned by uid $caller_uid: $home" >&2; exit 1; }
}

case $mode in
  install)
    resolve_home
    state="$home/.local/state/omarchy"
    req="$state/lock-explorer-boot-request"
    # apply.sh --spool always stages here, as one tar file. The helper uses
    # this fixed path and treats the request file purely as a trigger: reading
    # a path out of a file the user can write would let anything running as
    # that user hand root an arbitrary file to unpack into the boot image.
    spool="$state/lock-explorer-boot-spool.tar"

    mkdir -p /usr/local/lib
    cat > "$helper" <<EOF
#!/bin/bash
# Applies the boot theme staged by omarchy-lock-explorer's rotation.
# Installed by rotate-setup.sh; edits here are overwritten on reinstall.
set -euo pipefail
req="$req"
spool="$spool"
owner_uid=$caller_uid
EOF
    cat >> "$helper" <<'EOF'
[[ -f $req ]] || exit 0
rm -f "$req"

# The staged theme is written by an unprivileged account, and root never
# walks a directory of that account's: any part of it could be swapped for a
# symlink while it is being read, and the copy below makes whatever it then
# reaches world-readable. The theme is one tar file instead, opened once,
# checked as the open file it is, and copied in full into a directory of
# root's own before a single member is looked at. The unpacked tree has to
# be plain files and directories, each with one link, and tar itself leaves
# out members that name a parent directory; anything else refuses the whole
# theme before any of it reaches the theme directory.
max_theme_bytes=$((2 * 1024 * 1024 * 1024))
work=$(mktemp -d -p /var/tmp omarchy-lock-explorer.XXXXXX)
trap 'rm -rf "$work"' EXIT
exec 4<"$spool" || exit 1
[[ -f /dev/fd/4 && $(stat -L -c %u /dev/fd/4) == "$owner_uid" ]] || exit 1
(( $(stat -L -c %s /dev/fd/4) <= max_theme_bytes )) || exit 1
head -c "$max_theme_bytes" /dev/fd/4 > "$work/theme.tar"
exec 4<&-
mkdir "$work/theme"
# A word from tar on stderr -- a member renamed or left out -- is not a theme
# apply.sh made, so it refuses. Timestamps are not restored, so a clock that
# moved cannot cause one.
tar -xmf "$work/theme.tar" -C "$work/theme" --no-same-owner --no-same-permissions \
  --warning=no-timestamp 2>"$work/tar.err" || exit 1
[[ ! -s $work/tar.err ]] || exit 1
[[ -f $work/theme/omarchy-boot.plymouth && ! -L $work/theme/omarchy-boot.plymouth ]] || exit 1
[[ -z $(find "$work/theme" -mindepth 1 \( \( ! -type f -a ! -type d \) -o \( -type f -a -links +1 \) \) -print -quit) ]] || exit 1

theme_root=/usr/share/plymouth/themes
rm -rf "$theme_root/omarchy-boot"
mkdir -p "$theme_root/omarchy-boot"
cp -r --no-preserve=mode,ownership "$work/theme/." "$theme_root/omarchy-boot/"
find "$theme_root/omarchy-boot" -type d -exec chmod 0755 {} + \
  -o -type f -exec chmod 0644 {} +
plymouth-set-default-theme omarchy-boot

if command -v limine-mkinitcpio >/dev/null 2>&1; then
  limine-mkinitcpio
else
  mkinitcpio -P
fi
EOF
    chmod 755 "$helper"

    cat > "$unit_base.service" <<EOF
[Unit]
Description=Apply the rotated omarchy-lock-explorer boot screen

[Service]
Type=oneshot
ExecStart=$helper
EOF

    cat > "$unit_base.path" <<EOF
[Unit]
Description=Watch for omarchy-lock-explorer boot rotation requests

[Path]
PathExists=$req

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable --now "$(basename "$unit_base").path"
    echo installed
    ;;
  remove)
    systemctl disable --now "$(basename "$unit_base").path" 2>/dev/null || true
    rm -f "$unit_base.service" "$unit_base.path" "$helper"
    systemctl daemon-reload
    echo removed
    ;;
  *)
    echo "Unknown mode: $mode" >&2
    exit 1
    ;;
esac
