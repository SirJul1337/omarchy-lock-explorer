#!/bin/bash
# PAM service for security-key unlock on the lock screen.
#   setup-fido2.sh            write /etc/pam.d/omarchy-lock-fido2
#   setup-fido2.sh --remove   delete it again (only if this script wrote it)
#
# The plugin never touches PAM from QML; this is the one place that needs root,
# and it is a file the user can read before running it.
#
# Enrol the key first with the Omarchy menu: Setup > Security > Fido2.
set -uo pipefail

PAM_MODULE="/usr/lib/security/pam_u2f.so"
AUTHFILE="/etc/fido2/fido2"
TARGET="/etc/pam.d/omarchy-lock-fido2"
MARKER="io.github.sirjul1337.lock-explorer"

# /etc/pam.d is root-owned, so only root can put a link here. Refused all the
# same: -f and grep would read through it and take some other file for ours,
# and the remove path would then delete a link it never made.
if [[ -L $TARGET ]]; then
  echo "$TARGET is a symlink; not touching it"
  exit 1
fi
if [[ -e $TARGET && ! -f $TARGET ]]; then
  echo "$TARGET exists but is not a regular file; not touching it"
  exit 1
fi

case "${1:-}" in
  --remove)
    if [[ ! -f $TARGET ]]; then
      echo "nothing to remove: $TARGET does not exist"
      exit 0
    fi
    if ! grep -q "$MARKER" "$TARGET"; then
      echo "$TARGET was not written by this plugin; remove it yourself if you mean to"
      exit 1
    fi
    sudo rm -f "$TARGET" || exit 1
    echo "removed $TARGET"
    exit 0
    ;;
  "") ;;
  *)
    echo "usage: setup-fido2.sh [--remove]"
    exit 1
    ;;
esac

if [[ ! -f $PAM_MODULE ]]; then
  echo "install it first: sudo pacman -S --needed pam-u2f libfido2"
  exit 1
fi

if [[ ! -f $AUTHFILE ]]; then
  echo "enroll a key first: Omarchy menu > Setup > Security > Fido2 (omarchy-setup-security-fido2)"
  exit 1
fi

if [[ -f $TARGET ]]; then
  if grep -q "pam_u2f.so" "$TARGET"; then
    echo "already set up: $TARGET (left as is)"
    exit 0
  fi
  echo "$TARGET exists but does not load pam_u2f.so; move it aside and rerun"
  exit 1
fi

# The content reaches root over a pipe, not through a file. A temporary in
# $TMPDIR would be reopened by root after the sudo prompt, and anything running
# as this user could have swapped it by then; a pipe has no name to swap.
# install replaces the destination rather than writing through it, so a file
# that appeared at $TARGET in the meantime is unlinked, never followed.
cat <<EOF | sudo install -o root -g root -m 0644 /dev/stdin "$TARGET" || exit 1
#%PAM-1.0
# Security-key unlock for the Omarchy lock screen ($MARKER).
# Its own service on purpose: a \`sufficient pam_u2f.so\` line in
# omarchy-lock-password would send every mistyped password to the key as a
# PIN attempt. \`required\` with no pam_unix fallback: the way back to the
# password is Tab on the lock screen, not a silent fall-through.
# No pinverification=1: pam_u2f ORs it with the per-credential flag and
# would force a PIN onto keys enrolled without one.
auth       required    pam_u2f.so authfile=$AUTHFILE cue [cue_prompt=Touch your security key]
account    include     system-local-login
EOF
echo "done. Lock the screen with a key plugged in."
