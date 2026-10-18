import QtQuick
import qs.Commons

// The motion tracker from Aliens. Things are moving out there, closing on the
// middle of the dial, and you only see them when the sweep goes over them.
// Each key you press sends another one in. When something gets close the
// readout speeds up and the dial goes red, and if one reaches you it is
// caught in the middle. A wrong password sends a swarm.
DesignBase {
  id: lock
  inputItem: field.input

  // Briefly 1 after a wrong password, flashes the dial.
  property real flash: 0
  // How close the nearest contact is, 0 (far) to 1 (on top of you).
  property real danger: 0

  Rectangle { anchors.fill: parent; color: Color.background }

  Canvas {
    id: radar
    anchors.fill: parent

    property real arm: 0
    property real speed: 1.4
    property real lastTime: 0
    property real beep: 0
    property real beepClock: 0
    property real caught: 0
    // Contacts: { angle, dist 0..1, rate, seenAt: {x, y} or null, seen 0..1, ping 0..1 }
    property var contacts: []
    property var trails: []

    Component.onCompleted: send(3, 0.45)

    function send(count, from) {
      var list = contacts.slice(-13)
      for (var i = 0; i < count; i++)
        list.push({
          angle: Math.random() * Math.PI * 2,
          dist: from + Math.random() * (1 - from) * 0.4,
          rate: 0.018 + Math.random() * 0.03,
          wobble: Math.random() * 6,
          seen: 0, ping: 0, sx: 0, sy: 0
        })
      contacts = list
    }

    function step(dt) {
      var want = 1.4 + Math.min(3, typing.cadence * 0.7)
      speed += (want - speed) * Math.min(1, dt * 3)
      var prev = arm
      arm = (arm + speed * dt) % (Math.PI * 2)
      lock.flash = Math.max(0, lock.flash - dt * 0.8)
      caught = Math.max(0, caught - dt * 1.2)
      beepClock += dt
      beep = Math.max(0, beep - dt * 4)

      var nearest = 1
      var alive = []
      for (var i = 0; i < contacts.length; i++) {
        var c = contacts[i]
        // Things creep in towards the middle, weaving a little.
        c.dist -= c.rate * dt
        c.angle += Math.sin(beepClock * 0.7 + c.wobble) * 0.02 * dt
        c.seen = Math.max(0, c.seen - dt * 0.28)
        c.ping = Math.max(0, c.ping - dt * 1.3)
        // The sweep crossed this contact since the last frame: it shows up.
        var da = ((c.angle - prev) % (Math.PI * 2) + Math.PI * 2) % (Math.PI * 2)
        var span = ((arm - prev) % (Math.PI * 2) + Math.PI * 2) % (Math.PI * 2)
        if (da <= span) { c.seen = 1; c.ping = 1; c.sx = c.dist; c.sa = c.angle }
        nearest = Math.min(nearest, c.dist)
        if (c.dist <= 0.04) { caught = 1; lock.flash = Math.max(lock.flash, 0.6); continue }
        alive.push(c)
      }
      contacts = alive
      if (contacts.length < 3) send(1, 0.9)
      lock.danger = Math.max(0, 1 - nearest / 0.45)
      // Beeps tick faster the closer the nearest contact is.
      if (beepClock > 0.9 - lock.danger * 0.7) { beepClock = 0; beep = 1 }
    }

    onPaint: {
      var ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)
      var cx = width / 2
      var cy = height / 2
      var R = Math.min(width, height) * 0.42
      var tau = Math.PI * 2
      var base = Color.lock.borderActive
      var err = Color.lock.textError
      // The dial warms from the theme color to red as things close in.
      var m = Math.max(lock.danger, lock.flash)
      var col = Qt.rgba(base.r + (err.r - base.r) * m, base.g + (err.g - base.g) * m, base.b + (err.b - base.b) * m, 1)

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

      // Contacts, shown where the sweep last found them.
      ctx.font = "bold 13px monospace"
      var seenNow = 0
      var nearest = 99
      for (var i = 0; i < contacts.length; i++) {
        var c = contacts[i]
        nearest = Math.min(nearest, c.dist)
        if (c.seen < 0.03) continue
        seenNow++
        var bx = cx + Math.cos(c.sa) * c.sx * R
        var by = cy + Math.sin(c.sa) * c.sx * R
        // The ring that goes out when the sweep finds it.
        if (c.ping > 0) {
          ctx.strokeStyle = Qt.rgba(col.r, col.g, col.b, c.ping * 0.8)
          ctx.lineWidth = 2
          ctx.beginPath(); ctx.arc(bx, by, 6 + (1 - c.ping) * 34, 0, tau); ctx.stroke()
        }
        // A dot, with a tail pointing back to where it was heading from.
        ctx.fillStyle = Qt.rgba(col.r, col.g, col.b, c.seen)
        ctx.beginPath(); ctx.arc(bx, by, 4 + c.seen * 3, 0, tau); ctx.fill()
        ctx.strokeStyle = Qt.rgba(col.r, col.g, col.b, c.seen * 0.6)
        ctx.lineWidth = 2
        ctx.beginPath()
        ctx.moveTo(bx, by)
        ctx.lineTo(bx + Math.cos(c.sa) * 18, by + Math.sin(c.sa) * 18)
        ctx.stroke()
        ctx.fillStyle = Qt.rgba(col.r, col.g, col.b, c.seen * 0.9)
        ctx.fillText((c.sx * 20).toFixed(1), bx + 10, by - 8)
      }

      // The middle, which gets a flash when something reaches it.
      if (caught > 0) {
        ctx.strokeStyle = Qt.rgba(err.r, err.g, err.b, caught)
        ctx.lineWidth = 3
        ctx.beginPath(); ctx.arc(cx, cy, R * (0.1 + (1 - caught) * 0.5), 0, tau); ctx.stroke()
      }

      // Readout: range to the nearest contact, with a beep lamp, and a count.
      ctx.font = "bold 22px monospace"
      ctx.fillStyle = Qt.rgba(col.r, col.g, col.b, 0.95)
      ctx.fillText(contacts.length > 0 ? (nearest * 20).toFixed(1) + " M" : "-- M", cx + R * 0.55, cy + R * 0.95)
      ctx.font = "13px monospace"
      ctx.fillStyle = Qt.rgba(col.r, col.g, col.b, 0.7)
      ctx.fillText("CONTACTS " + contacts.length + "   TRACKED " + seenNow, cx - R, cy + R * 0.95)
      ctx.fillStyle = Qt.rgba(col.r, col.g, col.b, 0.2 + beep * 0.8)
      ctx.beginPath(); ctx.arc(cx + R * 0.5, cy + R * 0.95 - 8, 6, 0, tau); ctx.fill()
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
    onTyped: radar.send(1, 0.7)
    onDeleted: radar.send(0, 0.7)
    onCleared: radar.send(4, 0.8)
  }

  Connections {
    target: lock
    function onFailureMessageChanged() {
      if (lock.failureMessage.length > 0) { radar.send(8, 0.55); lock.flash = 1 }
    }
  }

  Column {
    anchors.centerIn: parent
    anchors.verticalCenterOffset: -Math.round(lock.height * 0.0)
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
