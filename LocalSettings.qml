import QtQuick
import Quickshell
import Quickshell.Io

// Omarchy 4.0.3 no longer exposes shellConfig to third-party services.
// Retain only this plugin's settings; writes still use the scoped shell API.
Item {
  id: root
  property string pluginId: "io.github.sirjul1337.lock-explorer"
  property string path: Quickshell.env("HOME") + "/.config/omarchy/shell.json"
  property var entry: ({})
  readonly property var config: ({ plugins: [entry] })

  function reload() { settingsFile.reload() }

  FileView {
    id: settingsFile
    path: root.path
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try {
        var parsed = JSON.parse(text())
        var entries = Array.isArray(parsed.plugins) ? parsed.plugins : []
        var selected = {}
        for (var i = 0; i < entries.length; i++) {
          if (entries[i] && entries[i].id === root.pluginId) {
            selected = entries[i]
            break
          }
        }
        root.entry = selected
      } catch (e) {
        // A partial/invalid write must not reset the last known design.
        console.warn("lock-explorer: cannot read saved plugin settings")
      }
    }
  }
}
