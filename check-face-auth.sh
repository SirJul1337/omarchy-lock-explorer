#!/bin/bash
# Check whether facelock face auth is configured.
# The CLI "facelock list" requires root, but face auth via PAM
# uses the daemon directly — so we check the prerequisites instead.

FACE_PAM="/etc/pam.d/omarchy-lock-face"
PAM_MODULE="/usr/lib/security/pam_facelock.so"

# 1. PAM config must exist with pam_facelock.so
if [[ ! -f "$FACE_PAM" ]]; then
  echo no
  exit 0
fi

if ! grep -q "pam_facelock.so" "$FACE_PAM" 2>/dev/null; then
  echo no
  exit 0
fi

# 2. PAM module must be present
if [[ ! -f "$PAM_MODULE" ]]; then
  echo no
  exit 0
fi

# 3. At least one model enrolled — check the models dir for .onnx files
if [[ -d /var/lib/facelock/models ]] && compgen -G "/var/lib/facelock/models/*.onnx" > /dev/null 2>&1; then
  echo yes
else
  echo no
fi
