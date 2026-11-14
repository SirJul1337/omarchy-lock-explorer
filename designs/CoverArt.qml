import QtQuick
import Quickshell.Io
import "Bounded.js" as Bounded

// A media player's cover art, made safe to show. The URL comes from whichever
// program on the session bus claims to be a player, so the shell never hands
// it to Qt's image decoders itself: a PNG can carry compressed text chunks
// that inflate to gigabytes before any scaling. A child process instead
// fetches the art (a local file or https, at most maxBytes), takes it only
// when its signature is PNG, JPEG, WebP or GIF, and has magick re-encode it
// as a stripped PNG of at most 512 pixels, all under a memory, CPU and time
// limit. Only that PNG reaches the shell, as a data URL; a cover that fails
// any step is simply not shown.
Item {
  id: art
  visible: false

  // The player's trackArtUrl, as it says it.
  property string url: ""
  // What an Image may load: a data: URL of the re-encoded PNG, or "".
  property string source: ""

  readonly property int maxBytes: 8388608
  readonly property int maxOutput: 2097152

  readonly property string wanted: {
    var u = String(url || "")
    if (/^https:\/\//.test(u)) return u.length <= 2048 ? u : ""
    if (!/^file:\/\/\//.test(u)) return ""
    try { return decodeURIComponent(u.substring(7)) } catch (e) { return "" }
  }

  property string loaded: ""

  function refresh() {
    if (wanted === loaded) return
    if (wanted.length === 0) { loaded = ""; source = ""; return }
    // A change while one runs is picked up when it finishes.
    if (proc.running) return
    proc.target = wanted
    proc.command = Bounded.run(["bash", "-c",
      'set -o pipefail; src="$1"; cap="$2"; outcap="$3"; '
      + 'ulimit -v 1048576; ulimit -t 15; export MAGICK_THREAD_LIMIT=1; '
      + 'command -v magick >/dev/null || exit 2; '
      + 'd=$(mktemp -d "${XDG_RUNTIME_DIR:-/tmp}/lock-explorer-art.XXXXXX") || exit 1; '
      + 'trap \'rm -rf -- "$d"\' EXIT; '
      + 'case $src in '
      + '  https://*) timeout 20 curl -fsS --proto =https --proto-redir =https --max-redirs 3 '
      + '    --max-time 15 --max-filesize "$cap" -- "$src" | head -c "$cap" > "$d/in" || exit 3 ;; '
      + '  /*) [ -f "$src" ] || exit 3; [ "$(stat -L -c %s -- "$src")" -le "$cap" ] || exit 4; '
      + '    timeout 5 head -c "$cap" -- "$src" > "$d/in" || exit 3 ;; '
      + '  *) exit 3 ;; '
      + 'esac; '
      + 'sig=$(head -c 12 -- "$d/in" | od -An -tx1 | tr -d " \\n"); '
      + 'case $sig in '
      + '  89504e470d0a1a0a*) c=png ;; ffd8ff*) c=jpeg ;; '
      + '  52494646????????57454250) c=webp ;; 474946383761* | 474946383961*) c=gif ;; '
      + '  *) exit 5 ;; '
      + 'esac; '
      + 'timeout 20 magick -limit memory 256MiB -limit map 512MiB -limit disk 0 -limit area 64MP '
      + '  -limit width 16KP -limit height 16KP -limit time 15 "$c:$d/in[0]" '
      + '  -auto-orient -strip -thumbnail "512x512>" -define png:exclude-chunks=all "png:$d/out" || exit 6; '
      + '[ "$(stat -c %s -- "$d/out")" -le "$outcap" ] || exit 7; '
      + 'base64 -w0 -- "$d/out"',
      "coverart", wanted, String(maxBytes), String(maxOutput)], { deadline: 60, cap: Math.ceil(maxOutput * 4 / 3) + 16 })
    proc.running = true
  }

  onWantedChanged: refresh()
  Component.onCompleted: refresh()

  property bool exited: false
  property bool streamed: false
  property int exitCode: -1
  property string output: ""

  function finish() {
    if (!exited || !streamed) return
    exited = false
    streamed = false
    var b64 = output
    output = ""
    var ok = exitCode === 0 && b64.length > 0 && b64.length <= maxOutput * 4 / 3 + 4
             && /^[A-Za-z0-9+\/]+=*$/.test(b64)
    loaded = proc.target
    source = ok && proc.target === wanted ? "data:image/png;base64," + b64 : ""
    Qt.callLater(refresh)
  }

  Process {
    id: proc
    property string target: ""
    stdout: StdioCollector {
      id: out
      waitForEnd: true
      onStreamFinished: { art.output = String(out.text || ""); art.streamed = true; art.finish() }
    }
    onExited: function(code) { art.exitCode = code; art.exited = true; art.finish() }
  }
}
