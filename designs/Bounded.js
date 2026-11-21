.pragma library

// Every helper process the plugin starts goes through run(): it gets a
// deadline, its output is capped before the shell reads it, and whatever it
// starts in turn goes when it goes.
//
//   command: Bounded.run(["hyprctl", "-j", "devices"], { deadline: 5, cap: 262144 })
//
// deadline  seconds before the helper and everything it started are sent
//           TERM, then KILL two seconds later. 0 only for a watcher that runs
//           as long as the lock or the explorer wants it (udevadm monitor, a
//           ttfx stream); those are still ended with the shell.
// cap       bytes of stdout the shell takes in all. Past it the helper is cut
//           off and fails, so a result too big to be real reads as an error.
// line      bytes per line, for a stream read line by line, where a total cap
//           would end it too soon.
//
// How the cleanup works: the outer bash stays the shell's direct child. The
// helper runs under timeout, which puts it in a process group of its own and
// passes a TERM it gets on to that whole group. Both carry a parent-death
// signal (setpriv --pdeathsig), so when Quickshell stops the outer bash --
// TERM from `running = false`, KILL when the Process object is destroyed --
// or exits altogether, timeout is told and takes the group down with it.

var SCRIPT = 'd="$1"; c="$2"; l="$3"; shift 3\n'
  // timeout 0 means no deadline, but the uutils timeout then stops passing
  // a TERM on to the group, so a watcher would outlive its stop. infinity
  // keeps the forwarding in both GNU and uutils.
  + '[ "$d" -gt 0 ] || d=infinity\n'
  + 'set -o pipefail\n'
  + 'run() { setpriv --pdeathsig TERM timeout -k 2 "$d" "$@"; }\n'
  // In a pipeline bash runs the helper in a subshell of its own, which would
  // be timeout's parent and outlive this bash: exec it away.
  + 'piped() { exec setpriv --pdeathsig TERM timeout -k 2 "$d" "$@"; }\n'
  + 'if [ "$c" -gt 0 ]; then piped "$@" | head -c "$c"\n'
  + 'elif [ "$l" -gt 0 ]; then piped "$@" | stdbuf -oL cut -b "1-$l"\n'
  + 'else run "$@"\n'
  + 'fi\n'
  // A plain last command would be exec'd in place of this bash, and the
  // parent-death signal above would then have no parent to watch.
  + 'exit $?'

function whole(n) {
  var v = Math.floor(Number(n))
  return isFinite(v) && v > 0 ? v : 0
}

function run(argv, opts) {
  var o = opts || {}
  return ["setpriv", "--pdeathsig", "TERM", "bash", "-c", SCRIPT, "bounded",
          String(whole(o.deadline)), String(whole(o.cap)), String(whole(o.line))].concat(argv)
}
