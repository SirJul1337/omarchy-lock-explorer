import QtQuick
import Quickshell
import Quickshell.Io

// This plugin's own entry in ~/.config/omarchy/shell.json, read straight off
// disk. Omarchy 4.0.3 stopped handing third-party plugins `shell.shellConfig`,
// so without this every setting fell back to its default, and worse, every
// write went out with an empty entry and replaced whatever else was saved
// (issue #19). Writes still go through the host's scoped updateEntryInline.
//
// The first read blocks: pluginEntry() is read-modify-write, so a write that
// raced the initial async load would not merely see a stale value, it would
// destroy the rest of the entry. `remember()` keeps a write-through copy of
// what was just written, since the file watcher lands a beat after the host's
// atomic write and two settings changed back to back must not clobber each
// other.
Item {
  id: root
  property string pluginId: "io.github.sirjul1337.lock-explorer"
  property string path: Quickshell.env("HOME") + "/.config/omarchy/shell.json"
  property var entry: ({})
  property bool loaded: false
  readonly property var config: ({ plugins: [entry] })

  function reload() { settingsFile.reload() }

  function remember(next) {
    var copy = {}
    for (var k in next) if (k !== "id") copy[k] = next[k]
    copy.id = root.pluginId
    root.entry = copy
  }

  function parse() {
    var raw = ""
    try { raw = String(settingsFile.text() || "") } catch (e) { raw = "" }
    if (raw.trim().length === 0) {
      // A missing or empty file has no entry to keep; nothing to protect.
      root.entry = {}
      root.loaded = true
      return
    }
    try {
      var parsed = JSON.parse(raw)
      var entries = parsed && Array.isArray(parsed.plugins) ? parsed.plugins : []
      var selected = {}
      for (var i = 0; i < entries.length; i++) {
        if (entries[i] && String(entries[i].id || "") === root.pluginId) {
          selected = entries[i]
          break
        }
      }
      root.entry = selected
      root.loaded = true
    } catch (e) {
      // A partial or invalid write must not reset the last known settings.
      console.warn("lock-explorer: cannot read saved plugin settings: " + e)
    }
  }

  FileView {
    id: settingsFile
    path: root.path
    blockLoading: true
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.parse()
    onLoadFailed: root.parse()
  }

  Component.onCompleted: parse()
}
