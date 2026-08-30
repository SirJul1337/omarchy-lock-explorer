#!/bin/bash
# Boot screen twin of the storm clip design, see cliptwin.sh.
exec bash "$(dirname "$(realpath "$0")")/../cliptwin.sh" "${1:?usage: generate.sh <staging-dir>}" storm omarchy-storm.mp4
