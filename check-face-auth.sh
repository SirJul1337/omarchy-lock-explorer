#!/bin/bash
# Detect the configured face authentication provider for this user.
FACE_PAM="/etc/pam.d/omarchy-lock-face"
if [[ ! -r "$FACE_PAM" ]]; then
  echo no
  exit 0
fi

if grep -Eq '^[[:space:]]*auth[[:space:]].*pam_howdy\.so([[:space:]]|$)' "$FACE_PAM" && [[ -f /usr/lib/security/pam_howdy.so ]]; then
  if ! command -v python >/dev/null 2>&1; then
    echo no
    exit 0
  fi
  python - <<'PYTHON'
import configparser
import json
import pwd
import os
from pathlib import Path
try:
    config = configparser.ConfigParser()
    config.read('/etc/howdy/config.ini')
    model = Path('/etc/howdy/models') / (pwd.getpwuid(os.getuid()).pw_name + '.dat')
    data = json.loads(model.read_text())
    ready = (not config.getboolean('core', 'disabled', fallback=False)
             and bool(data) and any(item.get('data') for item in data))
    print('yes' if ready else 'no')
except (OSError, ValueError, configparser.Error, AttributeError, TypeError):
    print('no')
PYTHON
  exit 0
fi

if grep -Eq '^[[:space:]]*auth[[:space:]].*pam_facelock\.so([[:space:]]|$)' "$FACE_PAM" && [[ -f /usr/lib/security/pam_facelock.so ]] && compgen -G '/var/lib/facelock/models/*.onnx' > /dev/null 2>&1; then
  echo yes
else
  echo no
fi
