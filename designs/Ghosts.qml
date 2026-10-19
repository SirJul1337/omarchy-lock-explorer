import QtQuick
import QtQuick.Effects
import qs.Commons
import qs.Commons as Commons

// Ghosts: the wallpaper gone cold and dim, and a handful of sheet ghosts
// drifting over it with their eyes on the password field. Every key makes
// one of them bob; a wrong password scatters the lot with a BOO. A seasonal
// design, so it keeps its own palette instead of the theme's.
DesignBase {
  id: lock
  inputItem: input
  shakeOnFail: false
  flashOnFail: false

  readonly property color sheet: "#eef0ff"
  readonly property color moon: "#c7cdfd"
  readonly property color blood: "#ff4a3d"
  readonly property color dusk: "#1a1230"

  // The ghosts: a home spot in screen fractions, a size, a drift phase, and
  // the push a scare gives them (vx, vy) with its displacement (dx, dy).
  property var ghosts: []
  property real boo: 0        // 0..1, the BOO fading out
  readonly property int lit: passwordText.length
  readonly property int maxLittle: 20
  property real fright: 0     // 0..1, red eyes
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

  function resetGhosts() {
    var r = rng(31)
    var n = Math.max(4, Math.min(7, Math.round(width / 300)))
    var g = []
    for (var i = 0; i < n; i++) {
      g.push({ ax: 0.06 + 0.88 * (i + 0.5) / n, ay: 0.16 + r() * 0.5, size: 64 + r() * 44,
               phase: r() * 6.28, speed: 0.45 + r() * 0.5, bob: 0, vx: 0, vy: 0, dx: 0, dy: 0 })
    }
    ghosts = g
  }

  // A key: one of them notices.
  function nudge() {
    if (ghosts.length === 0) return
    var g = ghosts[Math.floor(Math.random() * ghosts.length)]
    g.bob = 1
  }

  // A wrong password: eyes go red and they all fly outwards.
  function scare() {
    fright = 1
    boo = 1
    for (var i = 0; i < ghosts.length; i++) {
      var g = ghosts[i]
      g.vx = (g.ax - 0.5) * 1100 + (Math.random() - 0.5) * 300
      g.vy = -260 - Math.random() * 260
      g.bob = 1
    }
  }

  onWidthChanged: resetGhosts()
  onHeightChanged: resetGhosts()
  Component.onCompleted: resetGhosts()
  Typing { lock: lock; onTyped: lock.nudge() }

  Wallpaper { anchors.fill: parent; lock: lock; blur: 1; dim: 0.5; vignette: true }

  LockInput {
    id: input
    lock: lock
    width: 1; height: 1
    opacity: 0
    anchors.centerIn: parent
  }
  Rectangle { anchors.fill: parent; color: lock.withAlpha(lock.dusk, 0.55) }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: { lock.wakeRequested(); lock.forcePasswordFocus() }
    onPositionChanged: lock.wakeRequested()
  }

  Canvas {
    id: haunt
    anchors.fill: parent
    renderStrategy: Canvas.Cooperative

    function ghost(ctx, x, y, s, g, lookX, lookY) {
      var w = s, h = s * 1.3
      ctx.save()
      ctx.translate(x, y)
      // A soft glow behind the sheet. A gradient, not a canvas shadow: the
      // shadow is a software blur per fill and starves the shell at 30 fps.
      var halo = ctx.createRadialGradient(0, h * 0.25, s * 0.2, 0, h * 0.25, s * 1.1)
      halo.addColorStop(0, lock.withAlpha(lock.moon, 0.45))
      halo.addColorStop(0.6, lock.withAlpha(lock.moon, 0.12))
      halo.addColorStop(1, lock.withAlpha(lock.moon, 0))
      ctx.fillStyle = halo
      ctx.fillRect(-s * 1.2, -s * 0.9, s * 2.4, s * 2.6)
      // The sheet: a round head, straight sides, a scalloped hem.
      ctx.beginPath()
      ctx.moveTo(-w / 2, 0)
      ctx.arc(0, 0, w / 2, Math.PI, 0)
      ctx.lineTo(w / 2, h * 0.55)
      var folds = 4
      for (var i = 0; i < folds; i++) {
        var x0 = w / 2 - (i + 1) * (w / folds)
        var xm = x0 + w / folds / 2
        ctx.quadraticCurveTo(xm, h * 0.55 + (i % 2 === 0 ? s * 0.22 : -s * 0.05), x0, h * 0.55)
      }
      ctx.closePath()
      ctx.fillStyle = lock.withAlpha(lock.sheet, 0.88)
      ctx.fill()
      // Eyes, looking at the field; wide when nudged, red when frightened.
      var ex = s * 0.17, ey = -s * 0.02
      var er = s * 0.085 * (1 + g.bob * 0.35)
      var look = Math.atan2(lookY - y, lookX - x)
      var px = Math.cos(look) * er * 0.4, py = Math.sin(look) * er * 0.4
      var iris = Qt.rgba(lock.dusk.r + (lock.blood.r - lock.dusk.r) * lock.fright,
                         lock.dusk.g + (lock.blood.g - lock.dusk.g) * lock.fright,
                         lock.dusk.b + (lock.blood.b - lock.dusk.b) * lock.fright, 1)
      for (var side = -1; side <= 1; side += 2) {
        ctx.beginPath()
        ctx.ellipse(side * ex - er, ey - er * 1.25, er * 2, er * 2.5)
        ctx.fillStyle = iris
        ctx.fill()
        ctx.beginPath()
        ctx.arc(side * ex + px, ey + py, er * 0.35, 0, 6.2832)
        ctx.fillStyle = lock.withAlpha(lock.sheet, 0.9)
        ctx.fill()
      }
      // A small round mouth while it is bobbing.
      if (g.bob > 0.05) {
        ctx.beginPath()
        ctx.ellipse(-s * 0.06, s * 0.16, s * 0.12, s * 0.16 * g.bob)
        ctx.fillStyle = iris
        ctx.fill()
      }
      ctx.restore()
    }

    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      ctx.clearRect(0, 0, width, height)
      var at = fieldAnchor.mapToItem(lock, 0, 0)
      var lookX = at.x + fieldAnchor.width / 2, lookY = at.y + fieldAnchor.height / 2
      var g = lock.ghosts
      for (var i = 0; i < g.length; i++) {
        var o = g[i]
        var x = o.ax * width + Math.sin(lock.elapsed * o.speed + o.phase) * 26 + o.dx
        var y = o.ay * height + Math.cos(lock.elapsed * o.speed * 0.8 + o.phase) * 18 + o.dy - o.bob * 22
        ghost(ctx, x, y, o.size, o, lookX, lookY)
      }
    }
  }

  Timer {
    interval: 40
    running: haunt.visible && lock.animating
    repeat: true
    onRunningChanged: lock.lastTick = 0
    onTriggered: {
      var now = Date.now() / 1000
      var dt = lock.lastTick > 0 ? Math.min(0.1, now - lock.lastTick) : 0.033
      lock.lastTick = now
      lock.elapsed += dt
      var g = lock.ghosts
      for (var i = 0; i < g.length; i++) {
        var o = g[i]
        o.dx += o.vx * dt
        o.dy += o.vy * dt
        var damp = Math.pow(0.08, dt)
        o.vx *= damp
        o.vy *= damp
        // Back home once the push is spent.
        var home = Math.pow(0.35, dt)
        o.dx *= home
        o.dy *= home
        o.bob = Math.max(0, o.bob - dt * 1.8)
      }
      lock.fright = Math.max(0, lock.fright - dt * 0.35)
      lock.boo = Math.max(0, lock.boo - dt * 0.45)
      haunt.requestPaint()
    }
  }

  Connections {
    target: lock
    function onFailureMessageChanged() {
      if (lock.failureMessage.length > 0) lock.scare()
    }
  }

  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: column.top
    anchors.bottomMargin: 12
    text: "BOO"
    color: lock.blood
    opacity: lock.boo
    scale: 1.6 - lock.boo * 0.5
    font.family: Style.font.family
    font.pixelSize: Math.round(Style.font.baseSize * 7)
    font.weight: Font.Black
    font.letterSpacing: 12
    layer.enabled: true
    layer.effect: MultiEffect { shadowEnabled: true; shadowColor: lock.blood; shadowBlur: 1.0; shadowOpacity: 0.8 }
  }

  Column {
    id: column
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
    anchors.verticalCenterOffset: -Math.round(lock.height * 0.08)
    spacing: 30

    Column {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 6
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: lock.clock("HH:mm")
        color: "#ffffff"
        font.family: Style.font.family
        font.pixelSize: Math.round(Style.font.baseSize * 9)
        font.weight: Font.Bold
        font.letterSpacing: -2
        layer.enabled: true
        layer.effect: MultiEffect { shadowEnabled: true; shadowColor: lock.moon; shadowBlur: 0.9; shadowOpacity: 0.9; shadowVerticalOffset: 0 }
      }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: lock.date("dddd, d MMMM")
        color: lock.withAlpha(lock.moon, 0.9)
        font.family: Style.font.family
        font.pixelSize: Style.font.title
        font.letterSpacing: 3
      }
    }

  }

  // The little ones: one tiny ghost per character, in a row along the
  // bottom, bobbing at their own pace. Their eyes go red with the others' on
  // a wrong password; once the password is revealed each carries its letter.
  Item {
    id: fieldAnchor
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: Math.round(lock.height * 0.15)
    width: Math.max(260, Math.min(lock.lit, lock.maxLittle) * 40 + 40)
    height: 60

    Row {
      anchors.centerIn: parent
      spacing: 12
      Repeater {
        model: Math.min(lock.lit, lock.maxLittle)
        Item {
          id: little
          width: 28
          height: 40
          Component.onCompleted: { scale = 0.2; popIn.start() }
          NumberAnimation on scale { id: popIn; from: 0.2; to: 1; duration: 260; easing.type: Easing.OutBack; running: false }
          SequentialAnimation on y {
            loops: Animation.Infinite
            running: lock.animating
            NumberAnimation { from: 0; to: -7; duration: 900 + (index % 4) * 170; easing.type: Easing.InOutSine }
            NumberAnimation { from: -7; to: 0; duration: 900 + (index % 4) * 170; easing.type: Easing.InOutSine }
          }
          Canvas {
            id: sheet
            anchors.fill: parent
            Connections {
              target: lock
              function onErrorStateChanged() { sheet.requestPaint() }
              function onPasswordVisibleChanged() { sheet.requestPaint() }
            }
            onPaint: {
              var ctx = getContext("2d")
              ctx.reset()
              ctx.clearRect(0, 0, width, height)
              var w = 24, h = 30, x0 = (width - w) / 2, y0 = 4
              ctx.fillStyle = lock.withAlpha(lock.moon, 0.35)
              ctx.beginPath(); ctx.arc(width / 2, y0 + h * 0.5, w * 0.95, 0, 6.2832); ctx.fill()
              ctx.beginPath()
              ctx.moveTo(x0, y0 + w / 2)
              ctx.arc(x0 + w / 2, y0 + w / 2, w / 2, Math.PI, 0)
              ctx.lineTo(x0 + w, y0 + h)
              for (var i = 0; i < 3; i++) {
                var xa = x0 + w - (i + 1) * (w / 3), xm = xa + w / 6
                ctx.quadraticCurveTo(xm, y0 + h + (i % 2 === 0 ? 5 : -2), xa, y0 + h)
              }
              ctx.closePath()
              ctx.fillStyle = lock.withAlpha(lock.sheet, 0.92)
              ctx.fill()
              ctx.fillStyle = lock.errorState ? lock.blood : lock.dusk
              ctx.beginPath(); ctx.ellipse(x0 + w * 0.27, y0 + w * 0.32, 4, 5.5); ctx.fill()
              ctx.beginPath(); ctx.ellipse(x0 + w * 0.6, y0 + w * 0.32, 4, 5.5); ctx.fill()
              if (lock.passwordVisible) {
                ctx.fillStyle = lock.dusk
                ctx.font = "bold 12px " + Style.font.family
                ctx.textAlign = "center"
                ctx.fillText(lock.passwordText.charAt(index), width / 2, y0 + h - 4)
              }
            }
          }
        }
      }
      // Waiting: the outline of the next one, breathing.
      Canvas {
        width: 28
        height: 40
        visible: lock.inputEnabled && !lock.authenticatingPassword
        SequentialAnimation on opacity {
          loops: Animation.Infinite
          running: true
          NumberAnimation { from: 0.9; to: 0.2; duration: 700; easing.type: Easing.InOutSine }
          NumberAnimation { from: 0.2; to: 0.9; duration: 700; easing.type: Easing.InOutSine }
        }
        onPaint: {
          var ctx = getContext("2d")
          ctx.reset()
          ctx.clearRect(0, 0, width, height)
          var w = 24, h = 30, x0 = (width - w) / 2, y0 = 4
          ctx.beginPath()
          ctx.moveTo(x0, y0 + w / 2)
          ctx.arc(x0 + w / 2, y0 + w / 2, w / 2, Math.PI, 0)
          ctx.lineTo(x0 + w, y0 + h)
          for (var i = 0; i < 3; i++) {
            var xa = x0 + w - (i + 1) * (w / 3), xm = xa + w / 6
            ctx.quadraticCurveTo(xm, y0 + h + (i % 2 === 0 ? 5 : -2), xa, y0 + h)
          }
          ctx.closePath()
          ctx.strokeStyle = lock.withAlpha(lock.sheet, 0.8)
          ctx.lineWidth = 1.5
          ctx.setLineDash([3, 3])
          ctx.stroke()
        }
      }
    }

    Rectangle {
      anchors.bottom: parent.bottom
      anchors.horizontalCenter: parent.horizontalCenter
      width: parent.width
      height: 1
      color: lock.errorState ? lock.withAlpha(lock.blood, 0.7) : lock.withAlpha(lock.moon, 0.3)
      Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    }
    EyeButton {
      lock: lock
      anchors.left: parent.right
      anchors.leftMargin: 10
      anchors.verticalCenter: parent.verticalCenter
    }
  }

  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: fieldAnchor.top
    anchors.bottomMargin: 14
    opacity: lock.snapshotMode ? 0 : 1
    text: lock.authenticatingPassword ? lock.tr("Checking…")
      : (lock.errorState ? lock.failureMessage
      : (lock.lit === 0 ? "Who goes there?"
      : (lock.fingerprintConfigured ? lock.fingerprintHint(lock.tr("Type your password or touch the sensor")) : lock.tr("Type your password"))))
    textFormat: Text.PlainText
    color: lock.errorState ? lock.blood : lock.withAlpha(lock.moon, 0.7)
    font.family: Style.font.family
    font.pixelSize: Style.font.bodySmall
    font.letterSpacing: 2
    font.italic: lock.errorState
  }

  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 36
    opacity: lock.snapshotMode ? 0 : 1
    visible: lock.failedAttempts > 0
    text: lock.tr(lock.failedAttempts === 1 ? "1 failed attempt" : "%1 failed attempts").arg(lock.failedAttempts)
    textFormat: Text.PlainText
    color: lock.blood
    font.family: Style.font.family
    font.pixelSize: Style.font.bodySmall
    font.letterSpacing: 2
  }
}
