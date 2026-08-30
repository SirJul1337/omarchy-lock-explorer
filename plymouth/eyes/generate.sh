#!/bin/bash
# Boot screen twin of the eyes clip design, see cliptwin.sh.
exec bash "$(dirname "$(realpath "$0")")/../cliptwin.sh" "${1:?usage: generate.sh <staging-dir>}" eyes omarchy-eye.mp4
