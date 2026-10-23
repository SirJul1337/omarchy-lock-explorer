import QtQuick
import qs.Commons

// Two proton streams from the bottom corners, each a pair of strands twisting
// round each other, meeting in a white hot knot that throws sparks and arcs.
// It is never quiet: typing pushes the whole thing harder, and a wrong
// password is a full overload that lights up the screen.
DesignBase {
  id: lock
  inputItem: field.input

  // 0..1 extra energy from typing and failures, decays on its own.
  property real surge: 0
  // Whole screen flash on an overload.
  property real flash: 0

  Rectangle { anchors.fill: parent; color: Color.background }

  Canvas {
    id: beams
    anchors.fill: parent

    property real t: 0
    property real lastTime: 0
    property real drive: 0.4
    property var sparks: []
    property real kx: 0
    property real ky: 0

    function step(dt) {
      // Never below a strong idle.
      drive += ((0.4 + lock.surge * 0.6) - drive) * Math.min(1, dt * 6)
      t += dt * (1.2 + drive * 3.5)
      lock.surge = Math.max(0, lock.surge - dt * 0.6)
      lock.flash = Math.max(0, lock.flash - dt * 1.6)

      // Sparks fly off the knot and shed along the streams.
      var list = []
      for (var i = 0; i < sparks.length; i++) {
        var s = sparks[i]
        s.life -= dt * s.fade
        if (s.life <= 0) continue
        s.vy += 260 * dt
        s.x += s.vx * dt
        s.y += s.vy * dt
        list.push(s)
      }
      var births = 3 + Math.round(drive * 14)
      for (var b = 0; b < births && list.length < 260; b++) {
        var a = Math.random() * Math.PI * 2
        var v = 80 + Math.random() * 380 * (0.5 + drive)
        list.push({ x: kx, y: ky, vx: Math.cos(a) * v, vy: Math.sin(a) * v - 120, life: 1, fade: 0.9 + Math.random() * 1.4, hot: Math.random() < 0.5 })
      }
      sparks = list
    }

    // One stream from (x0, y0) to (x1, y1): two strands braided round each
    // other. Each strand is drawn as a wide soft glow under a thin white core.
    function stream(ctx, x0, y0, x1, y1, color, seed) {
      var dx = x1 - x0
      var dy = y1 - y0
      var len = Math.sqrt(dx * dx + dy * dy)
      var nx = -dy / len
      var ny = dx / len
      var amp = 16 + drive * 26
      for (var strand = 0; strand < 2; strand++) {
        var phase = strand * Math.PI
        var passes = [
          { w: 34, a: 0.07, c: color },
          { w: 18, a: 0.16, c: color },
          { w: 8, a: 0.5, c: color },
          { w: 3, a: 0.95, c: Qt.rgba(1, 1, 1, 1) }
        ]
        for (var p = 0; p < passes.length; p++) {
          ctx.strokeStyle = Qt.rgba(passes[p].c.r, passes[p].c.g, passes[p].c.b, passes[p].a)
          ctx.lineWidth = passes[p].w * (0.8 + drive * 0.5)
          ctx.beginPath()
          for (var i = 0; i <= 60; i++) {
            var u = i / 60
            // The braid tightens towards the knot, with a jitter on top.
            var tight = 0.25 + (1 - u) * 0.75
            var w = Math.sin(u * 16 - t * 11 + phase + seed) * amp * tight
            w += Math.sin(u * 47 + t * 17 + seed * 3) * 5 * drive
            var x = x0 + dx * u + nx * w
            var y = y0 + dy * u + ny * w
            if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
          }
          ctx.stroke()
        }
      }
    }

    onPaint: {
      var ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)
      ctx.lineCap = "round"
      ctx.lineJoin = "round"
      var a = Color.lock.borderActive
      var b = Qt.hsla((a.hslHue + 0.08) % 1, Math.max(0.7, a.hslSaturation), 0.6, 1)

      kx = width * (0.5 + Math.sin(t * 0.5) * 0.14 + Math.sin(t * 1.7) * 0.04 * (1 + drive * 2))
      ky = height * (0.36 + Math.sin(t * 0.7 + 1) * 0.07 + Math.sin(t * 2.3) * 0.02 * (1 + drive * 2))

      // Everything adds light to what is already there.
      ctx.globalCompositeOperation = "lighter"

      // Light cast across the whole screen from the knot.
      var wide = Math.max(width, height) * (0.55 + drive * 0.35)
      var wash = ctx.createRadialGradient(kx, ky, 0, kx, ky, wide)
      wash.addColorStop(0, Qt.rgba(a.r, a.g, a.b, 0.22 + drive * 0.2))
      wash.addColorStop(1, Qt.rgba(a.r, a.g, a.b, 0))
      ctx.fillStyle = wash
      ctx.fillRect(0, 0, width, height)

      stream(ctx, width * -0.02, height * 1.04, kx, ky, a, 0)
      stream(ctx, width * 1.02, height * 1.04, kx, ky, b, 3)

      // Rays turning round the knot.
      var radius = Math.min(width, height) * (0.14 + drive * 0.14)
      ctx.lineWidth = 3
      for (var r = 0; r < 14; r++) {
        var ang = t * 1.6 + r * Math.PI * 2 / 14
        var l = radius * (1.1 + 0.9 * Math.abs(Math.sin(t * 3 + r * 1.7))) * (0.8 + drive * 0.7)
        ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.12 + drive * 0.15)
        ctx.beginPath()
        ctx.moveTo(kx, ky)
        ctx.lineTo(kx + Math.cos(ang) * l, ky + Math.sin(ang) * l)
        ctx.stroke()
      }

      // The knot itself.
      var g = ctx.createRadialGradient(kx, ky, 0, kx, ky, radius)
      g.addColorStop(0, "rgba(255,255,255,1)")
      g.addColorStop(0.2, "rgba(255,255,255,0.85)")
      g.addColorStop(0.45, Qt.rgba(a.r, a.g, a.b, 0.6))
      g.addColorStop(1, Qt.rgba(a.r, a.g, a.b, 0))
      ctx.fillStyle = g
      ctx.beginPath(); ctx.arc(kx, ky, radius, 0, Math.PI * 2); ctx.fill()

      // Lightning arcing off in every direction.
      var bolts = 6 + Math.round(drive * 12)
      for (var i = 0; i < bolts; i++) {
        var ba = Math.random() * Math.PI * 2
        var bl = radius * (1.2 + Math.random() * 2.2)
        ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.4 + Math.random() * 0.6)
        ctx.lineWidth = 1 + Math.random() * 2
        ctx.beginPath()
        ctx.moveTo(kx, ky)
        for (var s = 1; s <= 6; s++)
          ctx.lineTo(kx + Math.cos(ba) * bl * s / 6 + (Math.random() - 0.5) * 30, ky + Math.sin(ba) * bl * s / 6 + (Math.random() - 0.5) * 30)
        ctx.stroke()
      }

      // Sparks.
      for (var k = 0; k < sparks.length; k++) {
        var sp = sparks[k]
        var c = sp.hot ? Qt.rgba(1, 1, 1, 1) : a
        ctx.fillStyle = Qt.rgba(c.r, c.g, c.b, sp.life)
        ctx.beginPath(); ctx.arc(sp.x, sp.y, 1 + sp.life * 2.2, 0, Math.PI * 2); ctx.fill()
      }

      // Overload: the whole screen lights up.
      if (lock.flash > 0.01) {
        ctx.fillStyle = Qt.rgba(1, 1, 1, lock.flash * 0.55)
        ctx.fillRect(0, 0, width, height)
      }
      ctx.globalCompositeOperation = "source-over"
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
    onTyped: lock.surge = Math.min(1, lock.surge + 0.3)
    onDeleted: lock.surge = Math.min(1, lock.surge + 0.12)
    onCleared: lock.surge = 1
  }

  Connections {
    target: lock
    function onFailureMessageChanged() {
      if (lock.failureMessage.length > 0) { lock.surge = 1; lock.flash = 1 }
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
