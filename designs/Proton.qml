import QtQuick
import qs.Commons

// Two proton streams from the bottom corners, crossing in a crackling knot.
// The knot wanders, wilder the faster you type. A wrong password is a surge.
DesignBase {
  id: lock
  inputItem: field.input

  // 0..1 extra energy from typing and failures, decays on its own.
  property real surge: 0

  Rectangle { anchors.fill: parent; color: Color.background }

  Canvas {
    id: beams
    anchors.fill: parent

    property real t: 0
    property real lastTime: 0
    property real drive: 0

    function step(dt) {
      drive += (lock.surge - drive) * Math.min(1, dt * 6)
      t += dt * (0.6 + drive * 3.5)
      lock.surge = Math.max(0, lock.surge - dt * 0.7)
    }

    // One wobbling stream from (x0, y0) to (x1, y1): a few passes, widest and
    // faintest first, so it glows.
    function stream(ctx, x0, y0, x1, y1, color, seed) {
      var dx = x1 - x0
      var dy = y1 - y0
      var len = Math.sqrt(dx * dx + dy * dy)
      var nx = -dy / len
      var ny = dx / len
      var widths = [22, 12, 5, 2]
      var alphas = [0.07, 0.14, 0.4, 0.95]
      for (var p = 0; p < widths.length; p++) {
        ctx.strokeStyle = Qt.rgba(color.r, color.g, color.b, alphas[p] * (0.7 + drive * 0.3))
        ctx.lineWidth = widths[p]
        ctx.lineCap = "round"
        ctx.beginPath()
        for (var i = 0; i <= 40; i++) {
          var u = i / 40
          // Wobble grows towards the knot.
          var w = Math.sin(u * 14 + t * 9 + seed) * 7 + Math.sin(u * 31 - t * 13 + seed * 2) * 4
          w *= (0.4 + u) * (1 + drive * 1.5)
          var x = x0 + dx * u + nx * w
          var y = y0 + dy * u + ny * w
          if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
        }
        ctx.stroke()
      }
    }

    onPaint: {
      var ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)
      var a = Color.lock.borderActive
      var b = Qt.hsla((a.hslHue + 0.1) % 1, Math.max(0.5, a.hslSaturation), 0.6, 1)

      // The knot wanders on two slow cycles.
      var kx = width * (0.5 + Math.sin(t * 0.9) * 0.12 + Math.sin(t * 2.3) * 0.04 * (1 + drive * 2))
      var ky = height * (0.34 + Math.sin(t * 1.3 + 1) * 0.06 + Math.sin(t * 3.1) * 0.02 * (1 + drive * 2))

      stream(ctx, width * 0.02, height * 1.02, kx, ky, a, 0)
      stream(ctx, width * 0.98, height * 1.02, kx, ky, b, 3)

      // Glow at the crossing.
      var radius = Math.min(width, height) * (0.12 + drive * 0.12)
      var g = ctx.createRadialGradient(kx, ky, 0, kx, ky, radius)
      g.addColorStop(0, "rgba(255,255,255," + (0.85).toFixed(2) + ")")
      g.addColorStop(0.25, Qt.rgba(a.r, a.g, a.b, 0.5))
      g.addColorStop(1, Qt.rgba(a.r, a.g, a.b, 0))
      ctx.fillStyle = g
      ctx.beginPath(); ctx.arc(kx, ky, radius, 0, Math.PI * 2); ctx.fill()

      // Crackle: short bright bolts flying off the knot.
      ctx.lineWidth = 1.5
      var bolts = 5 + Math.round(drive * 10)
      for (var i = 0; i < bolts; i++) {
        var ang = Math.random() * Math.PI * 2
        var l = radius * (0.5 + Math.random() * 1.1)
        ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.3 + Math.random() * 0.6)
        ctx.beginPath()
        ctx.moveTo(kx, ky)
        var px = kx
        var py = ky
        for (var s = 1; s <= 4; s++) {
          px = kx + Math.cos(ang) * l * s / 4 + (Math.random() - 0.5) * 14
          py = ky + Math.sin(ang) * l * s / 4 + (Math.random() - 0.5) * 14
          ctx.lineTo(px, py)
        }
        ctx.stroke()
      }
    }

    Timer {
      interval: 16
      repeat: true
      running: lock.animating
      onTriggered: {
        var now = Date.now()
        var dt = beams.lastTime > 0 ? Math.min(0.1, (now - beams.lastTime) / 1000) : 0.016
        beams.lastTime = now
        beams.step(dt)
        beams.requestPaint()
      }
      onRunningChanged: if (!running) beams.lastTime = 0
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
    onTyped: lock.surge = Math.min(1, lock.surge + 0.25)
    onDeleted: lock.surge = Math.min(1, lock.surge + 0.1)
    onCleared: lock.surge = 1
  }

  Connections {
    target: lock
    function onFailureMessageChanged() {
      if (lock.failureMessage.length > 0) lock.surge = 1
    }
  }

  Column {
    anchors.centerIn: parent
    anchors.verticalCenterOffset: -Math.round(lock.height * 0.1)
    spacing: 6
    opacity: lock.snapshotMode ? 0 : 1

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: lock.clock("HH:mm")
      color: Color.lock.text
      font.family: Style.font.family
      font.pixelSize: Math.round(Style.font.baseSize * 9)
      font.weight: Font.Light
      font.letterSpacing: 4
    }
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: lock.date("dddd, d MMMM")
      color: lock.withAlpha(Color.lock.text, 0.7)
      font.family: Style.font.family
      font.pixelSize: Style.font.heading
      font.letterSpacing: 2
    }
  }

  PasswordField {
    id: field
    lock: lock
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
    anchors.verticalCenterOffset: Math.round(lock.height * 0.2)
    width: 380
    height: 56
    radius: 28
    showLockGlyph: false
    color: lock.withAlpha(Color.lock.background, 0.55)
    placeholder: lock.greeting() + ", " + lock.displayName
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
    color: lock.failedAttempts > 0 ? Color.lock.textError : lock.withAlpha(Color.lock.text, 0.45)
    font.family: Style.font.family
    font.pixelSize: Style.font.bodySmall
    font.letterSpacing: 2
  }
}
