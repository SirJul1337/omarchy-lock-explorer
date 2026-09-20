#!/bin/bash
# Parse every .qml file with qmllint and fail on the ones that cannot be read
# at all. Run locally and in CI (see .github/workflows/qml-syntax-check.yml).
#
# Only syntax is checked, not the warnings qmllint is better known for. The
# designs import Quickshell and the shell's own qs.Commons, neither of which
# exists on a CI runner, so every file would otherwise arrive buried under
# unresolved imports and unqualified lookups. A file that will not parse is a
# file the lock screen cannot load, and that is worth a red build on its own.
#
# qmllint is in qt6-declarative-dev-tools on Debian/Ubuntu and qt6-declarative
# on Arch; it may be on PATH or under a Qt libexec directory.
set -uo pipefail
cd "$(dirname "$(realpath "$0")")/.." || exit 1

qmllint=""
for candidate in qmllint qmllint-qt6 /usr/lib/qt6/bin/qmllint /usr/lib/qt6/libexec/qmllint; do
  if command -v "$candidate" >/dev/null 2>&1; then
    qmllint="$candidate"
    break
  fi
done

if [[ -z $qmllint ]]; then
  echo "note: qmllint not installed, skipping (CI runs it)"
  exit 0
fi

mapfile -t files < <(find . -name '*.qml' -not -path './.git/*' | sort)
if (( ${#files[@]} == 0 )); then
  echo "no QML files found"
  exit 1
fi

# --json - writes the report to stdout. qmllint exits non-zero for warnings
# too, so the report decides, not the exit code.
report=$("$qmllint" --json - "${files[@]}" 2>/dev/null)

if [[ -z $report ]]; then
  echo "FAIL: qmllint produced no report"
  exit 1
fi

printf '%s' "$report" | python3 "$(dirname "$(realpath "$0")")/qml-syntax-report.py" "${#files[@]}"
