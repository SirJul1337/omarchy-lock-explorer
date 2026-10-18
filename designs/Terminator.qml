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
      "VISUAL MODE 2", "RANGE 4.1M", "ANALYZING", "NO MATCH", "POWER 100%", "SEARCH", "CPU 6502"
    ]

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

      // Red wash that thickens on a wrong password.
      ctx.fillStyle = Qt.rgba(red.r, red.g, red.b, 0.05 + a * 0.18)
      ctx.fillRect(0, 0, width, height)

      // Scan lines, with one brighter band sweeping down.
      var sweep = (phase * 0.18 % 1) * (height + 160) - 80
      for (var y = 0; y < height; y += 4) {
        var d = Math.abs(y - sweep)
        var glow = d < 80 ? (1 - d / 80) * 0.22 : 0
        ctx.fillStyle = Qt.rgba(red.r, red.g, red.b, 0.05 + glow)
        ctx.fillRect(0, y, width, 1)
      }

      // Readout scrolling up the left edge.
      ctx.font = "13px monospace"
      ctx.fillStyle = Qt.rgba(red.r, red.g, red.b, 0.7)
      var rowH = 22
      var offset = (phase * 24) % rowH
      var first = Math.floor(phase * 24 / rowH)
      for (var i = 0; i < Math.ceil(height / rowH) + 1; i++) {
        var text = lines[(first + i) % lines.length]
        if (i % 3 === 0) ctx.fillText(text, 28, height - i * rowH + offset)
      }

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

  Connections {
    target: lock
    function onFailureMessageChanged() {
      if (lock.failureMessage.length > 0) lock.denied = 1
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
