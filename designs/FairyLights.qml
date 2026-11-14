import QtQuick
import QtQuick.Effects
import qs.Commons
import qs.Commons as Commons

// Fairy Lights: two strings of old-fashioned bulbs swagged across the top of
// a dark winter night, twinkling at their own pace. Each key you type turns
// one more bulb up to full, scattered along the string; Esc runs a chase down
// the line, and a wrong password blows the fuse: the lot flickers and goes
// dark, then warms back up. A seasonal design, so it keeps its own palette
// instead of the theme's.
DesignBase {
  id: lock
  inputItem: field.input
  shakeOnFail: false
  flashOnFail: false

  readonly property color warm: "#fff3dc"
  readonly property color gold: "#ffc24d"
  readonly property color night: "#070b16"
  readonly property color pine: "#16301f"
  readonly property color fault: "#ff5148"
  readonly property color white: "#ffffff"
  readonly property color core: "#fffbe8"
  readonly property color forest: "#0f1a14"
  readonly property var bulbColors: ["#ff3b3b", "#2fe36d", "#ffc23d", "#3f8cff", "#ff8a2a"]

  // Every bulb: where it hangs, its colour, how it twinkles, and `flare`, the
  // pop when a key lights it. `front` bulbs are the ones the typing lights.
  property var bulbs: []
  property var wires: []
  // The order the front bulbs light in, so they come on all along the string
  // instead of marching from the left.
  property var order: []
  property int frontCount: 0
  readonly property int lit: passwordText.length
  property real outage: 0      // 0..1, the fuse gone
  property real chase: -1      // the Esc chase, -1 when there is none
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

  function quad(p0, c, p1, t) {
    var u = 1 - t
    return { x: u * u * p0.x + 2 * u * t * c.x + t * t * p1.x,
             y: u * u * p0.y + 2 * u * t * c.y + t * t * p1.y,
             // The slope there, to tilt the bulb with the wire a little.
             tx: 2 * u * (c.x - p0.x) + 2 * t * (p1.x - c.x),
             ty: 2 * u * (c.y - p0.y) + 2 * t * (p1.y - c.y) }
  }

  // One string: swags between hooks along the top, `perSwag` bulbs to each.
  function hang(r, top, sag, swags, offset, perSwag, front, sizeScale, b, w) {
    var span = (width + 120) / swags
    for (var k = -1; k <= swags; k++) {
      var x0 = -60 + (k + offset) * span, x1 = x0 + span
      var p0 = { x: x0, y: top + (k % 2 === 0 ? 0 : 8) }
      var p1 = { x: x1, y: top + ((k + 1) % 2 === 0 ? 0 : 8) }
      var dip = sag * (0.85 + r() * 0.3)
      var c = { x: (x0 + x1) / 2, y: top + dip * 2 }
      w.push({ p0: p0, c: c, p1: p1, front: front })
      for (var j = 0; j < perSwag; j++) {
        var at = quad(p0, c, p1, (j + 0.5) / perSwag)
        if (at.x < -30 || at.x > width + 30) continue
        b.push({ x: at.x, y: at.y, tilt: Math.atan2(at.ty, at.tx) * 0.35,
                 color: Qt.lighter(bulbColors[(b.length + (front ? 0 : 2)) % bulbColors.length], 1.0),
                 size: sizeScale * (0.92 + r() * 0.16),
                 phase: r() * 6.28, speed: 0.6 + r() * 1.4, flare: 0, front: front })
      }
    }
  }

  function resetLights() {
    if (width <= 0 || height <= 0) return
    var r = rng(1225)
    var b = [], w = []
    var swags = Math.max(3, Math.min(6, Math.round(width / 480)))
    // The back string first, smaller and dimmer, so the front one hangs over it.
    hang(r, -height * 0.015, height * 0.15, swags, 0.5, 6, false, 0.72, b, w)
    hang(r, -height * 0.025, height * 0.21, swags, 0, 7, true, 1, b, w)
    bulbs = b
    wires = w
    var idx = []
    for (var i = 0; i < b.length; i++) if (b[i].front) idx.push(i)
    for (var j = idx.length - 1; j > 0; j--) {
      var s = Math.floor(r() * (j + 1))
      var t = idx[j]; idx[j] = idx[s]; idx[s] = t
    }
    order = idx
    frontCount = idx.length
  }

  // The bulb a given character lights.
  function bulbFor(i) { return order.length > 0 ? order[i % order.length] : -1 }

  onWidthChanged: resetLights()
  onHeightChanged: resetLights()
  Component.onCompleted: resetLights()

  Typing {
    lock: lock
    onTyped: function(index) {
      var k = lock.bulbFor(index)
      if (k >= 0) lock.bulbs[k].flare = 1
    }
    onCleared: if (lock.outage < 0.05) lock.chase = 0
  }

  Connections {
    target: lock
    function onFailureMessageChanged() {
      if (lock.failureMessage.length > 0) { lock.outage = 1; lock.chase = -1 }
    }
  }

  Wallpaper { anchors.fill: parent; lock: lock; blur: 1; dim: 0.55; vignette: true }
  Rectangle {
    anchors.fill: parent
    gradient: Gradient {
      GradientStop { position: 0.0; color: lock.withAlpha(lock.night, 0.9) }
      GradientStop { position: 0.55; color: lock.withAlpha(lock.night, 0.7) }
      GradientStop { position: 1.0; color: lock.withAlpha(lock.forest, 0.8) }
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: { lock.wakeRequested(); lock.forcePasswordFocus() }
    onPositionChanged: lock.wakeRequested()
  }

  Canvas {
    id: strings
    anchors.fill: parent
    renderStrategy: Canvas.Cooperative

    // How bright bulb i is right now, 0 (dark glass) to about 1.3 (popping).
    function glow(i, o) {
      var base = o.front ? 0.44 : 0.36
      var tw = base + 0.22 * Math.sin(lock.elapsed * o.speed + o.phase)
      var on = 0
      if (o.front) {
        var pos = lock.order.indexOf(i)
        if (pos >= 0 && lock.lit > 0 && (pos < lock.lit || lock.lit > lock.frontCount)) on = 1
      }
      var b = Math.max(tw, on) + o.flare * 0.35
      if (lock.chase >= 0) {
        var wave = Math.abs(o.x / width - lock.chase)
        if (wave < 0.08) b = Math.max(b, 1.2 - wave * 6)
      }
      // The fuse: a dying flicker, then dark, then warming back up.
      if (lock.outage > 0) {
        var keep = 1 - lock.outage
        if (lock.outage > 0.75) keep = Math.random() < 0.5 ? 0.9 : 0.08
        b *= Math.max(0.06, keep)
      }
      return Math.min(1.35, b)
    }

    function bulb(ctx, o, b) {
      var s = 12.5 * o.size
      ctx.save()
      ctx.translate(o.x, o.y)
      // Light thrown round it, a gradient rather than a canvas shadow (a
      // shadow is a software blur per fill and stalls the shell).
      if (b > 0.12) {
        var halo = ctx.createRadialGradient(0, s * 1.5, 0, 0, s * 1.5, s * 5.5 * Math.min(1.2, b))
        halo.addColorStop(0, lock.withAlpha(o.color, 0.62 * Math.min(1, b)))
        halo.addColorStop(0.35, lock.withAlpha(o.color, 0.22 * Math.min(1, b)))
        halo.addColorStop(1, lock.withAlpha(o.color, 0))
        ctx.fillStyle = halo
        ctx.fillRect(-s * 7, -s * 5, s * 14, s * 14)
      }
      ctx.rotate(o.tilt)
      // The socket.
      ctx.fillStyle = "#24402e"
      ctx.fillRect(-s * 0.36, -s * 0.15, s * 0.72, s * 0.85)
      ctx.fillStyle = "#3b5e46"
      ctx.fillRect(-s * 0.36, -s * 0.15, s * 0.72, s * 0.18)
      // The glass: a rounded drop, dark when off, hot in the middle when on.
      var lvl = Math.min(1, b)
      var c = o.color
      var glass = Qt.rgba(c.r * (0.22 + 0.78 * lvl), c.g * (0.22 + 0.78 * lvl), c.b * (0.22 + 0.78 * lvl), 0.95)
      ctx.beginPath()
      ctx.moveTo(-s * 0.36, s * 0.65)
      ctx.bezierCurveTo(-s * 0.95, s * 1.3, -s * 0.6, s * 2.45, 0, s * 2.6)
      ctx.bezierCurveTo(s * 0.6, s * 2.45, s * 0.95, s * 1.3, s * 0.36, s * 0.65)
      ctx.closePath()
      ctx.fillStyle = glass
      ctx.fill()
      if (lvl > 0.2) {
        ctx.beginPath()
        ctx.ellipse(-s * 0.22, s * 1.15, s * 0.44, s * 0.95)
        ctx.fillStyle = lock.withAlpha(lock.core, 0.75 * (lvl - 0.2))
        ctx.fill()
      }
      // A highlight on the glass, there even when it is dark.
      ctx.beginPath()
      ctx.ellipse(-s * 0.42, s * 1.0, s * 0.16, s * 0.5)
      ctx.fillStyle = lock.withAlpha(lock.white, 0.18 + 0.25 * lvl)
      ctx.fill()
      ctx.restore()
    }

    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      ctx.clearRect(0, 0, width, height)
      var w = lock.wires, b = lock.bulbs
      var pass, i
      for (pass = 0; pass < 2; pass++) {
        var front = pass === 1
        ctx.beginPath()
        for (i = 0; i < w.length; i++) {
          if (w[i].front !== front) continue
          ctx.moveTo(w[i].p0.x, w[i].p0.y)
          ctx.quadraticCurveTo(w[i].c.x, w[i].c.y, w[i].p1.x, w[i].p1.y)
        }
        ctx.strokeStyle = front ? "#1d3a27" : "#132719"
        ctx.lineWidth = front ? 3 : 2
        ctx.stroke()
        for (i = 0; i < b.length; i++) {
          if (b[i].front !== front) continue
          bulb(ctx, b[i], glow(i, b[i]))
        }
      }
    }
  }

  Timer {
    interval: 40
    running: strings.visible && lock.animating
    repeat: true
    onRunningChanged: lock.lastTick = 0
    onTriggered: {
      var now = Date.now() / 1000
      var dt = lock.lastTick > 0 ? Math.min(0.1, now - lock.lastTick) : 0.04
      lock.lastTick = now
      lock.elapsed += dt
      var b = lock.bulbs
      for (var i = 0; i < b.length; i++) b[i].flare = Math.max(0, b[i].flare - dt * 2.2)
      lock.outage = Math.max(0, lock.outage - dt * 0.4)
      if (lock.chase >= 0) {
        lock.chase += dt * 0.9
        if (lock.chase > 1.15) lock.chase = -1
      }
      strings.requestPaint()
    }
  }

  Column {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
    anchors.verticalCenterOffset: Math.round(lock.height * 0.09)
    spacing: 34

    Column {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 8
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: lock.clock("HH:mm")
        color: lock.warm
        font.family: Style.font.family
        font.pixelSize: Math.round(Style.font.baseSize * 9)
        font.weight: Font.Bold
        font.letterSpacing: 2
        layer.enabled: true
        layer.effect: MultiEffect { shadowEnabled: true; shadowColor: lock.gold; shadowBlur: 1.0; shadowOpacity: 0.55 * (1 - lock.outage * 0.8); shadowVerticalOffset: 0 }
      }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: lock.date("dddd, d MMMM")
        color: lock.withAlpha(lock.warm, 0.85)
        font.family: Style.font.family
        font.pixelSize: Style.font.title
        font.letterSpacing: 3
      }
      ChristmasCountdown {
        lock: lock
        anchors.horizontalCenter: parent.horizontalCenter
        color: lock.gold
        opacity: 0.9
      }
    }

    PasswordField {
      id: field
      lock: lock
      anchors.horizontalCenter: parent.horizontalCenter
      width: 380
      height: 56
      radius: 10
      showLockGlyph: false
      shakeOnFail: true
      color: Qt.rgba(0.03, 0.06, 0.05, 0.8)
      textColor: lock.warm
      mutedColor: lock.withAlpha(lock.warm, 0.45)
      accentColor: lock.gold
      errorColor: lock.fault
      outlineColor: lock.withAlpha(lock.gold, 0.45)
      placeholder: lock.tr("Password")
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      opacity: lock.snapshotMode ? 0 : 1
      text: lock.failedAttempts > 0
        ? lock.tr(lock.failedAttempts === 1 ? "1 failed attempt" : "%1 failed attempts").arg(lock.failedAttempts)
        : (lock.fingerprintConfigured ? lock.fingerprintHint(lock.tr("󰆠  Touch sensor or type password")) : lock.tr("Enter your password to unlock"))
      textFormat: Text.PlainText
      color: lock.failedAttempts > 0 ? lock.fault : lock.withAlpha(lock.warm, 0.45)
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      font.letterSpacing: 2
    }
  }
}
