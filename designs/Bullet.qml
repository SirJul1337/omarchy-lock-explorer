import QtQuick
import qs.Commons

// Bullet time. Glass hangs in the air around the clock, turning almost too
// slowly to see, and every key you press fires a bullet across the screen in
// slow motion: you can see the round itself, the shock cone peeling off it,
// the rings of disturbed air in its wake and the shards flung aside as it
// passes. A wrong password is a volley from every side.
DesignBase {
  id: lock
  inputItem: field.input

  // Radial blast from a wrong password.
  property real blast: 0

  Rectangle { anchors.fill: parent; color: Color.background }

  Canvas {
    id: scene
    anchors.fill: parent

    property real lastTime: 0
    property real clockT: 0
    property real quiet: 0
    property var shards: []
    property var bullets: []
    property var rings: []

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
          tint: Math.random() < 0.3,
          dx: 0, dy: 0, dvx: 0, dvy: 0
        })
      }
      shards = items
    }

    function geom() {
      return { cx: width / 2, cy: height * 0.46, R: Math.min(width * 0.5, height * 0.85) * 0.62 }
    }

    // Fire one bullet from a random edge, aimed to pass near the clock.
    function fire() {
      var side = Math.floor(Math.random() * 4)
      var g = geom()
      var tx = g.cx + (Math.random() - 0.5) * g.R * 1.2
      var ty = g.cy + (Math.random() - 0.5) * g.R * 0.7
      var sx
      var sy
      if (side === 0) { sx = -60; sy = Math.random() * height }
      else if (side === 1) { sx = width + 60; sy = Math.random() * height }
      else if (side === 2) { sx = Math.random() * width; sy = -60 }
      else { sx = Math.random() * width; sy = height + 60 }
      var dx = tx - sx
      var dy = ty - sy
      var len = Math.sqrt(dx * dx + dy * dy)
      // Crosses the whole screen in a couple of seconds.
      var v = Math.max(width, height) / 1.9
      var list = bullets.slice(-9)
      list.push({ x: sx, y: sy, vx: dx / len * v, vy: dy / len * v, ang: Math.atan2(dy, dx), since: 0 })
      bullets = list
    }

    function volley(n) {
      for (var i = 0; i < n; i++) fire()
    }

    function place(s, g) {
      var depth = Math.sin(s.angle)
      var spread = 1 + lock.blast * 1.2
      return {
        depth: depth,
        x: g.cx + Math.cos(s.angle) * g.R * s.ring * spread + s.dx,
        y: g.cy + depth * g.R * s.ring * 0.32 * spread + s.lift * g.R * 0.55 + s.dy
      }
    }

    function step(dt) {
      clockT += dt
      // One now and then even when nobody is typing.
      quiet += dt
      if (quiet > 8) { quiet = 0; fire() }
      var g = geom()
      var alive = []
      var newRings = []

      for (var i = 0; i < bullets.length; i++) {
        var b = bullets[i]
        b.x += b.vx * dt
        b.y += b.vy * dt
        b.since += dt * Math.sqrt(b.vx * b.vx + b.vy * b.vy)
        // Leave a ring of disturbed air every so often, flat across the path.
        if (b.since > 38) {
          b.since = 0
          newRings.push({ x: b.x, y: b.y, ang: b.ang, life: 1 })
        }
        if (b.x > -120 && b.x < width + 120 && b.y > -120 && b.y < height + 120) alive.push(b)
      }
      bullets = alive

      var rl = []
      for (var r = 0; r < rings.length; r++) {
        rings[r].life -= dt * 0.7
        if (rings[r].life > 0) rl.push(rings[r])
      }
      rings = rl.concat(newRings).slice(-90)

      // Shards turn very slowly and spring back after being knocked aside.
      for (var k = 0; k < shards.length; k++) {
        var s = shards[k]
        s.angle += dt * s.rate * 0.04
        s.spin += dt * s.rate * 0.1
        var p = place(s, g)
        for (var j = 0; j < bullets.length; j++) {
          var bb = bullets[j]
          var ex = p.x - bb.x
          var ey = p.y - bb.y
          var d2 = ex * ex + ey * ey
          if (d2 < 9000 && d2 > 1) {
            var d = Math.sqrt(d2)
            var push = (1 - d / 95) * 240 * dt
            s.dvx += ex / d * push
            s.dvy += ey / d * push
            s.spin += (1 - d / 95) * dt * 12
          }
        }
        s.dx += s.dvx * dt * 4
        s.dy += s.dvy * dt * 4
        s.dvx *= Math.max(0, 1 - dt * 1.2)
        s.dvy *= Math.max(0, 1 - dt * 1.2)
        s.dx *= Math.max(0, 1 - dt * 0.6)
        s.dy *= Math.max(0, 1 - dt * 0.6)
      }
      lock.blast = Math.max(0, lock.blast - dt * 0.9)
    }

    function drawShard(ctx, s, g, front) {
      var p = place(s, g)
      if ((p.depth >= 0) !== front) return
      var scale = 0.65 + 0.35 * (p.depth + 1) / 2
      var size = s.size * scale
      var col = s.tint ? Color.lock.borderActive : Color.lock.text
      var alpha = (front ? 0.85 : 0.35) * Math.max(0, 1 - lock.blast * 0.5)
      ctx.save()
      ctx.translate(p.x, p.y)
      ctx.rotate(s.spin)
      ctx.fillStyle = Qt.rgba(col.r, col.g, col.b, alpha)
      ctx.beginPath()
      ctx.moveTo(0, -size)
      ctx.lineTo(size * 0.28, 0)
      ctx.lineTo(0, size * 0.6)
      ctx.lineTo(-size * 0.28, 0)
      ctx.closePath()
      ctx.fill()
      ctx.restore()
    }

    function drawBullet(ctx, b, accent, text) {
      var len = 54
      var w = 15
      // Shock cone peeling back from the nose.
      ctx.save()
      ctx.translate(b.x, b.y)
      ctx.rotate(b.ang)
      ctx.lineWidth = 1.5
      ctx.strokeStyle = Qt.rgba(accent.r, accent.g, accent.b, 0.5)
      for (var side = -1; side <= 1; side += 2) {
        ctx.beginPath()
        ctx.moveTo(len * 0.5, 0)
        ctx.lineTo(-len * 1.7, side * len * 1.0)
        ctx.stroke()
      }
      // Faint glow round the round.
      var gl = ctx.createRadialGradient(0, 0, 0, 0, 0, len)
      gl.addColorStop(0, Qt.rgba(accent.r, accent.g, accent.b, 0.35))
      gl.addColorStop(1, Qt.rgba(accent.r, accent.g, accent.b, 0))
      ctx.fillStyle = gl
      ctx.beginPath(); ctx.arc(0, 0, len, 0, Math.PI * 2); ctx.fill()
      // Casing.
      ctx.fillStyle = Qt.rgba(text.r, text.g, text.b, 0.95)
      ctx.beginPath()
      ctx.moveTo(-len * 0.5, -w / 2)
      ctx.lineTo(len * 0.1, -w / 2)
      ctx.quadraticCurveTo(len * 0.55, -w / 2, len * 0.55, 0)
      ctx.quadraticCurveTo(len * 0.55, w / 2, len * 0.1, w / 2)
      ctx.lineTo(-len * 0.5, w / 2)
      ctx.closePath()
      ctx.fill()
      // Tip and a highlight along the top.
      ctx.fillStyle = Qt.rgba(accent.r, accent.g, accent.b, 1)
      ctx.beginPath()
      ctx.moveTo(len * 0.1, -w / 2)
      ctx.quadraticCurveTo(len * 0.55, -w / 2, len * 0.55, 0)
      ctx.quadraticCurveTo(len * 0.55, w / 2, len * 0.1, w / 2)
      ctx.closePath()
      ctx.fill()
      ctx.fillStyle = Qt.rgba(1, 1, 1, 0.55)
      ctx.fillRect(-len * 0.45, -w / 2 + 2, len * 0.5, 2)
      ctx.restore()
    }

    onPaint: {
      var ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)
      var g = geom()
      var accent = Color.lock.borderActive
      var text = Color.lock.text

      // Soft light behind the ring.
      var bg = ctx.createRadialGradient(g.cx, g.cy, 0, g.cx, g.cy, g.R * 1.3)
      bg.addColorStop(0, Qt.rgba(accent.r, accent.g, accent.b, 0.12 + lock.blast * 0.15))
      bg.addColorStop(1, Qt.rgba(accent.r, accent.g, accent.b, 0))
      ctx.fillStyle = bg
      ctx.fillRect(0, 0, width, height)

      for (var i = 0; i < shards.length; i++) drawShard(ctx, shards[i], g, false)

      // Rings of air: ellipses across the path that open up as they fade.
      for (var r = 0; r < rings.length; r++) {
        var ring = rings[r]
        var open = 1 - ring.life
        ctx.save()
        ctx.translate(ring.x, ring.y)
        ctx.rotate(ring.ang)
        ctx.strokeStyle = Qt.rgba(accent.r, accent.g, accent.b, ring.life * 0.55)
        ctx.lineWidth = 1.5
        ctx.beginPath()
        ctx.ellipse(-4 - open * 10, -(10 + open * 46), 8 + open * 4, 20 + open * 92)
        ctx.stroke()
        ctx.restore()
      }

      for (var b = 0; b < bullets.length; b++) drawBullet(ctx, bullets[b], accent, text)
      for (var j = 0; j < shards.length; j++) drawShard(ctx, shards[j], g, true)
    }

    Timer {
      interval: 16
      repeat: true
      running: lock.animating
      onTriggered: {
        var now = Date.now()
        var dt = scene.lastTime > 0 ? Math.min(0.1, (now - scene.lastTime) / 1000) : 0.016
        scene.lastTime = now
        scene.step(dt)
        scene.requestPaint()
      }
      onRunningChanged: if (!running) scene.lastTime = 0
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
    onTyped: scene.fire()
    onDeleted: scene.fire()
    onCleared: scene.volley(4)
  }

  Connections {
    target: lock
    function onFailureMessageChanged() {
      if (lock.failureMessage.length > 0) { lock.blast = 1; scene.volley(6) }
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
