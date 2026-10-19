import QtQuick
import Quickshell
import Quickshell.Io
import "Ttfx.js" as Ttfx

// The square Omarchy logo as text: the branding copy in
// ~/.config/omarchy/branding/about.txt, then /usr/share/omarchy/icon.txt,
// then the copy in Ttfx.js.
Item {
  id: source

  property string text: Ttfx.ICON

  CappedFile {
    path: Quickshell.env("HOME") + "/.config/omarchy/branding/about.txt"
    maxBytes: 65536
    onLoaded: source.take(text())
    onLoadFailed: stock.path = "/usr/share/omarchy/icon.txt"
  }

  // Only given a path once the branding copy turns out to be missing, and
  // then a root-owned one under /usr/share/omarchy.
  FileView {
    id: stock
    path: ""
    printErrors: false
    onLoaded: source.take(text())
  }

  function take(t) {
    var s = String(t || "").replace(/\s+$/, "")
    if (s.trim().length > 0) text = s
  }
}
