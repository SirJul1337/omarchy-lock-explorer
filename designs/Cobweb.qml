import QtQuick
import QtQuick.Effects
import qs.Commons
import qs.Commons as Commons

// Cobweb: a dewy web spun across the top left corner of a moonlit night, and
// a spider that lets itself down on a thread as the password goes in, one
// step per key, and climbs back up when the typing stops. A wrong password
// shakes the web and drops it the whole way. A seasonal design, so it keeps
// its own palette instead of the theme's.
DesignBase {
  id: lock
  inputItem: field.input
  shakeOnFail: false
  flashOnFail: false

  readonly property color silk: "#dfe3f0"
  readonly property color moonlight: "#b9c3ff"
  readonly property color night: "#07080f"
  readonly property color blood: "#ff4a3d"

  property real descent: 0     // 0 at the top, 1 just above the field
  property real shake: 0       // 0..1, the web trembling
  property real fright: 0      // 0..1, red eyes
  property real idle: 0        // seconds since the last key
  property real elapsed: 0
  property real lastTick: 0
  property var dew: []

  readonly property real webR: Math.min(width, height) * 0.78
  readonly property real spiderX: width * 0.64
  readonly property real spiderTop: -40

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

  // Dew sits where the spiral threads cross the spokes.
  function resetDew() {
    var r = rng(17)
    var d = []
    for (var i = 0; i < 34; i++) {
      var ring = 3 + Math.floor(r() * 9)
      var spoke = Math.floor(r() * 13)
      d.push({ ring: ring, spoke: spoke, size: 2 + r() * 3, twinkle: r() * 6.28 })
    }
    dew = d
  }

  function scare() {
    shake = 1
    fright = 1
    descent = 1
    idle = 0
  }

  Component.onCompleted: resetDew()
  Typing { lock: lock; onTyped: { lock.descent = Math.min(1, lock.descent + 0.14); lock.idle = 0 } }

  Rectangle { anchors.fill: parent; color: lock.night }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: { lock.wakeRequested(); lock.forcePasswordFocus() }
    onPositionChanged: lock.wakeRequested()
  }

  Canvas {
    id: web
    anchors.fill: parent
    renderStrategy: Canvas.Cooperative

    readonly property int spokes: 13
    readonly property int rings: 12

    function spokeAngle(i) { return (i + 0.5) / spokes * Math.PI / 2 }
    function ringRadius(j) { return lock.webR * (0.12 + 0.88 * Math.pow(j / rings, 1.25)) }

    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      ctx.clearRect(0, 0, width, height)

      // Moonlight from the top right.
      var moon = ctx.createRadialGradient(width * 0.85, -height * 0.1, 20, width * 0.85, -height * 0.1, height * 1.1)
      moon.addColorStop(0, lock.withAlpha(lock.moonlight, 0.22))
      moon.addColorStop(0.5, lock.withAlpha(lock.moonlight, 0.05))
      moon.addColorStop(1, lock.withAlpha(lock.moonlight, 0))
      ctx.fillStyle = moon
      ctx.fillRect(0, 0, width, height)

      // The web, trembling when shaken.
      var jx = Math.sin(lock.elapsed * 31) * 6 * lock.shake
      var jy = Math.cos(lock.elapsed * 27) * 4 * lock.shake
      var ox = -12 + jx, oy = -12 + jy
      ctx.lineCap = "round"
      ctx.strokeStyle = lock.withAlpha(lock.silk, 0.34)
      ctx.lineWidth = 1.2
      var i, j
      for (i = 0; i < spokes; i++) {
        var a = spokeAngle(i)
        ctx.beginPath()
        ctx.moveTo(ox, oy)
        ctx.lineTo(ox + Math.cos(a) * lock.webR * 1.02, oy + Math.sin(a) * lock.webR * 1.02)
        ctx.stroke()
      }
      ctx.strokeStyle = lock.withAlpha(lock.silk, 0.26)
      ctx.lineWidth = 1
      for (j = 1; j <= rings; j++) {
        var rr = ringRadius(j)
        ctx.beginPath()
        for (i = 0; i < spokes - 1; i++) {
          var a0 = spokeAngle(i), a1 = spokeAngle(i + 1), am = (a0 + a1) / 2
          var x0 = ox + Math.cos(a0) * rr, y0 = oy + Math.sin(a0) * rr
          var x1 = ox + Math.cos(a1) * rr, y1 = oy + Math.sin(a1) * rr
          var sag = rr * 0.955
          if (i === 0) ctx.moveTo(x0, y0)
          ctx.quadraticCurveTo(ox + Math.cos(am) * sag, oy + Math.sin(am) * sag, x1, y1)
        }
        ctx.stroke()
      }
      // Dew, each drop with a highlight, twinkling in the moonlight.
      var d = lock.dew
      for (var k = 0; k < d.length; k++) {
        var o = d[k]
        var ang = spokeAngle(o.spoke), rad = ringRadius(o.ring)
        var dx = ox + Math.cos(ang) * rad, dy = oy + Math.sin(ang) * rad
        var tw = 0.6 + 0.4 * Math.sin(lock.elapsed * 1.7 + o.twinkle)
        ctx.beginPath()
        ctx.arc(dx, dy, o.size, 0, 6.2832)
        ctx.fillStyle = lock.withAlpha(lock.silk, 0.55 * tw)
        ctx.fill()
        ctx.beginPath()
        ctx.arc(dx - o.size * 0.3, dy - o.size * 0.3, o.size * 0.35, 0, 6.2832)
        ctx.fillStyle = lock.withAlpha("#ffffff", 0.8 * tw)
        ctx.fill()
      }

      // The spider on its thread.
      var sx = lock.spiderX + Math.sin(lock.elapsed * 1.1) * 6 + jx * 0.5
      var bottom = fieldAnchor.mapToItem(lock, 0, 0).y - 70
      var sy = lock.spiderTop + (bottom - lock.spiderTop) * lock.descent
      ctx.strokeStyle = lock.withAlpha(lock.silk, 0.5)
      ctx.lineWidth = 1
      ctx.beginPath()
      ctx.moveTo(sx, 0)
      ctx.lineTo(sx, sy)
      ctx.stroke()
      ctx.save()
      ctx.translate(sx, sy)
      ctx.fillStyle = "#121018"
      ctx.strokeStyle = "#121018"
      ctx.lineWidth = 2.2
      // Legs: four a side, bent at the knee, stirring as it moves.
      var stir = Math.sin(lock.elapsed * 6) * 0.08
      for (var side = -1; side <= 1; side += 2) {
        for (var leg = 0; leg < 4; leg++) {
          var la = (-0.9 + leg * 0.55) + stir * (leg % 2 === 0 ? 1 : -1)
          var kx = side * 22 * Math.cos(la), ky = 18 * Math.sin(la) - 6
          var fx = side * 38 * Math.cos(la * 0.8), fy = 18 * Math.sin(la) + 14
          ctx.beginPath()
          ctx.moveTo(side * 4, 0)
          ctx.quadraticCurveTo(kx, ky, fx, fy)
          ctx.stroke()
        }
      }
      ctx.beginPath()
      ctx.ellipse(-9, -2, 18, 26)
      ctx.fill()
      ctx.beginPath()
      ctx.arc(0, -8, 7, 0, 6.2832)
      ctx.fill()
      // Eyes, red when it is cross.
      var eye = Qt.rgba(lock.silk.r + (lock.blood.r - lock.silk.r) * lock.fright,
                        lock.silk.g + (lock.blood.g - lock.silk.g) * lock.fright,
                        lock.silk.b + (lock.blood.b - lock.silk.b) * lock.fright, 1)
      ctx.fillStyle = eye
      ctx.beginPath(); ctx.arc(-2.5, -10, 1.6, 0, 6.2832); ctx.fill()
      ctx.beginPath(); ctx.arc(2.5, -10, 1.6, 0, 6.2832); ctx.fill()
      ctx.restore()
    }
  }

  Timer {
    interval: 33
    running: web.visible && lock.animating
    repeat: true
    onRunningChanged: lock.lastTick = 0
    onTriggered: {
      var now = Date.now() / 1000
      var dt = lock.lastTick > 0 ? Math.min(0.1, now - lock.lastTick) : 0.033
      lock.lastTick = now
      lock.elapsed += dt
      lock.idle += dt
      // Left alone, it climbs back up.
      if (lock.idle > 2.5 && lock.descent > 0) lock.descent = Math.max(0, lock.descent - dt * 0.3)
      lock.shake = Math.max(0, lock.shake - dt * 0.6)
      lock.fright = Math.max(0, lock.fright - dt * 0.3)
      web.requestPaint()
    }
  }

  Connections {
    target: lock
    function onFailureMessageChanged() {
      if (lock.failureMessage.length > 0) lock.scare()
    }
  }

  Column {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
    anchors.verticalCenterOffset: Math.round(lock.height * 0.04)
    spacing: 30

    Column {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 6
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: lock.clock("HH:mm")
        color: lock.silk
        font.family: Style.font.family
        font.pixelSize: Math.round(Style.font.baseSize * 9)
        font.weight: Font.Light
        font.letterSpacing: 4
        layer.enabled: true
        layer.effect: MultiEffect { shadowEnabled: true; shadowColor: lock.moonlight; shadowBlur: 1.0; shadowOpacity: 0.5; shadowVerticalOffset: 0 }
      }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: lock.date("dddd, d MMMM")
        color: lock.withAlpha(lock.moonlight, 0.8)
        font.family: Style.font.family
        font.pixelSize: Style.font.title
        font.letterSpacing: 3
      }
    }

    Item {
      id: fieldAnchor
      anchors.horizontalCenter: parent.horizontalCenter
      width: field.width
      height: field.height
      PasswordField {
        id: field
        lock: lock
        anchors.fill: parent
        width: 380
        height: 56
        radius: 8
        showLockGlyph: false
        shakeOnFail: true
        color: Qt.rgba(0.04, 0.04, 0.08, 0.8)
        textColor: lock.silk
        mutedColor: lock.withAlpha(lock.silk, 0.45)
        accentColor: lock.moonlight
        errorColor: lock.blood
        outlineColor: lock.withAlpha(lock.silk, 0.55)
        placeholder: "Mind the spider"
      }
    }
  }

  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 36
    opacity: lock.snapshotMode ? 0 : 1
    text: lock.failedAttempts > 0
      ? lock.tr(lock.failedAttempts === 1 ? "1 failed attempt" : "%1 failed attempts").arg(lock.failedAttempts)
      : (lock.fingerprintConfigured ? lock.fingerprintHint(lock.tr("󰆠  Touch sensor or type password")) : lock.tr("Enter your password to unlock"))
    textFormat: Text.PlainText
    color: lock.failedAttempts > 0 ? lock.blood : lock.withAlpha(lock.silk, 0.4)
    font.family: Style.font.family
    font.pixelSize: Style.font.bodySmall
    font.letterSpacing: 2
  }
}
