import QtQuick
import qs.Commons

// The motion tracker from Aliens. A sweep goes round the dial and every key
// you press drops a contact that lights up as the sweep passes over it. The
// faster you type, the faster the sweep.
DesignBase {
  id: lock
  inputItem: field.input

  // Briefly 1 after a wrong password, lights up the dial.
  property real flash: 0

  Rectangle { anchors.fill: parent; color: Color.background }

  Canvas {
    id: radar
    anchors.fill: parent

    property real arm: 0
    property real speed: 1.1
    property real lastTime: 0
    property var blips: []

    function add(count, spread) {
      var list = blips.slice(-60)
      for (var i = 0; i < count; i++)
        list.push({ angle: Math.random() * Math.PI * 2, dist: 0.15 + Math.random() * 0.8 * spread })
      blips = list
    }

    function step(dt) {
      var want = 1.1 + Math.min(4, typing.cadence * 0.8)
      speed += (want - speed) * Math.min(1, dt * 3)
      arm = (arm + speed * dt) % (Math.PI * 2)
      lock.flash = Math.max(0, lock.flash - dt * 0.8)
    }

    onPaint: {
      var ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)
      var cx = width / 2
      var cy = height / 2
      var R = Math.min(width, height) * 0.42
      var col = Color.lock.borderActive
      var err = Color.lock.textError
      var tau = Math.PI * 2

      // Dial: rings, cross hairs and range ticks.
      ctx.lineWidth = 1
      ctx.strokeStyle = Qt.rgba(col.r, col.g, col.b, 0.25 + lock.flash * 0.3)
      for (var r = 1; r <= 4; r++) {
        ctx.beginPath(); ctx.arc(cx, cy, R * r / 4, 0, tau); ctx.stroke()
      }
      ctx.beginPath()
      ctx.moveTo(cx - R, cy); ctx.lineTo(cx + R, cy)
      ctx.moveTo(cx, cy - R); ctx.lineTo(cx, cy + R)
      ctx.stroke()
      for (var t = 0; t < 72; t++) {
        var ta = t * tau / 72
        var len = t % 6 === 0 ? 12 : 5
        ctx.beginPath()
        ctx.moveTo(cx + Math.cos(ta) * R, cy + Math.sin(ta) * R)
        ctx.lineTo(cx + Math.cos(ta) * (R - len), cy + Math.sin(ta) * (R - len))
        ctx.stroke()
      }

      // Sweep: a wedge that trails off behind the arm.
      var steps = 28
      for (var s = 0; s < steps; s++) {
        var a0 = arm - s * 0.035
        ctx.fillStyle = Qt.rgba(col.r, col.g, col.b, 0.22 * (1 - s / steps))
        ctx.beginPath()
        ctx.moveTo(cx, cy)
        ctx.arc(cx, cy, R, a0 - 0.035, a0)
        ctx.closePath()
        ctx.fill()
      }
      ctx.strokeStyle = Qt.rgba(col.r, col.g, col.b, 0.9)
      ctx.lineWidth = 2
      ctx.beginPath()
      ctx.moveTo(cx, cy); ctx.lineTo(cx + Math.cos(arm) * R, cy + Math.sin(arm) * R)
      ctx.stroke()

      // Contacts light up when the sweep passes and fade over one lap.
      for (var i = 0; i < blips.length; i++) {
        var b = blips[i]
        var since = ((arm - b.angle) % tau + tau) % tau
        var glow = Math.max(0, 1 - since / tau)
        if (glow < 0.02) continue
        ctx.fillStyle = Qt.rgba(col.r, col.g, col.b, glow)
        var bx = cx + Math.cos(b.angle) * b.dist * R
        var by = cy + Math.sin(b.angle) * b.dist * R
        ctx.beginPath(); ctx.arc(bx, by, 3 + glow * 4, 0, tau); ctx.fill()
      }

      // Range readout.
      ctx.font = "bold 18px monospace"
      ctx.fillStyle = lock.failedAttempts > 0 ? Qt.rgba(err.r, err.g, err.b, 0.9) : Qt.rgba(col.r, col.g, col.b, 0.85)
      var near = 0
      if (blips.length > 0) near = blips[blips.length - 1].dist * 20
      ctx.fillText(blips.length > 0 ? near.toFixed(1) + " M" : "-- M", cx + R * 0.62, cy + R * 0.92)
    }

    Timer {
      interval: 16
      repeat: true
      running: lock.animating
      onTriggered: {
        var now = Date.now()
        var dt = radar.lastTime > 0 ? Math.min(0.1, (now - radar.lastTime) / 1000) : 0.016
        radar.lastTime = now
        radar.step(dt)
        radar.requestPaint()
      }
      onRunningChanged: if (!running) radar.lastTime = 0
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
    onTyped: radar.add(1, 1)
    onDeleted: radar.add(1, 0.5)
    onCleared: radar.add(6, 1)
  }

  Connections {
    target: lock
    function onFailureMessageChanged() {
      if (lock.failureMessage.length > 0) { radar.add(14, 1); lock.flash = 1 }
    }
  }

  Column {
    anchors.centerIn: parent
    anchors.verticalCenterOffset: -Math.round(lock.height * 0.04)
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
    anchors.verticalCenterOffset: Math.round(lock.height * 0.28)
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
