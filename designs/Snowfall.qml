import QtQuick
import QtQuick.Effects
import qs.Commons
import qs.Commons as Commons

// Snowfall: snow coming down over a cold, dimmed wallpaper in three depths,
// and settling into a drift along the bottom edge that grows while the screen
// stays locked. Every key kicks a little powder up off the field; a wrong
// password sends a gust across that blows the snow sideways and half the
// drift away. A seasonal design, so it keeps its own palette instead of the
// theme's.
DesignBase {
  id: lock
  inputItem: field.input
  shakeOnFail: false
  flashOnFail: false

  readonly property color snow: "#f4f8ff"
  readonly property color frost: "#bcd8ff"
  readonly property color night: "#081325"
  readonly property color berry: "#ff5a5f"
  readonly property color white: "#ffffff"
  readonly property color deep: "#1c3358"

  // Flakes in three layers (0 far, 1 middle, 2 near). Only the near ones
  // land on the drift; the others fall past it into the distance.
  property var flakes: []
  // The drift: a height in pixels per column across the bottom.
  property var drift: []
  readonly property int columns: 80
  readonly property real driftMax: height * 0.085
  // Powder kicked up by a key or blown off the drift by a gust.
  property var puffs: []
  property real wind: 0
  property real gust: 0        // 0..1, a wrong password's storm
  property real elapsed: 0
  property real lastTick: 0

  readonly property var layerSize: [1.1, 1.9, 3.0]
  readonly property var layerSpeed: [26, 46, 78]
  readonly property var layerAlpha: [0.4, 0.68, 0.95]
  readonly property var layerWind: [0.45, 0.7, 1.0]

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

  function newFlake(r, layer, x, y) {
    return { x: x, y: y, layer: layer,
             r: layerSize[layer] * (0.75 + r() * 0.6),
             speed: layerSpeed[layer] * (0.8 + r() * 0.45),
             sway: 8 + r() * 22, freq: 0.4 + r() * 0.8, phase: r() * 6.28 }
  }

  function resetSnow() {
    if (width <= 0 || height <= 0) return
    var r = rng(23)
    var n = Math.round(Math.max(120, Math.min(340, width * height / 7000)))
    var f = []
    for (var i = 0; i < n; i++) f.push(newFlake(r, i % 3, r() * width, r() * height))
    flakes = f
    // A drift that has already been building a while, uneven like a real one.
    var d = []
    for (var c = 0; c < columns; c++) {
      var u = c / columns
      d.push(driftMax * (0.45 + 0.18 * Math.sin(u * 9.1 + 0.6) + 0.12 * Math.sin(u * 23.7 + 2.1) + 0.06 * Math.sin(u * 51.3)))
    }
    drift = d
    puffs = []
  }

  function driftAt(x) {
    var c = Math.max(0, Math.min(columns - 1, Math.floor(x / width * columns)))
    return drift.length > 0 ? drift[c] : 0
  }

  // Powder off the top of the field, a pinch per key.
  function kick(count, power) {
    var at = field.mapToItem(lock, 0, 0)
    var p = puffs
    for (var i = 0; i < count; i++) {
      p.push({ x: at.x + 20 + Math.random() * (field.width - 40), y: at.y + 4,
               vx: (Math.random() - 0.5) * 120, vy: -power * (0.55 + Math.random() * 0.6),
               r: 1.4 + Math.random() * 1.8, life: 1, span: 0.9 + Math.random() * 0.6 })
    }
    if (p.length > 260) p.splice(0, p.length - 260)
  }

  // A wrong password: the wind gets up, the drift is half blown away and what
  // comes off it goes with the gust.
  function storm() {
    gust = 1
    wind = 760 * (Math.random() < 0.5 ? -1 : 1)
    var p = puffs
    for (var c = 0; c < columns; c++) {
      var lost = drift[c] * 0.4
      drift[c] -= lost
      if (c % 2 === 0) {
        p.push({ x: (c + 0.5) / columns * width, y: height - drift[c] - 2,
                 vx: wind * 0.3 * Math.random(), vy: -80 - Math.random() * 160,
                 r: 1.6 + Math.random() * 2, life: 1, span: 1.2 + Math.random() * 0.8 })
      }
    }
    if (p.length > 260) p.splice(0, p.length - 260)
  }

  onWidthChanged: resetSnow()
  onHeightChanged: resetSnow()
  Component.onCompleted: resetSnow()

  Typing {
    id: typing
    lock: lock
    onTyped: lock.kick(5 + Math.min(6, Math.round(typing.cadence)), 200)
    onCleared: lock.kick(18, 260)
  }

  Connections {
    target: lock
    function onFailureMessageChanged() {
      if (lock.failureMessage.length > 0) lock.storm()
    }
  }

  Wallpaper { anchors.fill: parent; lock: lock; blur: 0.8; dim: 0.3; vignette: true }
  Rectangle {
    anchors.fill: parent
    gradient: Gradient {
      GradientStop { position: 0.0; color: lock.withAlpha(lock.night, 0.78) }
      GradientStop { position: 0.6; color: lock.withAlpha(lock.night, 0.5) }
      GradientStop { position: 1.0; color: lock.withAlpha(lock.deep, 0.45) }
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: { lock.wakeRequested(); lock.forcePasswordFocus() }
    onPositionChanged: lock.wakeRequested()
  }

  Canvas {
    id: scene
    anchors.fill: parent
    renderStrategy: Canvas.Cooperative

    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      ctx.clearRect(0, 0, width, height)
      var f = lock.flakes
      var i, o, layer

      // Far and middle snow first, so the drift covers what falls behind it.
      for (layer = 0; layer < 2; layer++) {
        ctx.beginPath()
        for (i = 0; i < f.length; i++) {
          o = f[i]
          if (o.layer !== layer) continue
          ctx.moveTo(o.x + o.r, o.y)
          ctx.arc(o.x, o.y, o.r, 0, 6.2832)
        }
        ctx.fillStyle = lock.withAlpha(lock.snow, lock.layerAlpha[layer])
        ctx.fill()
      }

      // The drift, lit from above and blue in its hollows.
      var d = lock.drift
      if (d.length > 1) {
        var step = width / (d.length - 1)
        ctx.beginPath()
        ctx.moveTo(0, height)
        ctx.lineTo(0, height - d[0])
        for (i = 1; i < d.length; i++) {
          var px = (i - 0.5) * step, py = height - (d[i - 1] + d[i]) / 2
          ctx.quadraticCurveTo((i - 1) * step, height - d[i - 1], px, py)
        }
        ctx.lineTo(width, height - d[d.length - 1])
        ctx.lineTo(width, height)
        ctx.closePath()
        var g = ctx.createLinearGradient(0, height - lock.driftMax * 1.2, 0, height)
        g.addColorStop(0, "#ffffff")
        g.addColorStop(0.45, "#e4eeff")
        g.addColorStop(1, "#9fb8dc")
        ctx.fillStyle = g
        ctx.fill()
        // Glints on the crust.
        for (i = 3; i < d.length; i += 7) {
          var tw = Math.sin(lock.elapsed * 2.3 + i * 1.7)
          if (tw < 0.55) continue
          ctx.beginPath()
          ctx.arc(i * step, height - d[i] + 3, 1.2 + (tw - 0.55) * 3, 0, 6.2832)
          ctx.fillStyle = lock.withAlpha(lock.white, (tw - 0.55) * 2)
          ctx.fill()
        }
      }

      // Near snow, with a soft halo so it reads as close and out of focus.
      ctx.beginPath()
      for (i = 0; i < f.length; i++) {
        o = f[i]
        if (o.layer !== 2) continue
        ctx.moveTo(o.x + o.r * 1.8, o.y)
        ctx.arc(o.x, o.y, o.r * 1.8, 0, 6.2832)
      }
      ctx.fillStyle = lock.withAlpha(lock.snow, 0.08)
      ctx.fill()
      ctx.beginPath()
      for (i = 0; i < f.length; i++) {
        o = f[i]
        if (o.layer !== 2) continue
        ctx.moveTo(o.x + o.r, o.y)
        ctx.arc(o.x, o.y, o.r, 0, 6.2832)
      }
      ctx.fillStyle = lock.withAlpha(lock.snow, lock.layerAlpha[2])
      ctx.fill()

      // Powder in the air.
      var p = lock.puffs
      for (i = 0; i < p.length; i++) {
        o = p[i]
        ctx.beginPath()
        ctx.arc(o.x, o.y, o.r, 0, 6.2832)
        ctx.fillStyle = lock.withAlpha(lock.snow, 0.9 * o.life)
        ctx.fill()
      }
    }
  }

  Timer {
    interval: 33
    running: scene.visible && lock.animating
    repeat: true
    onRunningChanged: lock.lastTick = 0
    onTriggered: {
      var now = Date.now() / 1000
      var dt = lock.lastTick > 0 ? Math.min(0.1, now - lock.lastTick) : 0.033
      lock.lastTick = now
      lock.elapsed += dt
      var w = lock.width, h = lock.height
      // A breeze that turns now and then, under whatever the gust is doing.
      var breeze = 16 * Math.sin(lock.elapsed * 0.13) + 8 * Math.sin(lock.elapsed * 0.41)
      lock.wind *= Math.pow(0.55, dt)
      lock.gust = Math.max(0, lock.gust - dt * 0.3)
      var air = lock.wind + breeze
      var f = lock.flakes, d = lock.drift
      for (var i = 0; i < f.length; i++) {
        var o = f[i]
        o.y += o.speed * dt * (1 + lock.gust * 0.5)
        o.x += air * lock.layerWind[o.layer] * dt + Math.cos(lock.elapsed * o.freq + o.phase) * o.sway * o.freq * dt
        if (o.x < -20) o.x += w + 40
        else if (o.x > w + 20) o.x -= w + 40
        if (o.layer === 2 && d.length > 0 && o.x >= 0 && o.x < w) {
          var c = Math.floor(o.x / w * lock.columns)
          if (o.y >= h - d[c]) {
            // Lands: the drift grows a touch, and the neighbours take some.
            var add = o.r * 0.35
            d[c] = Math.min(lock.driftMax, d[c] + add)
            if (c > 0) d[c - 1] = Math.min(lock.driftMax, d[c - 1] + add * 0.4)
            if (c < lock.columns - 1) d[c + 1] = Math.min(lock.driftMax, d[c + 1] + add * 0.4)
            o.y = -10 - Math.random() * 40
            o.x = Math.random() * w
            continue
          }
        }
        if (o.y > h + 10) { o.y = -10 - Math.random() * 40; o.x = Math.random() * w }
      }
      // Powder: up, over and down, gone with the wind.
      var p = lock.puffs
      for (var j = p.length - 1; j >= 0; j--) {
        var q = p[j]
        q.vy += 260 * dt
        q.vx += (air * 0.6 - q.vx) * Math.min(1, dt * 1.5)
        q.x += q.vx * dt
        q.y += q.vy * dt
        q.life -= dt / q.span
        if (q.life <= 0) p.splice(j, 1)
      }
      scene.requestPaint()
    }
  }

  Column {
    id: column
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
    anchors.verticalCenterOffset: -Math.round(lock.height * 0.06)
    spacing: 34

    Column {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 8
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: lock.clock("HH:mm")
        color: "#ffffff"
        font.family: Style.font.family
        font.pixelSize: Math.round(Style.font.baseSize * 9.5)
        font.weight: Font.DemiBold
        font.letterSpacing: -1
        layer.enabled: true
        layer.effect: MultiEffect { shadowEnabled: true; shadowColor: lock.frost; shadowBlur: 1.0; shadowOpacity: 0.7; shadowVerticalOffset: 0 }
      }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: lock.date("dddd, d MMMM")
        color: lock.withAlpha(lock.snow, 0.92)
        font.family: Style.font.family
        font.pixelSize: Style.font.title
        font.letterSpacing: 3
      }
      ChristmasCountdown {
        lock: lock
        anchors.horizontalCenter: parent.horizontalCenter
        color: lock.frost
        opacity: 0.85
      }
    }

    PasswordField {
      id: field
      lock: lock
      anchors.horizontalCenter: parent.horizontalCenter
      width: 380
      height: 56
      radius: 28
      showLockGlyph: false
      shakeOnFail: true
      color: Qt.rgba(0.85, 0.92, 1, 0.14)
      textColor: lock.snow
      mutedColor: lock.withAlpha(lock.snow, 0.5)
      accentColor: lock.frost
      errorColor: lock.berry
      outlineColor: lock.withAlpha(lock.snow, 0.5)
      placeholder: lock.tr("Password")
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      opacity: lock.snapshotMode ? 0 : 1
      text: lock.failedAttempts > 0
        ? lock.tr(lock.failedAttempts === 1 ? "1 failed attempt" : "%1 failed attempts").arg(lock.failedAttempts)
        : (lock.fingerprintConfigured ? lock.fingerprintHint(lock.tr("󰆠  Touch sensor or type password")) : lock.tr("Enter your password to unlock"))
      textFormat: Text.PlainText
      color: lock.failedAttempts > 0 ? lock.berry : lock.withAlpha(lock.snow, 0.55)
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      font.letterSpacing: 2
    }
  }
}
