#!/bin/bash
# Removes the boot screen rotation helper that earlier versions installed
# (run through pkexec):
#
#   rotate-setup.sh remove
#
# That helper was a root path unit that applied whatever boot theme the
# account staged, without asking. A theme decides which Plymouth plugin root
# loads, so that turned a standing permission to change the splash into
# running code as root. It is no longer installed; the boot rotation asks
# through polkit like every other boot screen change.
set -euo pipefail

mode="${1:?usage: rotate-setup.sh remove}"
helper=/usr/local/lib/omarchy-lock-explorer-rotate.sh
unit_base=/etc/systemd/system/omarchy-lock-explorer-boot

case $mode in
  remove)
    systemctl disable --now "$(basename "$unit_base").path" 2>/dev/null || true
    rm -f "$unit_base.service" "$unit_base.path" "$helper"
    systemctl daemon-reload
    echo removed
    ;;
  install)
    echo "The passwordless rotation helper is no longer installed; rotation asks each time" >&2
    exit 1
    ;;
  *)
    echo "Unknown mode: $mode" >&2
    exit 1
    ;;
esac
