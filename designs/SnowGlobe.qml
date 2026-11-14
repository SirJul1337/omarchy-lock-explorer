import QtQuick
import QtQuick.Effects
import qs.Commons
import qs.Commons as Commons

// Snow Globe: the time inside a glass globe on a wooden base, over a little
// winter village of pines and a cottage with its window lit. The snow inside
// settles on the ground; every key gives the globe a little shake and stirs
// it up again, and a wrong password rocks the globe on its base and whips up
// a blizzard. A seasonal design, so it keeps its own palette instead of the
// theme's.
DesignBase {
  id: lock
  inputItem: field.input
  shakeOnFail: false
  flashOnFail: false

  readonly property color ember: "#2a160e"
  readonly property color room: "#0c0705"
  readonly property color cream: "#fff2e2"
  readonly property color brass: "#e2b866"
  readonly property color cherry: "#ff5a48"
  readonly property color snow: "#f6f9ff"
  readonly property color white: "#ffffff"
  readonly property color glassTint: "#bcd6ff"
  readonly property color windowGlow: "#ffc861"

  // The globe's radius, and the base it stands on.
  readonly property real globeR: Math.round(Math.min(height * 0.26, width * 0.2))
  readonly property real baseH: Math.round(globeR * 0.42)

  // Flakes in globe coordinates (0..2R): falling, or resting on the ground.
  property var flakes: []
  property real stir: 0        // how hard it has been shaken, decays
  property real wobble: 0      // 0..1, the globe rocking on a wrong password
  property real elapsed: 0
  property real lastTick: 0

  function rng(seed) {
    var s = seed >>> 0
    return function() {
      s = (s + 0x6D2B79F5) >>> 0
      var t = s
      t = Math.imul(t ^ (t >>> 15), t | 1)
      t ^= t + Math.imul(t ^ (t >>> 7), t | 61)
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296
    }
  }

  // The top of the snowy ground inside the globe, a low mound.
  function groundY(x) {
    var R = globeR
    var u = (x - R) / (R * 0.95)
    return R + R * 0.62 - R * 0.12 * Math.max(0, 1 - u * u)
  }

  // A fresh lock comes up just shaken: the snow is all in the air.
  function resetSnow() {
    var R = globeR
    if (R <= 0) return
    var r = rng(2512)
    var f = []
    for (var i = 0; i < 170; i++) {
      var a = r() * 6.2832, d = Math.sqrt(r()) * (R - 14)
      var x = R + Math.cos(a) * d, y = R + Math.sin(a) * d
      if (y > groundY(x) - 2) y = groundY(x) - 2 - r() * R * 0.5
      f.push({ x: x, y: y, vx: 0, vy: 0, size: 1.3 + r() * 2.1, rest: false,
               drift: 0.6 + r() * 0.8, phase: r() * 6.28 })
    }
    flakes = f
  }

  // A key: a little shake. A wrong password: a big one, and the rocking.
  function shake(amount) {
    stir = Math.min(1.4, stir + amount)
    var f = flakes
    for (var i = 0; i < f.length; i++) {
      var o = f[i]
      if (o.rest && Math.random() < amount * 2.2) o.rest = false
      if (!o.rest) {
        o.vx += (Math.random() - 0.5) * 560 * amount
        o.vy -= (140 + Math.random() * 460) * amount
      }
    }
  }

  onGlobeRChanged: resetSnow()
  Component.onCompleted: resetSnow()

  Typing {
    lock: lock
    onTyped: lock.shake(0.16)
    onCleared: lock.shake(0.3)
  }

  Connections {
    target: lock
    function onFailureMessageChanged() {
      if (lock.failureMessage.length > 0) { lock.wobble = 1; lock.shake(1) }
    }
  }

  // A dark room with the fire somewhere behind you.
  Rectangle { anchors.fill: parent; color: lock.room }
  Rectangle {
    anchors.fill: parent
    gradient: Gradient {
      GradientStop { position: 0.0; color: "#05070d" }
      GradientStop { position: 0.55; color: lock.room }
      GradientStop { position: 1.0; color: lock.ember }
    }
  }
  Canvas {
    id: fireside
    anchors.fill: parent
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      ctx.clearRect(0, 0, width, height)
      var g = ctx.createRadialGradient(width / 2, globe.y + globe.height * 0.5, 0, width / 2, globe.y + globe.height * 0.5, height * 0.75)
      g.addColorStop(0, "rgba(255, 150, 70, 0.20)")
      g.addColorStop(0.5, "rgba(255, 120, 50, 0.06)")
      g.addColorStop(1, "rgba(0, 0, 0, 0)")
      ctx.fillStyle = g
      ctx.fillRect(0, 0, width, height)
      // A soft shadow under the base, on the table.
      var sy = globe.y + globe.height
      var s = ctx.createRadialGradient(width / 2, sy, 0, width / 2, sy, lock.globeR * 1.3)
      s.addColorStop(0, "rgba(0, 0, 0, 0.6)")
      s.addColorStop(1, "rgba(0, 0, 0, 0)")
      ctx.save()
      ctx.translate(width / 2, sy)
      ctx.scale(1, 0.16)
      ctx.translate(-width / 2, -sy)
      ctx.fillStyle = s
      ctx.fillRect(width / 2 - lock.globeR * 1.4, sy - lock.globeR * 1.4, lock.globeR * 2.8, lock.globeR * 2.8)
      ctx.restore()
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: { lock.wakeRequested(); lock.forcePasswordFocus() }
    onPositionChanged: lock.wakeRequested()
  }

  Item {
    id: globe
    width: lock.globeR * 2
    height: lock.globeR * 2 + lock.baseH
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
    anchors.verticalCenterOffset: -Math.round(lock.height * 0.07)
    transformOrigin: Item.Bottom
    rotation: Math.sin(lock.elapsed * 11) * 6 * lock.wobble

    // The village and the sky behind it, drawn once.
    Canvas {
      id: village
      anchors.fill: parent
      onWidthChanged: requestPaint()
      onHeightChanged: requestPaint()

      function pine(ctx, x, y, h) {
        var w = h * 0.55
        ctx.fillStyle = "#3a2417"
        ctx.fillRect(x - h * 0.04, y - h * 0.12, h * 0.08, h * 0.14)
        for (var t = 0; t < 3; t++) {
          var top = y - h * (0.35 + t * 0.27) - h * 0.1
          var bottom = y - h * (0.08 + t * 0.26)
          var half = w * (0.5 - t * 0.12)
          ctx.beginPath()
          ctx.moveTo(x, top)
          ctx.lineTo(x + half, bottom)
          ctx.lineTo(x - half, bottom)
          ctx.closePath()
          ctx.fillStyle = t === 0 ? "#173d2b" : (t === 1 ? "#1c4a33" : "#22583c")
          ctx.fill()
          // Snow along each tier's edge.
          ctx.beginPath()
          ctx.moveTo(x, top)
          ctx.lineTo(x + half * 0.55, top + (bottom - top) * 0.55)
          ctx.quadraticCurveTo(x, top + (bottom - top) * 0.7, x - half * 0.55, top + (bottom - top) * 0.55)
          ctx.closePath()
          ctx.fillStyle = "rgba(246, 249, 255, 0.9)"
          ctx.fill()
        }
      }

      onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        ctx.clearRect(0, 0, width, height)
        var R = lock.globeR
        ctx.save()
        ctx.beginPath()
        ctx.arc(R, R, R - 2, 0, 6.2832)
        ctx.clip()
        // Night sky with a few stars.
        var sky = ctx.createLinearGradient(0, 0, 0, R * 2)
        sky.addColorStop(0, "#0e1a36")
        sky.addColorStop(0.6, "#22365e")
        sky.addColorStop(1, "#3d5784")
        ctx.fillStyle = sky
        ctx.fillRect(0, 0, R * 2, R * 2)
        var r = lock.rng(7)
        for (var i = 0; i < 40; i++) {
          var sx = r() * R * 2, sy = r() * R * 1.1
          ctx.beginPath()
          ctx.arc(sx, sy, 0.6 + r() * 1.1, 0, 6.2832)
          ctx.fillStyle = "rgba(255, 255, 255, " + (0.25 + r() * 0.5) + ")"
          ctx.fill()
        }
        // A far hill.
        ctx.beginPath()
        ctx.moveTo(0, R * 1.42)
        ctx.quadraticCurveTo(R * 0.6, R * 1.18, R * 1.2, R * 1.38)
        ctx.quadraticCurveTo(R * 1.6, R * 1.5, R * 2, R * 1.3)
        ctx.lineTo(R * 2, R * 2)
        ctx.lineTo(0, R * 2)
        ctx.closePath()
        ctx.fillStyle = "#9fb3d3"
        ctx.fill()
        // The pines behind the cottage.
        pine(ctx, R * 0.42, lock.groundY(R * 0.42) + 6, R * 0.5)
        pine(ctx, R * 1.52, lock.groundY(R * 1.52) + 6, R * 0.58)
        pine(ctx, R * 1.74, lock.groundY(R * 1.74) + 8, R * 0.38)
        // The cottage, its window lit.
        var hx = R * 0.86, hw = R * 0.42, hh = R * 0.26, hy = lock.groundY(hx + hw / 2) + 4
        var glow = ctx.createRadialGradient(hx + hw * 0.3, hy - hh * 0.5, 0, hx + hw * 0.3, hy - hh * 0.5, R * 0.42)
        glow.addColorStop(0, "rgba(255, 200, 97, 0.35)")
        glow.addColorStop(1, "rgba(255, 200, 97, 0)")
        ctx.fillStyle = glow
        ctx.fillRect(hx - R * 0.5, hy - R * 0.9, R * 1.4, R * 1.2)
        ctx.fillStyle = "#6b3a26"
        ctx.fillRect(hx, hy - hh, hw, hh)
        ctx.fillStyle = "#4a2618"
        ctx.fillRect(hx + hw * 0.66, hy - hh * 0.7, hw * 0.2, hh * 0.7)
        ctx.fillStyle = "#4a2618"
        ctx.fillRect(hx + hw * 0.7, hy - hh - R * 0.2, hw * 0.12, R * 0.14)
        ctx.beginPath()
        ctx.moveTo(hx - hw * 0.12, hy - hh)
        ctx.lineTo(hx + hw / 2, hy - hh - R * 0.2)
        ctx.lineTo(hx + hw * 1.12, hy - hh)
        ctx.closePath()
        ctx.fillStyle = "#f2f6ff"
        ctx.fill()
        ctx.fillStyle = "#ffc861"
        ctx.fillRect(hx + hw * 0.14, hy - hh * 0.72, hw * 0.28, hh * 0.38)
        ctx.strokeStyle = "#6b3a26"
        ctx.lineWidth = 2
        ctx.beginPath()
        ctx.moveTo(hx + hw * 0.28, hy - hh * 0.72)
        ctx.lineTo(hx + hw * 0.28, hy - hh * 0.34)
        ctx.moveTo(hx + hw * 0.14, hy - hh * 0.53)
        ctx.lineTo(hx + hw * 0.42, hy - hh * 0.53)
        ctx.stroke()
        // A small pine in front.
        pine(ctx, R * 0.62, lock.groundY(R * 0.62) + 10, R * 0.3)
        // The snowy ground.
        ctx.beginPath()
        ctx.moveTo(0, lock.groundY(0))
        for (var x = 0; x <= R * 2; x += R / 20) ctx.lineTo(x, lock.groundY(x))
        ctx.lineTo(R * 2, R * 2)
        ctx.lineTo(0, R * 2)
        ctx.closePath()
        var ground = ctx.createLinearGradient(0, R * 1.45, 0, R * 2)
        ground.addColorStop(0, "#ffffff")
        ground.addColorStop(1, "#b9c9e4")
        ctx.fillStyle = ground
        ctx.fill()
        ctx.restore()
      }
    }

    // The time, floating in the sky inside the glass.
    Text {
      x: lock.globeR - width / 2
      y: lock.globeR * 0.5 - height / 2
      text: lock.clock("HH:mm")
      color: lock.cream
      font.family: Style.font.family
      font.pixelSize: Math.round(lock.globeR * 0.38)
      font.weight: Font.Bold
      font.letterSpacing: 1
      layer.enabled: true
      layer.effect: MultiEffect { shadowEnabled: true; shadowColor: lock.windowGlow; shadowBlur: 0.8; shadowOpacity: 0.5; shadowVerticalOffset: 0 }
    }

    // The base, in front of the bottom of the glass that sits in it.
    Canvas {
      id: stand
      anchors.fill: parent
      z: 1
      onWidthChanged: requestPaint()
      onHeightChanged: requestPaint()
      onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        ctx.clearRect(0, 0, width, height)
        var R = lock.globeR
        // Dark wood with a brass band, the glass standing a little into it.
        var top = R * 2 - R * 0.14
        var bh = lock.baseH + R * 0.14
        ctx.beginPath()
        ctx.moveTo(R - R * 0.74, top)
        ctx.lineTo(R + R * 0.74, top)
        ctx.lineTo(R + R * 0.92, top + bh)
        ctx.lineTo(R - R * 0.92, top + bh)
        ctx.closePath()
        var wood = ctx.createLinearGradient(0, top, 0, top + bh)
        wood.addColorStop(0, "#6a3a22")
        wood.addColorStop(0.5, "#4a2716")
        wood.addColorStop(1, "#2a140b")
        ctx.fillStyle = wood
        ctx.fill()
        ctx.fillStyle = "#e2b866"
        ctx.fillRect(R - R * 0.76, top, R * 1.52, R * 0.05)
        ctx.fillStyle = "rgba(226, 184, 102, 0.55)"
        ctx.fillRect(R - R * 0.9, top + bh - R * 0.04, R * 1.8, R * 0.04)
      }
    }

    // The snow and the glass in front of everything.
    Canvas {
      id: flurry
      anchors.fill: parent
      renderStrategy: Canvas.Cooperative

      onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        ctx.clearRect(0, 0, width, height)
        var R = lock.globeR
        ctx.save()
        ctx.beginPath()
        ctx.arc(R, R, R - 2, 0, 6.2832)
        ctx.clip()
        var f = lock.flakes
        ctx.beginPath()
        for (var i = 0; i < f.length; i++) {
          var o = f[i]
          ctx.moveTo(o.x + o.size, o.y)
          ctx.arc(o.x, o.y, o.size, 0, 6.2832)
        }
        ctx.fillStyle = lock.withAlpha(lock.snow, 0.92)
        ctx.fill()
        // The glass: bluish at the rim, clear in the middle.
        var edge = ctx.createRadialGradient(R, R, R * 0.55, R, R, R)
        edge.addColorStop(0, lock.withAlpha(lock.glassTint, 0))
        edge.addColorStop(0.85, lock.withAlpha(lock.glassTint, 0.08))
        edge.addColorStop(1, lock.withAlpha(lock.glassTint, 0.3))
        ctx.fillStyle = edge
        ctx.fillRect(0, 0, R * 2, R * 2)
        ctx.restore()
        // Rim and reflections.
        ctx.beginPath()
        ctx.arc(R, R, R - 2, 0, 6.2832)
        ctx.strokeStyle = lock.withAlpha(lock.white, 0.28)
        ctx.lineWidth = 2.5
        ctx.stroke()
        ctx.lineCap = "round"
        ctx.beginPath()
        ctx.arc(R, R, R * 0.86, Math.PI * 1.08, Math.PI * 1.38)
        ctx.strokeStyle = lock.withAlpha(lock.white, 0.32)
        ctx.lineWidth = R * 0.045
        ctx.stroke()
        ctx.beginPath()
        ctx.arc(R, R, R * 0.86, Math.PI * 1.44, Math.PI * 1.5)
        ctx.strokeStyle = lock.withAlpha(lock.white, 0.25)
        ctx.stroke()
        ctx.beginPath()
        ctx.arc(R, R, R * 0.9, Math.PI * 0.1, Math.PI * 0.32)
        ctx.strokeStyle = lock.withAlpha(lock.white, 0.12)
        ctx.lineWidth = R * 0.025
        ctx.stroke()
      }
    }

    // The date on a brass plaque on the base.
    Rectangle {
      id: plaque
      z: 2
      anchors.horizontalCenter: parent.horizontalCenter
      y: lock.globeR * 2 + (lock.baseH - height) / 2 - lock.globeR * 0.01
      width: plaqueText.implicitWidth + 28
      height: plaqueText.implicitHeight + 10
      radius: 3
      color: "#c9a052"
      border.color: "#f0d491"
      border.width: 1
      visible: plaqueText.text.length > 0
      Text {
        id: plaqueText
        anchors.centerIn: parent
        text: lock.date("dddd, d MMMM")
        color: "#3a2210"
        font.family: Style.font.family
        font.pixelSize: Math.max(12, Math.round(lock.globeR * 0.075))
        font.weight: Font.DemiBold
        font.letterSpacing: 1
      }
    }
  }

  Timer {
    interval: 33
    running: flurry.visible && lock.animating
    repeat: true
    onRunningChanged: lock.lastTick = 0
    onTriggered: {
      var now = Date.now() / 1000
      var dt = lock.lastTick > 0 ? Math.min(0.1, now - lock.lastTick) : 0.033
      lock.lastTick = now
      lock.elapsed += dt
      var R = lock.globeR
      var stir = lock.stir
      var f = lock.flakes
      var settled = 0
      for (var i = 0; i < f.length; i++) {
        var o = f[i]
        if (o.rest) {
          settled++
          // Now and then an eddy lifts one, so a quiet globe is never dead still.
          if (Math.random() < dt * 0.012) { o.rest = false; o.vy = -40 - Math.random() * 50; o.vx = (Math.random() - 0.5) * 40 }
          continue
        }
        // Water: heavy drag, a slow sink, and the swirl of a shake.
        var drag = Math.pow(0.25, dt)
        o.vx *= drag
        o.vy = o.vy * drag + (14 + o.size * 5) * (1 - drag)
        var cx = o.x - R, cy = o.y - R
        o.vx += -cy * stir * 1.6 * dt
        o.vy += cx * stir * 1.6 * dt
        o.x += (o.vx + Math.sin(lock.elapsed * o.drift + o.phase) * 6) * dt
        o.y += o.vy * dt
        // The glass.
        var dx = o.x - R, dy = o.y - R, d = Math.sqrt(dx * dx + dy * dy)
        var lim = R - 6 - o.size
        if (d > lim) {
          o.x = R + dx / d * lim
          o.y = R + dy / d * lim
          var n = (o.vx * dx + o.vy * dy) / d
          if (n > 0) { o.vx -= 1.6 * n * dx / d; o.vy -= 1.6 * n * dy / d }
        }
        var gy = lock.groundY(o.x) - o.size * 0.6
        if (o.y >= gy && o.vy >= 0) { o.y = gy; o.vx = 0; o.vy = 0; o.rest = true }
      }
      lock.stir = Math.max(0, lock.stir - dt * 0.55)
      lock.wobble = Math.max(0, lock.wobble - dt * 0.5)
      flurry.requestPaint()
    }
  }

  Column {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: globe.bottom
    anchors.topMargin: Math.round(lock.height * 0.045)
    spacing: 16

    ChristmasCountdown {
      lock: lock
      anchors.horizontalCenter: parent.horizontalCenter
      color: lock.brass
      opacity: 0.9
    }

    PasswordField {
      id: field
      lock: lock
      anchors.horizontalCenter: parent.horizontalCenter
      width: 360
      height: 54
      radius: 27
      showLockGlyph: false
      shakeOnFail: true
      color: Qt.rgba(0.1, 0.06, 0.04, 0.85)
      textColor: lock.cream
      mutedColor: lock.withAlpha(lock.cream, 0.45)
      accentColor: lock.brass
      errorColor: lock.cherry
      outlineColor: lock.withAlpha(lock.brass, 0.5)
      placeholder: lock.tr("Password")
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      opacity: lock.snapshotMode ? 0 : 1
      text: lock.failedAttempts > 0
        ? lock.tr(lock.failedAttempts === 1 ? "1 failed attempt" : "%1 failed attempts").arg(lock.failedAttempts)
        : (lock.fingerprintConfigured ? lock.fingerprintHint(lock.tr("󰆠  Touch sensor or type password")) : lock.tr("Enter your password to unlock"))
      textFormat: Text.PlainText
      color: lock.failedAttempts > 0 ? lock.cherry : lock.withAlpha(lock.cream, 0.4)
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      font.letterSpacing: 2
    }
  }
}
