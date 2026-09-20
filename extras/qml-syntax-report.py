#!/usr/bin/env python3
# Reads a qmllint --json report on stdin and fails on the files that cannot be
# parsed at all. Called by extras/qml-syntax-check.sh; see there for why the
# warnings are left alone.
import json
import sys

expected = sys.argv[1] if len(sys.argv) > 1 else "?"

raw = sys.stdin.read()
try:
    report = json.loads(raw)
except json.JSONDecodeError as error:
    head = raw[:200].replace("\n", " ")
    print(f"FAIL: qmllint report is not JSON ({error})")
    if head:
        print(f"  report started: {head}")
    raise SystemExit(1)

# The shape has moved between Qt versions: {"files": [...]} in 6.x, a bare
# list in some builds.
entries = report.get("files", []) if isinstance(report, dict) else report

broken = []
for entry in entries:
    name = entry.get("filename", "?")
    for warning in entry.get("warnings", []):
        severity = str(warning.get("type", warning.get("severity", ""))).lower()
        category = str(warning.get("id", "")).lower()
        # A file that will not parse is reported as an ordinary warning in the
        # `syntax` category, not as a critical, so both have to be caught: the
        # criticals cover things like two items sharing an id.
        if category != "syntax" and severity not in ("critical", "error"):
            continue
        message = str(warning.get("message", ""))
        broken.append(f"{name}:{warning.get('line', 0)}:{warning.get('column', 0)}: {message}")

if broken:
    print("FAIL: QML that will not parse")
    for line in broken:
        print("  " + line)
    raise SystemExit(1)

print(f"qml syntax: OK ({len(entries)} of {expected} files reported)")
