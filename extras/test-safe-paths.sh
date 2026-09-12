#!/bin/bash
# Adversarial tests for extras/safe-paths.sh. Each case sets up something a
# writer should refuse, runs a real write through the public functions, and
# fails if anything landed outside the intended directory.
#
# Run it directly: extras/test-safe-paths.sh
set -uo pipefail

here="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=extras/safe-paths.sh
source "$here/safe-paths.sh"

# The rules these tests exercise start at $HOME, so a $HOME that already
# breaks them would fail every case for a reason that is not the code's.
home_mode=$(stat -c %a "${HOME:?}" 2>/dev/null || echo 000)
if (( 8#$home_mode & 8#022 )); then
  echo "skipping: \$HOME is group- or world-writable (mode $home_mode)" >&2
  exit 0
fi

root=$(mktemp -d "${HOME:?}/.safe-paths-test.XXXXXX") || exit 1
trap 'chmod -R u+rwX "$root" 2>/dev/null; rm -rf "$root"' EXIT

pass=0; fail_count=0
ok()   { pass=$((pass + 1));       printf '  ok   %s\n' "$1"; }
bad()  { fail_count=$((fail_count + 1)); printf '  FAIL %s\n' "$1"; }

# Each write runs in a subshell: the helpers call `exit` on refusal, and a
# refusal is the expected result in most of these.
try_put() { ( echo PAYLOAD | put_file "$1" "$2" ) >/dev/null 2>&1; }

refuses() { # refuses DESC DIR NAME [WITNESS...]
  local desc=$1 dir=$2 name=$3; shift 3
  if try_put "$dir" "$name"; then bad "$desc (write was allowed)"; return; fi
  local witness
  for witness in "$@"; do
    if [[ -e $witness ]]; then bad "$desc (wrote to $witness)"; return; fi
  done
  ok "$desc"
}

allows() { # allows DESC DIR NAME
  local desc=$1 dir=$2 name=$3
  if try_put "$dir" "$name" && [[ -f $dir/$name ]] &&
     [[ $(cat "$dir/$name") == PAYLOAD ]]; then ok "$desc"
  else bad "$desc (a legitimate write was refused)"; fi
}

echo "safe-paths adversarial tests"

# --- the ordinary case still works ------------------------------------------
allows "plain write into a fresh directory" "$root/normal/deep" out.txt

mkdir -p "$root/existing"
allows "overwrite of our own existing file" "$root/existing" out.txt
allows "second overwrite of the same file"  "$root/existing" out.txt

# --- symlinked components ---------------------------------------------------
mkdir -p "$root/elsewhere"
ln -s "$root/elsewhere" "$root/link"
refuses "symlinked target directory" \
  "$root/link" out.txt "$root/elsewhere/out.txt"

mkdir -p "$root/real/inner"
ln -s "$root/elsewhere" "$root/parentlink"
refuses "symlinked parent component" \
  "$root/parentlink/inner" out.txt "$root/elsewhere/out.txt"

# --- a symlink standing where our file should be ----------------------------
mkdir -p "$root/filelink"
ln -s "$root/elsewhere/victim.txt" "$root/filelink/out.txt"
refuses "symlink in place of our file" \
  "$root/filelink" out.txt "$root/elsewhere/victim.txt"

# --- loose permissions on an ancestor ---------------------------------------
# The flaw HANCORE-linux reported: owned, so `-O` passed, but writable by
# anyone, so anyone could swap a component inside it.
mkdir -p "$root/worldw/deep"; chmod 0777 "$root/worldw"
refuses "world-writable ancestor" "$root/worldw/deep" out.txt
chmod 0755 "$root/worldw"

mkdir -p "$root/groupw/deep"; chmod 0775 "$root/groupw"
refuses "group-writable ancestor" "$root/groupw/deep" out.txt
chmod 0755 "$root/groupw"

mkdir -p "$root/selfloose"; chmod 0777 "$root/selfloose"
refuses "world-writable target directory itself" "$root/selfloose" out.txt
chmod 0755 "$root/selfloose"

# --- escaping $HOME ---------------------------------------------------------
refuses "absolute path outside \$HOME" /tmp/sp-escape out.txt /tmp/sp-escape/out.txt
refuses "traversal back out of \$HOME" "$root/../../../tmp/sp-escape2" out.txt \
  /tmp/sp-escape2/out.txt

# --- a non-directory in the way ---------------------------------------------
mkdir -p "$root/notdir"; : > "$root/notdir/file"
refuses "regular file used as a directory" "$root/notdir/file" out.txt

# --- bad names --------------------------------------------------------------
refuses "name containing a slash"  "$root/normal/deep" "sub/out.txt"
refuses "name that is dot-dot"     "$root/normal/deep" ".."

# --- the write binds to the directory that was checked, not to its path -----
# What the descriptor walk buys: once the target is validated, nothing is
# looked up by name again. Swap the whole directory out from under an in-flight
# write -- move it aside, drop a fresh one at the old path -- and the bytes
# must land in the directory that was checked, not in the one that replaced it.
mkdir -p "$root/bind/target"
mkfifo "$root/bind/feed"
( put_file "$root/bind/target" out.txt < "$root/bind/feed" ) >/dev/null 2>&1 &
writer_pid=$!
exec {feed}>"$root/bind/feed"
printf 'PAY' >&"$feed"
sleep 0.3                      # past the descent now, blocked reading stdin
mv "$root/bind/target" "$root/bind/moved"
mkdir -p "$root/bind/target"   # an impostor at the checked path
printf 'LOAD' >&"$feed"
exec {feed}>&-
wait "$writer_pid" 2>/dev/null

if [[ -f $root/bind/moved/out.txt && ! -e $root/bind/target/out.txt ]]; then
  ok "write follows the checked directory, not its path"
else
  bad "write followed the path instead of the checked directory"
fi

# --- drop_file --------------------------------------------------------------
mkdir -p "$root/removal"; echo x > "$root/removal/gone.txt"
drop_file "$root/removal" gone.txt
[[ -e $root/removal/gone.txt ]] && bad "drop_file removes our file" ||
  ok "drop_file removes our file"

mkdir -p "$root/removal2"; : > "$root/elsewhere/keep.txt"
ln -s "$root/elsewhere/keep.txt" "$root/removal2/link.txt"
drop_file "$root/removal2" link.txt
[[ -e $root/elsewhere/keep.txt ]] &&
  ok "drop_file leaves a symlink and its target alone" ||
  bad "drop_file followed a symlink"

printf '\n%d passed, %d failed\n' "$pass" "$fail_count"
[[ $fail_count -eq 0 ]]
