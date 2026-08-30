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
#   rotate-setup.sh install /home/you
#   rotate-setup.sh remove
set -euo pipefail

mode="${1:?usage: rotate-setup.sh install <home> | remove}"
helper=/usr/local/lib/omarchy-lock-explorer-rotate.sh
unit_base=/etc/systemd/system/omarchy-lock-explorer-boot

case $mode in
  install)
    home="${2:?missing home dir}"
    req="$home/.local/state/omarchy/lock-explorer-boot-request"

    mkdir -p /usr/local/lib
    cat > "$helper" <<EOF
#!/bin/bash
# Applies the boot theme staged by omarchy-lock-explorer's rotation.
set -euo pipefail
req="$req"
[[ -f \$req ]] || exit 0
staging=\$(cat "\$req")
rm -f "\$req"
[[ -f \$staging/omarchy-boot.plymouth ]] || exit 1

theme_root=/usr/share/plymouth/themes
rm -rf "\$theme_root/omarchy-boot"
mkdir -p "\$theme_root/omarchy-boot"
cp -r --no-preserve=mode,ownership "\$staging/." "\$theme_root/omarchy-boot/"
chmod -R a+rX "\$theme_root/omarchy-boot"
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
