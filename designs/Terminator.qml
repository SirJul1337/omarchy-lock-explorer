import QtQuick
import qs.Commons

// A machine's view of the lock screen. Red scan lines, readout scrolling past
// and a target box that tightens on the field with every key. A wrong
// password gets stamped ACCESS DENIED.
DesignBase {
  id: lock
  inputItem: field.input

  readonly property color red: Qt.rgba(0.95, 0.14, 0.1, 1)
  // Decays from 1 after a wrong password.
  property real denied: 0
  // 0..1, how closed the target box is around the field.
  readonly property real lockOn: Math.min(1, lock.passwordText.length / 12)

  Rectangle { anchors.fill: parent; color: Color.background }

  Canvas {
    id: hud
    anchors.fill: parent

    property real phase: 0
    property real lastTime: 0
    property real pad: 44
    property var lines: [
      "TARGET ACQUIRED", "SCAN 0x7F3A", "THREAT ASSESSMENT", "MIMIC 98.4%", "LANG: ENG",
      "VISUAL MODE 2", "RANGE 4.1M", "ANALYZING", "NO MATCH", "POWER 100%", "SEARCH",
      "CPU 6502", "BIOS CHECK OK", "MEM 64K", "OPTICS ONLINE", "IR FILTER ON",
      "SUBJECT FOUND", "CHECKING ARMED", "DB QUERY", "PROFILE LOADED", "RESPONSE SET"
    ]
    // Newest last; typing and failures write here.
    property var log: ["SYSTEM ONLINE", "AWAITING INPUT"]

    function note(text) {
      var list = log.slice(-7)
      list.push(text)
      log = list
    }

    function step(dt) {
      phase += dt
      var want = 44 - lock.lockOn * 30
      pad += (want - pad) * Math.min(1, dt * 8)
      lock.denied = Math.max(0, lock.denied - dt * 0.7)
    }

    onPaint: {
      var ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)
      var red = lock.red
      var a = lock.denied
      function tint(alpha) { return Qt.rgba(red.r, red.g, red.b, alpha) }

      // Red wash that thickens on a wrong password.
      ctx.fillStyle = tint(0.05 + a * 0.18)
      ctx.fillRect(0, 0, width, height)

      // Scan lines, with one brighter band sweeping down.
      var sweep = (phase * 0.18 % 1) * (height + 160) - 80
      for (var y = 0; y < height; y += 4) {
        var d = Math.abs(y - sweep)
        var glow = d < 80 ? (1 - d / 80) * 0.22 : 0
        ctx.fillStyle = tint(0.05 + glow)
        ctx.fillRect(0, y, width, 1)
      }

      // Header bar.
      ctx.font = "bold 16px monospace"
      ctx.fillStyle = tint(0.95)
      ctx.fillText("CYBERDYNE SYSTEMS   MODEL 101   VISION 2.4", 28, 36)
      ctx.fillStyle = tint(0.5)
      ctx.fillRect(28, 46, width - 56, 1)
      ctx.font = "13px monospace"
      ctx.textAlign = "right"
      ctx.fillStyle = tint(0.85)
      ctx.fillText(lock.hostName.toUpperCase() + "   " + lock.date("yyyy-MM-dd").toUpperCase() + "   " + lock.date("HH:mm:ss"), width - 28, 36)
      ctx.textAlign = "left"

      // Readout scrolling up the left edge, every row.
      ctx.font = "14px monospace"
      var rowH = 22
      var offset = (phase * 26) % rowH
      var first = Math.floor(phase * 26 / rowH)
      var rows = Math.min(Math.ceil((height - 140) / rowH) + 1, 22)
      for (var i = 0; i < rows; i++) {
        var text = lines[(first + i) % lines.length]
        var yy = height - 60 - i * rowH + offset
        ctx.fillStyle = tint(0.35 + 0.45 * (1 - i / rows))
        ctx.fillText((((first + i) * 37) % 256).toString(16).toUpperCase().padStart(2, "0") + "  " + text, 28, yy)
      }

      // Subject analysis down the right edge. Values flicker like a live feed.
      var rx = width - 330
      var ry = 96
      var flick = Math.floor(phase * 6)
      var entered = lock.passwordText.length
      var info = [
        "SUBJECT ANALYSIS",
        "",
        "NAME     " + lock.displayName.toUpperCase().substring(0, 18),
        "HOST     " + lock.hostName.toUpperCase().substring(0, 18),
        "THREAT   " + (lock.failedAttempts > 0 ? "ELEVATED" : "NONE"),
        "ATTEMPTS " + lock.failedAttempts,
        "INPUT    " + "#".repeat(Math.min(entered, 18)) + (entered === 0 ? "-" : ""),
        "MATCH    " + Math.round(lock.lockOn * 100 + ((flick * 7) % 3)) + "%",
        "HEART    " + (62 + (flick * 5) % 9) + " BPM",
        "VOICE    " + (flick % 4 === 0 ? "SCANNING" : "STANDBY"),
        "RANGE    " + (4.0 + ((flick * 3) % 10) / 10).toFixed(1) + " M"
      ]
      for (var k = 0; k < info.length; k++) {
        ctx.font = (k === 0 ? "bold 16px monospace" : "14px monospace")
        ctx.fillStyle = tint(k === 0 ? 0.95 : 0.8)
        ctx.fillText(info[k], rx, ry + k * 22)
      }

      // Event log, bottom right.
      ctx.font = "13px monospace"
      for (var l = 0; l < log.length; l++) {
        var age = log.length - 1 - l
        ctx.fillStyle = tint(Math.max(0.25, 0.95 - age * 0.12))
        ctx.fillText("> " + log[l], rx, height - 56 - age * 20)
      }

      // Hex stream along the bottom edge.
      ctx.font = "12px monospace"
      ctx.fillStyle = tint(0.4)
      var hex = ""
      for (var h = 0; h < 40; h++) hex += (((Math.floor(phase * 9) + h) * 2654435761 >>> 0) % 256).toString(16).toUpperCase().padStart(2, "0") + " "
      ctx.fillText(hex, 28, height - 20)

      // Target box around the field.
      var f = field.mapToItem(lock, 0, 0)
      var x0 = f.x - pad
      var y0 = f.y - pad * 0.6
      var x1 = f.x + field.width + pad
      var y1 = f.y + field.height + pad * 0.6
      var arm = 26
      ctx.strokeStyle = Qt.rgba(red.r, red.g, red.b, 0.9)
      ctx.lineWidth = 2
      ctx.beginPath()
      ctx.moveTo(x0, y0 + arm); ctx.lineTo(x0, y0); ctx.lineTo(x0 + arm, y0)
      ctx.moveTo(x1 - arm, y0); ctx.lineTo(x1, y0); ctx.lineTo(x1, y0 + arm)
      ctx.moveTo(x1, y1 - arm); ctx.lineTo(x1, y1); ctx.lineTo(x1 - arm, y1)
      ctx.moveTo(x0 + arm, y1); ctx.lineTo(x0, y1); ctx.lineTo(x0, y1 - arm)
      ctx.stroke()

      if (a > 0.02) {
        ctx.font = "bold " + Math.round(Math.min(width * 0.08, 96)) + "px monospace"
        ctx.textAlign = "center"
        ctx.fillStyle = Qt.rgba(red.r, red.g, red.b, Math.min(1, a * 1.4))
        ctx.fillText("ACCESS DENIED", width / 2, height * 0.2)
        ctx.textAlign = "left"
      }

      // Label hanging off the target box.
      ctx.font = "bold 14px monospace"
      ctx.fillStyle = tint(0.95)
      ctx.fillText(entered === 0 ? "TARGET: AWAITING" : "TARGET: LOCKING " + Math.round(lock.lockOn * 100) + "%", x0, y0 - 10)
    }

    Timer {
      interval: 33
      repeat: true
      running: lock.animating
      onTriggered: {
        var now = Date.now()
        var dt = hud.lastTime > 0 ? Math.min(0.1, (now - hud.lastTime) / 1000) : 0.033
        hud.lastTime = now
        hud.step(dt)
        hud.requestPaint()
      }
      onRunningChanged: if (!running) hud.lastTime = 0
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
      if (lock.failureMessage.length > 0) { lock.denied = 1; hud.note("PASSWORD MISMATCH") }
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
      color: lock.red
      font.family: Style.font.family
      font.pixelSize: Math.round(Style.font.baseSize * 8)
      font.weight: Font.Bold
      font.letterSpacing: 6
    }
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: lock.date("dddd d MMMM").toUpperCase()
      color: lock.withAlpha(lock.red, 0.75)
      font.family: Style.font.family
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
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 40
    opacity: lock.snapshotMode ? 0 : 1
    text: lock.failedAttempts > 0
      ? lock.tr(lock.failedAttempts === 1 ? "1 failed attempt" : "%1 failed attempts").arg(lock.failedAttempts)
      : (lock.fingerprintConfigured ? lock.fingerprintHint(lock.tr("Touch the sensor or press Enter")) : lock.tr("Press Enter to unlock"))
    textFormat: Text.PlainText
    color: lock.failedAttempts > 0 ? Color.lock.textError : lock.withAlpha(lock.red, 0.6)
    font.family: Style.font.family
    font.pixelSize: Style.font.bodySmall
    font.letterSpacing: 2
  }
}
