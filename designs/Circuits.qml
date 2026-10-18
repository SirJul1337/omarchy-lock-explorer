import QtQuick
import qs.Commons

// Time circuits. Three readouts, red for where you are going, green for where
// you are and amber for where you were, with flux sparks crawling along the
// bottom of the screen that jump when you type. A wrong password makes the
// displays flicker.
DesignBase {
  id: lock
  inputItem: field.input

  readonly property color red: Qt.rgba(1, 0.2, 0.12, 1)
  readonly property color green: Qt.rgba(0.2, 1, 0.35, 1)
  readonly property color amber: Qt.rgba(1, 0.72, 0.1, 1)
  // 1 while the displays are acting up after a wrong password.
  property real glitch: 0
  // Flickers between lit and dark while glitching, driven by the frame timer.
  property real flicker: 1

  Rectangle { anchors.fill: parent; color: Color.background }

  // One readout row: a label above a plate holding the lit digits over a
  // faint grid of unlit ones.
  component Readout: Item {
    id: readout
    property string label: ""
    property color tint: lock.green
    property string month: "OCT"
    property string day: "26"
    property string year: "1985"
    property string time: "01:21"
    property string meridiem: "AM"

    width: row.width + 36
    height: 86 + 22

    Text {
      id: caption
      anchors.horizontalCenter: parent.horizontalCenter
      text: readout.label
      color: lock.withAlpha(Color.lock.text, 0.6)
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      font.letterSpacing: 3
    }
    Rectangle {
      anchors.top: caption.bottom
      anchors.topMargin: 6
      anchors.horizontalCenter: parent.horizontalCenter
      width: parent.width
      height: 78
      radius: 6
      color: "#0b0b0b"
      border.width: 2
      border.color: lock.withAlpha(Color.lock.text, 0.25)

      Row {
        id: row
        anchors.centerIn: parent
        spacing: 18
        opacity: lock.flicker

        Repeater {
          model: [
            { lit: readout.month, ghost: "888", size: 40 },
            { lit: readout.day, ghost: "88", size: 40 },
            { lit: readout.year, ghost: "8888", size: 40 },
            { lit: readout.time, ghost: "88:88", size: 40 },
            { lit: readout.meridiem, ghost: "88", size: 22 }
          ]
          delegate: Item {
            width: ghostText.width
            height: ghostText.height
            anchors.verticalCenter: parent.verticalCenter
            Text {
              id: ghostText
              text: modelData.ghost
              color: lock.withAlpha(readout.tint, 0.1)
              font.family: "monospace"
              font.bold: true
              font.pixelSize: modelData.size
            }
            Text {
              anchors.right: ghostText.right
              text: modelData.lit
              color: readout.tint
              font.family: "monospace"
              font.bold: true
              font.pixelSize: modelData.size
              style: Text.Outline
              styleColor: lock.withAlpha(readout.tint, 0.3)
            }
          }
        }
      }
    }
  }

  Canvas {
    id: flux
    anchors.fill: parent

    property real lastTime: 0
    property real energy: 0.15
    property var bolts: []
    property real since: 0

    function spark(count) {
      var list = bolts.slice(-30)
      for (var i = 0; i < count; i++)
        list.push({ x: Math.random(), life: 1, size: 0.5 + Math.random() })
      bolts = list
    }

    function step(dt) {
      since += dt
      // A trickle of sparks, a flood while typing.
      if (since > 0.18 / (1 + energy * 6)) { since = 0; spark(1) }
      energy = Math.max(0.15, energy - dt * 0.8)
      for (var i = 0; i < bolts.length; i++) bolts[i].life -= dt * 2.2
      bolts = bolts.filter(function(b) { return b.life > 0 })

      lock.glitch = Math.max(0, lock.glitch - dt * 0.7)
      lock.flicker = lock.glitch > 0 ? (Math.random() < 0.45 ? 0.15 : 1) : 1
    }

    onPaint: {
      var ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)
      var c = Color.lock.borderActive
      var y0 = height - 3
      ctx.lineWidth = 1.5

      // The conduit along the bottom.
      ctx.fillStyle = Qt.rgba(c.r, c.g, c.b, 0.15 + energy * 0.2)
      ctx.fillRect(0, y0, width, 3)

      for (var i = 0; i < bolts.length; i++) {
        var b = bolts[i]
        var x = b.x * width
        var h = (30 + 90 * energy) * b.size * b.life
        ctx.strokeStyle = Qt.rgba(1, 1, 1, Math.min(1, b.life * 1.2))
        ctx.beginPath()
        ctx.moveTo(x, y0)
        for (var s = 1; s <= 5; s++)
          ctx.lineTo(x + (Math.random() - 0.5) * 22, y0 - h * s / 5)
        ctx.stroke()
        ctx.strokeStyle = Qt.rgba(c.r, c.g, c.b, b.life * 0.5)
        ctx.lineWidth = 4
        ctx.beginPath()
        ctx.moveTo(x, y0); ctx.lineTo(x + (Math.random() - 0.5) * 10, y0 - h)
        ctx.stroke()
        ctx.lineWidth = 1.5
      }
    }

    Timer {
      interval: 33
      repeat: true
      running: lock.animating
      onTriggered: {
        var now = Date.now()
        var dt = flux.lastTime > 0 ? Math.min(0.1, (now - flux.lastTime) / 1000) : 0.033
        flux.lastTime = now
        flux.step(dt)
        flux.requestPaint()
      }
      onRunningChanged: if (!running) flux.lastTime = 0
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
    onTyped: { flux.energy = Math.min(1, flux.energy + 0.35); flux.spark(3) }
    onDeleted: flux.energy = Math.min(1, flux.energy + 0.15)
    onCleared: { flux.energy = 1; flux.spark(10) }
  }

  Connections {
    target: lock
    function onFailureMessageChanged() {
      if (lock.failureMessage.length > 0) { lock.glitch = 1; flux.energy = 1; flux.spark(14) }
    }
  }

  Column {
    anchors.centerIn: parent
    anchors.verticalCenterOffset: -Math.round(lock.height * 0.06)
    spacing: 10
    opacity: lock.snapshotMode ? 0 : 1

    Readout {
      anchors.horizontalCenter: parent.horizontalCenter
      label: "DESTINATION TIME"
      tint: lock.red
    }
    Readout {
      anchors.horizontalCenter: parent.horizontalCenter
      label: "PRESENT TIME"
      tint: lock.green
      month: lock.date("MMM").toUpperCase()
      day: lock.date("dd")
      year: lock.date("yyyy")
      time: lock.date("hh:mm")
      meridiem: lock.date("AP").toUpperCase()
    }
    Readout {
      anchors.horizontalCenter: parent.horizontalCenter
      label: "LAST TIME DEPARTED"
      tint: lock.amber
      month: "NOV"
      day: "05"
      year: "1955"
      time: "06:00"
    }
  }

  PasswordField {
    id: field
    lock: lock
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: Math.round(lock.height * 0.1)
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
    anchors.bottomMargin: Math.round(lock.height * 0.1) - 36
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
