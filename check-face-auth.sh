#!/bin/bash
# Check whether facelock face auth is installed and configured for the user.
# The CLI "facelock list" requires root, but face auth via PAM
# uses the daemon directly — so we check the prerequisites instead.

FACE_PAM="/etc/pam.d/omarchy-lock-face"
PAM_MODULE="/usr/lib/security/pam_facelock.so"
user="${USER:-$(id -un)}"

# 1. Binary and PAM module must be installed
if ! command -v facelock >/dev/null 2>&1 || [[ ! -f "$PAM_MODULE" ]]; then
  echo no
  exit 0
fi

# 2. PAM service config must exist and reference pam_facelock.so
if [[ ! -f "$FACE_PAM" ]] || ! grep -q "pam_facelock.so" "$FACE_PAM" 2>/dev/null; then
  echo no
  exit 0
fi

# 3. Facelock daemon service must be active or enabled
if ! systemctl is-active --quiet facelock-daemon.service 2>/dev/null && \
   ! systemctl is-enabled --quiet facelock-daemon.service 2>/dev/null; then
  echo no
  exit 0
fi

# 4. At least one ONNX model must be present
if [[ ! -d /var/lib/facelock/models ]] || ! compgen -G "/var/lib/facelock/models/*.onnx" > /dev/null 2>&1; then
  echo no
  exit 0
fi

# 5. User must have an enrolled face model
if [[ -d /var/lib/facelock/enrolled ]]; then
  if [[ ! -f "/var/lib/facelock/enrolled/$user" ]]; then
    echo no
    exit 0
  fi
  if ! grep -q '"models": *[1-9]' "/var/lib/facelock/enrolled/$user" 2>/dev/null; then
    echo no
    exit 0
  fi
fi

# 6. A camera device must be present
if ! compgen -G "/dev/video*" > /dev/null 2>&1; then
  echo no
  exit 0
fi

echo yes
