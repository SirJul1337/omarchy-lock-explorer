#!/bin/bash
# Security lint for the repo, run locally and in CI (see
# .github/workflows/security-check.yml). Born out of the v1.5.0 marketplace
# review finding: a theme color crossed the pkexec boundary unvalidated and
# was interpolated into a root sed on limine.conf.
#
# Two layers:
#   1. shellcheck over every shell script (skipped when not installed; the
#      noisy style codes are triaged in .shellcheckrc)
#   2. injection greps for the patterns shellcheck does not flag:
#      - a variable expanded inside a sed program
#      - eval anywhere
#      - a variable expanded inside an inline bash -c / sh -c body
#      - a QML Process command concatenating values into a bash -c body
#        (values belong in positional args after the body: "$0", "$1", ...)
#
# A hit that is genuinely safe (the value is validated first, or is a local
# constant) is silenced with `# sec-ok: <why>` on the same or previous line.
# The reason is mandatory: the next reader has to be able to re-check it.
set -uo pipefail
cd "$(dirname "$(realpath "$0")")/.." || exit 1

fail=0

# The checker excludes itself from the greps: its labels and comments have to
# be able to name the very patterns they hunt.
mapfile -t scripts < <(find . -name '*.sh' -not -path './.git/*' \
  -not -path './extras/security-check.sh' | sort)
mapfile -t qml < <(find . -name '*.qml' -not -path './.git/*' | sort)

# --- shellcheck ------------------------------------------------------------
if command -v shellcheck >/dev/null 2>&1; then
  if ! shellcheck --severity=warning "${scripts[@]}"; then
    fail=1
  fi
else
  echo "note: shellcheck not installed, skipping that layer (CI runs it)"
fi

# --- injection greps -------------------------------------------------------
# flag <label> <extended-regex> <files...>: print every match not annotated
# with sec-ok on the same or the preceding line.
flag() {
  local label="$1" re="$2"; shift 2
  local hits="" f n rest prev
  while IFS=: read -r f n rest; do
    [[ $rest == *"sec-ok:"* ]] && continue
    prev=$([[ $n -gt 1 ]] && sed -n "$((n - 1))p" "$f")
    [[ $prev == *"sec-ok:"* ]] && continue
    hits+="$f:$n: $rest"$'\n'
  done < <(grep -nE "$re" "$@" /dev/null 2>/dev/null)
  if [[ -n $hits ]]; then
    printf '\nFAIL: %s\n%s' "$label" "$hits"
    fail=1
  fi
}

flag "variable expanded inside a sed program (validate the value, then annotate '# sec-ok: <why>')" \
  'sed[^"]*"[^"$]+\$[a-zA-Z_{]|-e +"[^"$]*\$[a-zA-Z_{]' \
  "${scripts[@]}"

flag "eval is banned in this repo" \
  '(^|[^a-zA-Z_.-])eval[ (]' \
  "${scripts[@]}" "${qml[@]}"

flag "variable expanded inside an inline bash -c body (pass it as a positional arg instead)" \
  '(bash|sh) -c "[^"]*\$' \
  "${scripts[@]}"

flag "QML concatenates into a bash -c body (pass values as positional args after the script)" \
  '"-c",.*\+' \
  "${qml[@]}"

if [[ $fail == 0 ]]; then
  echo "security check: OK"
else
  echo
  echo "security check: FAILED"
fi
exit $fail
