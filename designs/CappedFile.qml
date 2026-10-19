import QtQuick
import Quickshell.Io

// A text file the account itself can write, read by a child process: only a
// regular file, at most maxBytes of it, so a FIFO, a device or a huge file
// can neither stall the shell nor fill its memory the way a FileView read of
// it could. Files root owns are still read with FileView.
//
// The same shape as FileView where it is used: text(), reload(), loaded and
// loadFailed. allowLinks takes a symlink to a regular file (a design kept in
// a dotfiles repo); without it a link is refused like anything else.
Item {
  id: file
  visible: false

  property string path: ""
  property int maxBytes: 262144
  property bool allowLinks: false
  property bool preload: true

  property string content: ""
  property bool ready: false
  signal loaded()
  signal loadFailed()

  function text() { return content }

  property bool pending: false
  property bool exited: false
  property bool streamed: false
  property int exitCode: -1

  function reload() {
    if (path.length === 0) { content = ""; ready = false; return }
    if (proc.running) { pending = true; return }
    exited = false
    streamed = false
    proc.command = ["bash", "-c",
      'f="$1"; n="$2"; [ -f "$f" ] || exit 3; [ "$3" = 1 ] || [ ! -L "$f" ] || exit 3; '
      + '[ "$(stat -L -c %s -- "$f")" -le "$n" ] || exit 4; head -c "$n" -- "$f"',
      "cappedfile", path, String(maxBytes), allowLinks ? "1" : "0"]
    proc.running = true
  }

  function finish() {
    if (!exited || !streamed) return
    if (exitCode === 0) {
      ready = true
      loaded()
    } else {
      content = ""
      ready = false
      loadFailed()
    }
    if (pending) { pending = false; reload() }
  }

  onPathChanged: if (preload && path.length > 0) reload()
  Component.onCompleted: if (preload && path.length > 0) reload()

  Process {
    id: proc
    stdout: StdioCollector {
      id: out
      waitForEnd: true
      onStreamFinished: { file.content = String(out.text || ""); file.streamed = true; file.finish() }
    }
    onExited: function(code) { file.exitCode = code; file.exited = true; file.finish() }
  }
}
