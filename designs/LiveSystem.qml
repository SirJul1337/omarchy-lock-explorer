import QtQuick
import Quickshell.Io

// Uptime, memory, load and kernel for the designer's System info piece,
// reread every 15 seconds like the System design does.
Item {
  id: sys
  property real uptimeSeconds: 0
  property string memory: ""
  property int memoryPercent: 0
  property string load: ""
  property string kernel: ""

  readonly property string uptime: {
    var s = uptimeSeconds
    if (s <= 0) return ""
    var d = Math.floor(s / 86400), h = Math.floor((s % 86400) / 3600), m = Math.floor((s % 3600) / 60)
    if (d > 0) return d + "d " + h + "h"
    if (h > 0) return h + "h " + m + "m"
    return m + "m"
  }

  FileView {
    id: uptimeFile
    path: "/proc/uptime"
    printErrors: false
    onLoaded: sys.uptimeSeconds = parseFloat(String(text()).split(" ")[0]) || 0
  }
  FileView {
    id: memFile
    path: "/proc/meminfo"
    printErrors: false
    onLoaded: {
      var total = 0, avail = 0
      String(text()).split("\n").forEach(function(l) {
        if (l.indexOf("MemTotal:") === 0) total = parseInt(l.replace(/\D+/g, ""))
        if (l.indexOf("MemAvailable:") === 0) avail = parseInt(l.replace(/\D+/g, ""))
      })
      if (total > 0) {
        sys.memoryPercent = Math.round(100 * (total - avail) / total)
        sys.memory = ((total - avail) / 1048576).toFixed(1) + " / " + (total / 1048576).toFixed(0) + " GB"
      }
    }
  }
  FileView {
    id: loadFile
    path: "/proc/loadavg"
    printErrors: false
    onLoaded: sys.load = String(text()).split(" ").slice(0, 3).join("  ")
  }
  FileView {
    path: "/proc/sys/kernel/osrelease"
    printErrors: false
    onLoaded: sys.kernel = String(text()).trim()
  }
  Timer {
    interval: 15000
    running: true
    repeat: true
    onTriggered: { uptimeFile.reload(); memFile.reload(); loadFile.reload() }
  }
}
