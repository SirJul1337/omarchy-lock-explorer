import QtQuick
import QtQuick.Effects
import Quickshell.Io
import qs.Commons

// A machine's view of the lock screen. Your wallpaper, tinted red and darkened,
// under a grid, with this machine's specs in big white readout and a target box
// that tightens on the field with every key. A wrong password gets stamped
// ACCESS DENIED.
//
// Nothing here repaints per frame. The grid is painted once, the wallpaper
// is tinted once into a cached layer, and the readout is plain Text that only
// changes when a value does (the live figures are read every two seconds).
DesignBase {
  id: lock
  inputItem: field.input

  readonly property color red: Qt.rgba(0.95, 0.14, 0.1, 1)
  // Decays from 1 after a wrong password.
  property real denied: 0
  // 0..1, how closed the target box is around the field.
  readonly property real lockOn: Math.min(1, lock.passwordText.length / 12)
  // Readout size, scaled to the screen.
  // The 3270 face runs small for its size, so it is set a little larger.
  readonly property real faceScale: lock.face.indexOf("3270") === 0 ? 1.15 : 1
  // Width of one character, as a fraction of the font size.
  readonly property real cw: lock.face.indexOf("3270") === 0 ? 0.53 : 0.6
  readonly property int fs: Math.round(Math.max(14, Math.min(30, Math.min(lock.height / 40, lock.width / 62))) * lock.faceScale)
  readonly property real blockW: Math.min(lock.width * 0.32, 760)
  readonly property bool wide: lock.width >= 1500
  // The IBM 3270 terminal face where it is installed, then other terminal
  // faces, then whatever monospace the system has.
  readonly property string face: {
    var have = Qt.fontFamilies()
    var want = ["3270 Nerd Font Mono", "3270", "VT323", "Terminus", "Terminess Nerd Font Mono"]
    for (var i = 0; i < want.length; i++)
      if (have.indexOf(want[i]) >= 0) return want[i]
    return "monospace"
  }

  Rectangle { anchors.fill: parent; color: Color.background }

  NumberAnimation {
    id: denyFade
    target: lock
    property: "denied"
    from: 1
    to: 0
    duration: 1400
  }

  // What this machine is. Most of it comes from /proc and /sys; the model
  // names, display and disk come from one fastfetch run when the screen locks.
  Item {
    id: sys
    visible: false

    property string osName: ""
    property string kernel: ""
    property string cpuModel: ""
    property string hostModel: ""
    property string wm: ""
    property string display: ""
    property string disk: ""
    property string gpuName: ""
    property real uptimeSeconds: 0
    property real memUsedGb: 0
    property real memTotalGb: 0
    property var cores: []
    property real cpuLoad: 0
    property int cpuMhz: 0
    property int cpuTemp: -1
    property int gpuMhz: -1
    property int gpuBusy: -1
    property int gpuTemp: -1
    property string cpuTempPath: ""
    property string gpuTempPath: ""
    property string gpuMhzPath: ""
    property string gpuBusyPath: ""
    property var prevTotal: []
    property var prevIdle: []

    readonly property string uptime: {
      var s = uptimeSeconds
      var d = Math.floor(s / 86400), h = Math.floor((s % 86400) / 3600), m = Math.floor((s % 3600) / 60)
      return (d > 0 ? d + "D " : "") + h + "H " + m + "M"
    }

    function sample() {
      stat.reload(); cpuinfo.reload(); meminfo.reload(); uptimeFile.reload()
      if (cpuTempPath) cpuTempFile.reload()
      if (gpuTempPath) gpuTempFile.reload()
      if (gpuMhzPath) gpuMhzFile.reload()
      if (gpuBusyPath) gpuBusyFile.reload()
    }

    FileView {
      id: stat
      path: "/proc/stat"
      printErrors: false
      onLoaded: {
        var pt = sys.prevTotal.slice(), pi = sys.prevIdle.slice(), out = []
        var lines = String(text()).split("\n")
        for (var i = 0; i < lines.length; i++) {
          var m = /^cpu(\d+)\s+(.*)$/.exec(lines[i])
          if (!m) continue
          var n = parseInt(m[1])
          var f = m[2].split(/\s+/).slice(0, 8).map(Number)
          var total = f.reduce(function(a, b) { return a + b }, 0)
          var idle = f[3] + (f[4] || 0)
          out[n] = (pt[n] !== undefined && total > pt[n]) ? Math.max(0, Math.min(1, 1 - (idle - pi[n]) / (total - pt[n]))) : 0
          pt[n] = total
          pi[n] = idle
        }
        sys.prevTotal = pt
        sys.prevIdle = pi
        sys.cores = out
        var sum = 0
        for (var c = 0; c < out.length; c++) sum += out[c]
        sys.cpuLoad = out.length > 0 ? sum / out.length : 0
      }
    }
    FileView {
      id: cpuinfo
      path: "/proc/cpuinfo"
      printErrors: false
      onLoaded: {
        var t = String(text())
        if (sys.cpuModel === "") {
          var model = /model name\s*:\s*(.+)/.exec(t)
          if (model) sys.cpuModel = model[1].replace(/\(R\)|\(TM\)| CPU|@.*$/g, "").replace(/\s+/g, " ").trim()
        }
        var mhz = t.match(/cpu MHz\s*:\s*[\d.]+/g)
        if (mhz && mhz.length > 0) {
          var s = 0
          mhz.forEach(function(l) { s += parseFloat(l.split(":")[1]) })
          sys.cpuMhz = Math.round(s / mhz.length)
        }
      }
    }
    FileView {
      id: meminfo
      path: "/proc/meminfo"
      printErrors: false
      onLoaded: {
        var total = 0, avail = 0
        String(text()).split("\n").forEach(function(l) {
          if (l.indexOf("MemTotal:") === 0) total = parseInt(l.replace(/\D+/g, ""))
          if (l.indexOf("MemAvailable:") === 0) avail = parseInt(l.replace(/\D+/g, ""))
        })
        sys.memTotalGb = total / 1048576
        sys.memUsedGb = (total - avail) / 1048576
      }
    }
    FileView {
      id: uptimeFile
      path: "/proc/uptime"
      printErrors: false
      onLoaded: sys.uptimeSeconds = parseFloat(String(text()).split(" ")[0]) || 0
    }
    FileView {
      path: "/proc/sys/kernel/osrelease"
      printErrors: false
      onLoaded: sys.kernel = String(text()).trim()
    }
    FileView {
      path: "/etc/os-release"
      printErrors: false
      onLoaded: {
        var m = /^PRETTY_NAME="?([^"\n]+)"?/m.exec(String(text()))
        if (m) sys.osName = m[1]
      }
    }
    CappedFile {
      id: cpuTempFile
      maxBytes: 4096
      path: sys.cpuTempPath
      onLoaded: sys.cpuTemp = Math.round(parseInt(text()) / 1000)
    }
    CappedFile {
      id: gpuTempFile
      maxBytes: 4096
      path: sys.gpuTempPath
      onLoaded: sys.gpuTemp = Math.round(parseInt(text()) / 1000)
    }
    CappedFile {
      id: gpuMhzFile
      maxBytes: 4096
      path: sys.gpuMhzPath
      onLoaded: sys.gpuMhz = parseInt(text())
    }
    CappedFile {
      id: gpuBusyFile
      maxBytes: 4096
      path: sys.gpuBusyPath
      onLoaded: sys.gpuBusy = parseInt(text())
    }

    // The sensor files are read through CappedFile (a child process, regular files
    // only, a byte cap) because their paths are found at run time.

    // Which sensors this machine has: CPU and GPU temperature, and the GPU
    // clock or load where the driver exposes one.
    Process {
      running: true
      command: ["sh", "-c",
        "for h in /sys/class/hwmon/hwmon*; do case $(cat $h/name 2>/dev/null) in "
        + "coretemp|k10temp|zenpower) echo cputemp $h/temp1_input;; amdgpu|nouveau) echo gputemp $h/temp1_input;; esac; done; "
        + "for c in /sys/class/drm/card[0-9]; do "
        + "[ -r $c/gt_cur_freq_mhz ] && echo gpumhz $c/gt_cur_freq_mhz; "
        + "[ -r $c/device/gpu_busy_percent ] && echo gpubusy $c/device/gpu_busy_percent; done; true"]
      stdout: StdioCollector {
        waitForEnd: true
        onStreamFinished: {
          String(text).split("\n").forEach(function(l) {
            var p = l.trim().split(" ")
            if (p.length !== 2) return
            if (p[0] === "cputemp") sys.cpuTempPath = p[1]
            else if (p[0] === "gputemp") sys.gpuTempPath = p[1]
            else if (p[0] === "gpumhz") sys.gpuMhzPath = p[1]
            else if (p[0] === "gpubusy") sys.gpuBusyPath = p[1]
          })
        }
      }
    }

    // One run of fastfetch for the names /proc does not give. Without it the
    // lines it fills simply read UNKNOWN.
    Process {
      running: true
      command: ["fastfetch", "--format", "json", "-s", "Host:WM:Display:Disk:GPU"]
      stdout: StdioCollector {
        waitForEnd: true
        onStreamFinished: {
          try {
            JSON.parse(String(text)).forEach(function(m) {
              var r = m.result
              if (m.type === "Host" && r) sys.hostModel = r.name || r.family || ""
              else if (m.type === "WM" && r) sys.wm = r.prettyName || r.processName || ""
              else if (m.type === "Display" && r && r.length > 0) {
                var o = r[0].output
                sys.display = o.width + "X" + o.height + " @ " + Math.round(o.refreshRate) + "HZ"
              } else if (m.type === "Disk" && r && r.length > 0) {
                var b = r[0].bytes
                sys.disk = Math.round(b.used / 1073741824) + " / " + Math.round(b.total / 1073741824) + " GB"
              } else if (m.type === "GPU" && r && r.length > 0)
                sys.gpuName = (r[0].name || "") + (r[0].driver ? " (" + r[0].driver + ")" : "")
            })
          } catch (e) {}
        }
      }
    }

    Timer {
      interval: 2000
      repeat: true
      running: lock.animating
      triggeredOnStart: true
      onTriggered: sys.sample()
    }
  }

  // Everything that never changes while the screen is up: the wallpaper,
  // tinted and darkened, the shading behind the text and the grid. Cached in
  // one layer, so each frame draws a single texture.
  Item {
    id: backdrop
    anchors.fill: parent
    layer.enabled: true

    Wallpaper {
      anchors.fill: parent
      lock: lock
      blur: 0
      dim: 0
      vignette: false
      layer.enabled: true
      layer.effect: MultiEffect {
        colorization: 1.0
        colorizationColor: Qt.rgba(1, 0, 0, 1)
        brightness: 0.25
        contrast: 0.2
      }
    }

      // Keeps the white readout legible on a bright wallpaper.
      Rectangle {
        width: parent.width * 0.4
        height: parent.height
        gradient: Gradient {
          orientation: Gradient.Horizontal
          GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0.5) }
          GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0) }
        }
      }
      Rectangle {
        x: parent.width * 0.6
        width: parent.width * 0.4
        height: parent.height
        visible: lock.wide
        gradient: Gradient {
          orientation: Gradient.Horizontal
          GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0) }
          GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.5) }
        }
      }

    // Pull the wallpaper down so the red reads against black.
    Rectangle {
      anchors.fill: parent
      color: Qt.rgba(0, 0, 0, 0.3)
    }

      // The grid. Painted once, and again only if the size changes.
      Canvas {
        anchors.fill: parent
        renderTarget: Canvas.FramebufferObject
        renderStrategy: Canvas.Cooperative
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
          var ctx = getContext("2d")
          ctx.clearRect(0, 0, width, height)
          var cell = 64
          var ox = (width % cell) / 2
          var oy = (height % cell) / 2
          ctx.lineWidth = 1
          for (var i = 0, x = ox; x <= width; i++, x += cell) {
            ctx.strokeStyle = i % 4 === 0 ? "rgba(255, 40, 30, 0.6)" : "rgba(255, 40, 30, 0.3)"
            ctx.beginPath(); ctx.moveTo(Math.round(x) + 0.5, 0); ctx.lineTo(Math.round(x) + 0.5, height); ctx.stroke()
          }
          for (var j = 0, y = oy; y <= height; j++, y += cell) {
            ctx.strokeStyle = j % 4 === 0 ? "rgba(255, 40, 30, 0.6)" : "rgba(255, 40, 30, 0.3)"
            ctx.beginPath(); ctx.moveTo(0, Math.round(y) + 0.5); ctx.lineTo(width, Math.round(y) + 0.5); ctx.stroke()
          }
        }
      }

  }


  Item {
    id: hud
    anchors.fill: parent

    // How far the target box stands off the field.
    property real pad: 44 - lock.lockOn * 30
    Behavior on pad { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

    // Newest last; typing and failures write here.
    property var log: ["SYSTEM ONLINE", "AWAITING INPUT"]
    // When each log entry was written (ms), so new lines type out.
    property var born: [-1e9, -1e9]

    property bool blink: true
    // Bumped while the newest log line is still typing.
    property int typeTick: 0
    property bool typingOut: false

    readonly property real x0: field.x - pad
    readonly property real y0: field.y - pad * 0.6
    readonly property real x1: field.x + field.width + pad
    readonly property real y1: field.y + field.height + pad * 0.6
    readonly property real arm: 26

    function note(text) {
      var list = log.slice(-6)
      var times = born.slice(-6)
      list.push(text)
      times.push(Date.now())
      log = list
      born = times
      typingOut = true
    }

    function clip(s, n) {
      s = String(s || "UNKNOWN").toUpperCase()
      return s.length > n ? s.substring(0, n - 1) + "…" : s
    }

    function logLine(index, tick) {
      var text = log[index]
      var shown = Math.max(0, Math.floor((Date.now() - born[index]) / 25))
      var newest = index === log.length - 1
      var full = shown >= text.length
      return "> " + text.substring(0, shown) + (newest && (!full || blink) ? "█" : "")
    }

    Timer {
      interval: 500
      repeat: true
      running: lock.animating
      onTriggered: hud.blink = !hud.blink
    }

    // Only runs while a line is being typed.
    Timer {
      interval: 30
      repeat: true
      running: lock.animating && hud.typingOut
      onTriggered: {
        hud.typeTick++
        var last = hud.log.length - 1
        if (Date.now() - hud.born[last] >= hud.log[last].length * 25) hud.typingOut = false
      }
    }

    // Red wash that thickens on a wrong password.
    Rectangle {
      anchors.fill: parent
      visible: lock.denied > 0.02
      color: Qt.rgba(lock.red.r, lock.red.g, lock.red.b, lock.denied * 0.18)
    }

    // Header bar.
    Text {
      x: 28
      y: 18
      text: "CYBERDYNE SYSTEMS   MODEL 101   VISION 2.4"
      color: "white"
      font.family: lock.face
      font.pixelSize: Math.round(lock.fs * 0.75)
      font.bold: true
    }
    Rectangle {
      x: 28
      y: 18 + Math.round(lock.fs * 1.1)
      width: parent.width - 56
      height: 1
      color: lock.withAlpha(lock.red, 0.7)
    }
    Text {
      anchors.right: parent.right
      anchors.rightMargin: 28
      y: 18
      text: lock.hostName.toUpperCase() + "   " + lock.date("yyyy-MM-dd").toUpperCase() + "   " + lock.date("HH:mm:ss")
      color: "white"
      font.family: lock.face
      font.pixelSize: Math.round(lock.fs * 0.75)
    }

    // Left: the machine, then the subject.
    Spec {
      id: system
      x: 48
      y: 18 + Math.round(lock.fs * 2.2)
      width: lock.blockW
      heading: "SYSTEM"
      rows: [
        ["OS", hud.clip(sys.osName, lock.cols)],
        ["HOST", hud.clip(sys.hostModel, lock.cols)],
        ["KERNEL", hud.clip(sys.kernel, lock.cols)],
        ["UPTIME", sys.uptime],
        ["WM", hud.clip(sys.wm, lock.cols)],
        ["DISPLAY", hud.clip(sys.display, lock.cols)],
        ["DISK", hud.clip(sys.disk, lock.cols)]
      ]
    }
    Spec {
      x: 48
      y: system.y + system.height + lock.fs
      width: lock.blockW
      heading: "SUBJECT"
      rows: [
        ["NAME", hud.clip(lock.displayName, lock.cols)],
        ["THREAT", lock.failedAttempts > 0 ? "ELEVATED" : "NONE"],
        ["ATTEMPTS", String(lock.failedAttempts)],
        ["INPUT", "#".repeat(Math.min(lock.passwordText.length, 12)) + (lock.passwordText.length === 0 ? "-" : "")],
        ["MATCH", Math.round(lock.lockOn * 100) + "%"],
        ["ORDERS", lock.failedAttempts > 1 ? "TERMINATE" : "OBSERVE"]
      ]
    }

    // Right: the hardware, live.
    Spec {
      id: hardware
      visible: lock.wide
      anchors.right: parent.right
      anchors.rightMargin: 48
      y: system.y
      width: lock.blockW
      heading: "HARDWARE"
      rows: {
        var r = [
          ["CPU", hud.clip(sys.cpuModel, lock.cols)],
          ["LOAD", Math.round(sys.cpuLoad * 100) + "%"],
          ["CLOCK", sys.cpuMhz > 0 ? (sys.cpuMhz / 1000).toFixed(2) + " GHZ" : "UNKNOWN"]
        ]
        if (sys.cpuTemp >= 0) r.push(["TEMP", sys.cpuTemp + " C"])
        r.push(["GPU", hud.clip(sys.gpuName, lock.cols)])
        if (sys.gpuBusy >= 0) r.push(["GPU LOAD", sys.gpuBusy + "%"])
        else if (sys.gpuMhz >= 0) r.push(["GPU CLOCK", sys.gpuMhz + " MHZ"])
        if (sys.gpuTemp >= 0) r.push(["GPU TEMP", sys.gpuTemp + " C"])
        r.push(["MEMORY", sys.memUsedGb.toFixed(1) + " / " + sys.memTotalGb.toFixed(0) + " GB  " + Math.round(100 * sys.memUsedGb / Math.max(0.1, sys.memTotalGb)) + "%"])
        return r
      }
    }

    // One bar per core.
    Row {
      visible: lock.wide
      x: hardware.x
      y: hardware.y + hardware.height + lock.fs
      spacing: Math.round(lock.fs * 0.5)
      Repeater {
        model: sys.cores.length
        Item {
          required property int index
          width: Math.round(lock.fs * 1.1)
          height: Math.round(lock.fs * 2.6)
          Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.width: 1
            border.color: lock.withAlpha(lock.red, 0.7)
          }
          Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 2
            height: Math.max(1, (parent.height - 4) * (sys.cores[index] || 0))
            color: "white"
            Behavior on height { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
          }
        }
      }
    }

    // Event log, bottom right. New lines type out, and a block cursor blinks
    // after the last one.
    Repeater {
      model: hud.log.length
      Text {
        required property int index
        readonly property int age: hud.log.length - 1 - index
        readonly property int size: Math.max(12, Math.round(lock.fs * 0.55))
        anchors.right: hud.right
        anchors.rightMargin: 48
        y: hud.height - 56 - age * (size + 6) - size
        text: hud.logLine(index, hud.typeTick)
        color: lock.withAlpha(Qt.rgba(1, 1, 1, 1), Math.max(0.4, 1 - age * 0.12))
        font.family: lock.face
        font.pixelSize: size
      }
    }

    // Shell prompt, bottom left. One star per key, never the password itself.
    Text {
      x: 48
      y: hud.height - 40 - Math.round(lock.fs * 0.8)
      text: "root@" + lock.hostName.toLowerCase().substring(0, 14) + ":~# auth --user " + lock.displayName.toLowerCase().substring(0, 12)
        + " " + "*".repeat(Math.min(lock.passwordText.length, 24)) + (hud.blink ? "█" : "")
      color: "white"
      font.family: lock.face
      font.pixelSize: Math.round(lock.fs * 0.8)
    }

    // Target box around the field.
    Bracket { x: hud.x0; y: hud.y0 }
    Bracket { x: hud.x1 - hud.arm; y: hud.y0; atRight: true }
    Bracket { x: hud.x0; y: hud.y1 - hud.arm; atBottom: true }
    Bracket { x: hud.x1 - hud.arm; y: hud.y1 - hud.arm; atRight: true; atBottom: true }

    // Label hanging off the target box.
    Text {
      x: hud.x0
      y: hud.y0 - 10 - Math.round(lock.fs * 0.8)
      text: lock.passwordText.length === 0 ? "TARGET: AWAITING" : "TARGET: LOCKING " + Math.round(lock.lockOn * 100) + "%"
      color: "white"
      font.family: lock.face
      font.pixelSize: Math.round(lock.fs * 0.8)
      font.bold: true
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      y: hud.height * 0.2 - font.pixelSize * 0.8
      visible: lock.denied > 0.02
      opacity: Math.min(1, lock.denied * 1.4)
      text: "ACCESS DENIED"
      color: lock.red
      font.family: lock.face
      font.pixelSize: Math.round(Math.min(hud.width * 0.08, 96))
      font.bold: true
    }
  }

  // Characters of value text that fit in a readout block.
  readonly property int cols: Math.max(12, Math.floor(lock.blockW / (lock.fs * lock.cw)) - 10)

  // One block of readout: a heading, a rule and key/value rows. Keys in
  // dimmer white, values in full white.
  component Spec: Item {
    id: spec
    property string heading: ""
    property var rows: []
    readonly property real lineH: Math.round(lock.fs * 1.45)
    readonly property real headH: Math.round(lock.fs * 1.6)
    // Same value column in every block.
    readonly property real keyW: Math.round(lock.fs * lock.cw * 11)
    height: headH + rows.length * lineH

    Text {
      text: spec.heading
      color: "white"
      font.family: lock.face
      font.pixelSize: Math.round(lock.fs * 0.8)
      font.bold: true
      font.letterSpacing: 3
    }
    // A row of stars under the heading, like the film's readout.
    Text {
      y: spec.headH - Math.round(lock.fs * 0.55)
      text: "*".repeat(Math.floor(spec.width / (lock.fs * 0.5 * lock.cw)))
      color: "white"
      font.family: lock.face
      font.pixelSize: Math.round(lock.fs * 0.5)
    }
    Text {
      id: keys
      y: spec.headH
      lineHeightMode: Text.FixedHeight
      lineHeight: spec.lineH
      text: spec.rows.map(function(r) { return r[0] }).join("\n")
      color: lock.withAlpha(Qt.rgba(1, 1, 1, 1), 0.72)
      font.family: lock.face
      font.pixelSize: lock.fs
    }
    Text {
      x: spec.keyW
      y: spec.headH
      lineHeightMode: Text.FixedHeight
      lineHeight: spec.lineH
      text: spec.rows.map(function(r) { return r[1] }).join("\n")
      color: "white"
      font.family: lock.face
      font.pixelSize: lock.fs
    }
  }

  // One corner of the target box: two arms meeting at the outer corner.
  component Bracket: Item {
    property bool atRight: false
    property bool atBottom: false
    width: hud.arm
    height: hud.arm
    Rectangle {
      width: parent.width
      height: 2
      y: parent.atBottom ? parent.height - 2 : 0
      color: "white"
    }
    Rectangle {
      width: 2
      height: parent.height
      x: parent.atRight ? parent.width - 2 : 0
      color: "white"
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: { lock.wakeRequested(); lock.forcePasswordFocus() }
    onPositionChanged: lock.wakeRequested()
  }

  Typing {
    id: typing
    lock: lock
    onTyped: function(index) { hud.note("KEY " + (index + 1) + " REGISTERED") }
    onDeleted: hud.note("KEY REMOVED")
    onCleared: hud.note("INPUT PURGED")
  }

  Connections {
    target: lock
    function onFailureMessageChanged() {
      if (lock.failureMessage.length > 0) { denyFade.restart(); hud.note("PASSWORD MISMATCH") }
    }
  }

  Column {
    anchors.centerIn: parent
    anchors.verticalCenterOffset: -Math.round(lock.height * 0.1)
    spacing: 4
    opacity: lock.snapshotMode ? 0 : 1

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: lock.clock("HH:mm")
      color: "white"
      font.family: lock.face
      font.pixelSize: Math.round(Style.font.baseSize * 8 * lock.faceScale)
      font.weight: Font.Bold
      font.letterSpacing: 6
    }
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: lock.date("dddd d MMMM").toUpperCase()
      color: "white"
      font.family: lock.face
      font.pixelSize: Style.font.heading
      font.letterSpacing: 4
    }
  }

  PasswordField {
    id: field
    lock: lock
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
    anchors.verticalCenterOffset: Math.round(lock.height * 0.14)
    width: 360
    height: 52
    radius: 2
    showLockGlyph: false
    color: lock.withAlpha(Color.lock.background, 0.7)
    placeholder: lock.tr("ENTER PASSWORD")
  }

  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    y: hud.y1 + 16
    opacity: lock.snapshotMode ? 0 : 1
    text: lock.failedAttempts > 0
      ? lock.tr(lock.failedAttempts === 1 ? "1 failed attempt" : "%1 failed attempts").arg(lock.failedAttempts)
      : (lock.fingerprintConfigured ? lock.fingerprintHint(lock.tr("Touch the sensor or press Enter")) : lock.tr("Press Enter to unlock"))
    textFormat: Text.PlainText
    color: lock.failedAttempts > 0 ? Color.lock.textError : "white"
    font.family: lock.face
    font.pixelSize: Style.font.bodySmall
    font.letterSpacing: 2
  }
}
