import QtQuick
import qs.Commons

// Bullet time. Shards hang in the air around the clock, turning almost too
// slowly to see. Each key spins them up for a moment and then time stops
// again. A wrong password shatters the ring outward.
DesignBase {
  id: lock
  inputItem: field.input

  // Time scale: close to 0 is frozen, 1 is full speed. Decays back to frozen.
  property real pace: 0
  // Radial blast from a wrong password.
  property real blast: 0

  Rectangle { anchors.fill: parent; color: Color.background }

  Canvas {
    id: shards
    anchors.fill: parent

    property real lastTime: 0
    property var list: []

    Component.onCompleted: {
      var items = []
      for (var i = 0; i < 110; i++) {
        items.push({
          angle: Math.random() * Math.PI * 2,
          ring: 0.55 + Math.random() * 0.7,
          lift: (Math.random() - 0.5) * 0.9,
          rate: 0.5 + Math.random() * 0.9,
          size: 5 + Math.random() * 15,
          spin: Math.random() * Math.PI,
          tint: Math.random() < 0.3
        })
      }
      list = items
    }

    function step(dt) {
      var scale = 0.015 + lock.pace
      for (var i = 0; i < list.length; i++) {
        var s = list[i]
        s.angle += dt * s.rate * scale * 2.4
        s.spin += dt * s.rate * scale * 3
      }
      lock.pace = Math.max(0, lock.pace - dt * 1.4)
      lock.blast = Math.max(0, lock.blast - dt * 1.1)
    }

    function draw(ctx, s, cx, cy, R, front) {
      var depth = Math.sin(s.angle)
      if ((depth >= 0) !== front) return
      var spread = 1 + lock.blast * 1.2
      var x = cx + Math.cos(s.angle) * R * s.ring * spread
      var y = cy + depth * R * s.ring * 0.32 * spread + s.lift * R * 0.55
      var scale = 0.65 + 0.35 * (depth + 1) / 2
      var size = s.size * scale
      var col = s.tint ? Color.lock.borderActive : Color.lock.text
      var alpha = (front ? 0.85 : 0.35) * Math.max(0, 1 - lock.blast * 0.5)

      ctx.save()
      ctx.translate(x, y)
      ctx.rotate(s.spin)
      ctx.fillStyle = Qt.rgba(col.r, col.g, col.b, alpha)
      // A long sliver of glass.
      ctx.beginPath()
      ctx.moveTo(0, -size)
      ctx.lineTo(size * 0.28, 0)
      ctx.lineTo(0, size * 0.6)
      ctx.lineTo(-size * 0.28, 0)
      ctx.closePath()
      ctx.fill()
      ctx.restore()
    }

    onPaint: {
      var ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)
      var cx = width / 2
      var cy = height * 0.46
      var R = Math.min(width * 0.5, height * 0.85) * 0.62

      // Soft light behind the ring.
      var c = Color.lock.borderActive
      var g = ctx.createRadialGradient(cx, cy, 0, cx, cy, R * 1.3)
      g.addColorStop(0, Qt.rgba(c.r, c.g, c.b, 0.12 + lock.pace * 0.1))
      g.addColorStop(1, Qt.rgba(c.r, c.g, c.b, 0))
      ctx.fillStyle = g
      ctx.fillRect(0, 0, width, height)

      for (var i = 0; i < list.length; i++) draw(ctx, list[i], cx, cy, R, false)
      for (var j = 0; j < list.length; j++) draw(ctx, list[j], cx, cy, R, true)
    }

    Timer {
      interval: 16
      repeat: true
      running: lock.animating
      onTriggered: {
        var now = Date.now()
        var dt = shards.lastTime > 0 ? Math.min(0.1, (now - shards.lastTime) / 1000) : 0.016
        shards.lastTime = now
        shards.step(dt)
        shards.requestPaint()
      }
      onRunningChanged: if (!running) shards.lastTime = 0
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
    onTyped: lock.pace = Math.min(1, lock.pace + 0.5)
    onDeleted: lock.pace = Math.min(1, lock.pace + 0.25)
    onCleared: lock.pace = 1
  }

  Connections {
    target: lock
    function onFailureMessageChanged() {
      if (lock.failureMessage.length > 0) { lock.pace = 1; lock.blast = 1 }
    }
  }

  Column {
    anchors.centerIn: parent
    anchors.verticalCenterOffset: -Math.round(lock.height * 0.06)
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
    anchors.verticalCenterOffset: Math.round(lock.height * 0.22)
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
