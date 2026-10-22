import QtQuick
import qs.Commons

// The jump to lightspeed. Stars stream out from the middle of the screen and
// stretch into streaks as the ship speeds up. Every keystroke is a burst of
// speed, a wrong password is a full jump.
DesignBase {
  id: lock
  inputItem: field.input

  readonly property int starCount: 320
  // 0 is a slow cruise, 1 is the stars fully stretched.
  property real boost: 0

  Rectangle { anchors.fill: parent; color: Color.background }

  Canvas {
    id: space
    anchors.fill: parent

    // One field of stars with real depth. A star far away sits out in the
    // screen and crawls, one close by races past in a streak, same as the
    // rest, so the two never look like separate layers.
    property var stars: []
    property real speed: 0.12
    property real lastTime: 0

    function spawn(star, fresh) {
      star.angle = Math.random() * Math.PI * 2
      // Distance from the middle in world units, evenly over the area.
      star.rho = 0.03 + Math.sqrt(Math.random()) * 0.97
      // Depth runs from 1 (far away) to 0 (right at the screen).
      star.z = fresh ? 0.05 + Math.random() * 0.95 : 1
      star.tint = Math.random() < 0.2
    }

    Component.onCompleted: {
      var list = []
      for (var i = 0; i < lock.starCount; i++) {
        var star = {}
        spawn(star, true)
        list.push(star)
      }
      stars = list
    }

    function step(dt) {
      var target = 0.12 + lock.boost * 3.4
      speed += (target - speed) * Math.min(1, dt * 4)
      lock.boost = Math.max(0, lock.boost - dt * 0.8)
      for (var i = 0; i < stars.length; i++) {
        var star = stars[i]
        star.z -= speed * dt * 0.35
        // Gone once it has flown past the edge of the screen.
        if (star.z <= star.rho * 0.95 || star.z <= 0.02) spawn(star, false)
      }
    }

    onPaint: {
      var ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)
      var cx = width / 2
      var cy = height / 2
      var reach = Math.sqrt(cx * cx + cy * cy)
      var base = Color.lock.text
      var accent = Color.lock.borderActive
      ctx.lineCap = "round"

      for (var i = 0; i < stars.length; i++) {
        var star = stars[i]
        var tail = Math.min(1, star.z + speed * 0.05)
        var cos = Math.cos(star.angle)
        var sin = Math.sin(star.angle)
        var rHead = star.rho / star.z * reach
        var rTail = star.rho / tail * reach
        var near = 1 - star.z
        var color = star.tint ? accent : base
        var alpha = Math.min(1, near * 12) * (0.2 + 0.8 * Math.pow(near, 1.5))
        ctx.strokeStyle = Qt.rgba(color.r, color.g, color.b, alpha)
        ctx.lineWidth = 0.5 + near * near * 2.4
        ctx.beginPath()
        ctx.moveTo(cx + cos * rTail, cy + sin * rTail)
        ctx.lineTo(cx + cos * rHead + 0.01, cy + sin * rHead)
        ctx.stroke()
      }
    }

    Timer {
      interval: 16
      repeat: true
      running: lock.animating
      onTriggered: {
        var now = Date.now()
        var dt = space.lastTime > 0 ? Math.min(0.1, (now - space.lastTime) / 1000) : 0.016
        space.lastTime = now
        space.step(dt)
        space.requestPaint()
      }
      onRunningChanged: if (!running) space.lastTime = 0
    }
  }

  // A soft glow where the stars come from, brighter the faster you go.
  Rectangle {
    anchors.centerIn: parent
    width: Math.min(lock.width, lock.height) * (0.5 + lock.boost * 0.5)
    height: width
    radius: width / 2
    opacity: 0.05 + lock.boost * 0.2
    gradient: Gradient {
      GradientStop { position: 0; color: Color.lock.borderActive }
      GradientStop { position: 1; color: "transparent" }
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
    onTyped: lock.boost = Math.min(1, lock.boost + 0.3 + Math.min(0.3, typing.cadence * 0.05))
    onDeleted: lock.boost = Math.min(1, lock.boost + 0.12)
    onCleared: lock.boost = 1
  }

  Connections {
    target: lock
    function onFailureMessageChanged() {
      if (lock.failureMessage.length > 0) lock.boost = 1
    }
  }

  Column {
    anchors.centerIn: parent
    anchors.verticalCenterOffset: -Math.round(lock.height * 0.08)
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
    anchors.verticalCenterOffset: Math.round(lock.height * 0.16)
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
