#!/bin/bash
# Check whether security-key unlock (pam_u2f) is configured, and whether a key
# is attached right now. Prints "<yes|no> <present|absent>".
# Configured means the omarchy-lock-fido2 PAM service exists and loads
# pam_u2f.so, the module is installed, and the authfile it names has a line for
# this user. The authfile is root-owned and normally world-readable; when it is
# not, a non-empty file has to do.

FIDO2_PAM="/etc/pam.d/omarchy-lock-fido2"
PAM_MODULE="/usr/lib/security/pam_u2f.so"

present() {
  # A wedged key can hang the enumeration; the lock screen must not wait on it.
  if command -v fido2-token >/dev/null 2>&1 && timeout 3 fido2-token -L 2>/dev/null | grep -q .; then
    echo present
  else
    echo absent
  fi
}

if [[ ! -f "$FIDO2_PAM" ]] || ! grep -q "pam_u2f.so" "$FIDO2_PAM" 2>/dev/null || [[ ! -f "$PAM_MODULE" ]]; then
  echo "no absent"
  exit 0
fi

authfile=$(grep -o 'authfile=[^ ]*' "$FIDO2_PAM" 2>/dev/null | head -1 | cut -d= -f2)
[[ -z "$authfile" ]] && authfile="/etc/fido2/fido2"
[[ "$authfile" != /* ]] && authfile="$HOME/$authfile"
user="${USER:-$(id -un)}"

if [[ -r "$authfile" ]]; then
  if ! grep -q "^${user}:" "$authfile"; then
    echo "no absent"
    exit 0
  fi
elif [[ ! -s "$authfile" ]]; then
  echo "no absent"
  exit 0
fi

echo "yes $(present)"
