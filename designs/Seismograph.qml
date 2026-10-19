import QtQuick
import qs.Commons
import qs.Commons as Commons

// Seismograph: a strip chart scrolling under a pen, in the theme's colours.
// Left alone the trace is a faint tremble; every key is a sharp event the
// pen records and the picks row logs, and a wrong password is a quake that
// takes seconds to settle. The clock is the station's time stamp.
DesignBase {
  id: lock
  inputItem: input
  shakeOnFail: false
  flashOnFail: false

  readonly property color ink: lock.withAlpha(Commons.Color.lock.text, 1)
  readonly property color pen: lock.withAlpha(Commons.Color.lock.borderActive, 1)
  readonly property color red: Commons.Color.lock.textError
  readonly property color bg: lock.deepen(Commons.Color.background, 1.3)
  readonly property int lit: passwordText.length

  property var samples: []        // the trace, newest last, in px
  property var packets: []        // live events: { age, amp, freq, decay }
  property real quake: 0          // 0..1 after a wrong password
  property real elapsed: 0
  property real lastTick: 0
  readonly property int sampleCount: 720
  readonly property real magnitude: Math.min(9.9, lit === 0 ? 0 : 1.2 + lit * 0.55 + quake * 4)

  function event(amp, freq, decay) {
    var p = packets
    p.push({ age: 0, amp: amp, freq: freq, decay: decay })
    if (p.length > 40) p.splice(0, p.length - 40)
  }
  function scare() { quake = 1; event(1, 9, 0.55) }

  Typing { id: typing; lock: lock; onTyped: lock.event(0.3 + Math.min(0.3, typing.cadence * 0.05), 22 + Math.random() * 12, 3.2) }

  Component.onCompleted: {
    var s = []
    for (var i = 0; i < sampleCount; i++) s.push(0)
    samples = s
  }

  Rectangle { anchors.fill: parent; color: lock.bg }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: { lock.wakeRequested(); lock.forcePasswordFocus() }
    onPositionChanged: lock.wakeRequested()
  }

  LockInput {
    id: input
    lock: lock
    width: 1; height: 1
    opacity: 0
    anchors.centerIn: parent
  }

  // The station header and the time stamp.
  Row {
    anchors.left: chart.left
    anchors.bottom: chart.top
    anchors.bottomMargin: 22
    spacing: 40
    Column {
      spacing: 4
      Text {
        text: lock.tr("STATION") + "  " + lock.hostName.toUpperCase() + "   ·   HHZ"
        textFormat: Text.PlainText
        color: lock.withAlpha(lock.ink, 0.6)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        font.letterSpacing: 3
      }
      Text {
        text: lock.clock("HH:mm")
        color: lock.ink
        font.family: Style.font.family
        font.pixelSize: Math.round(Style.font.baseSize * 6)
        font.weight: Font.Bold
        font.letterSpacing: -1
      }
      Text {
        text: lock.date("dddd, d MMMM yyyy").toUpperCase()
        color: lock.withAlpha(lock.ink, 0.7)
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        font.letterSpacing: 2
      }
    }
  }

  // The readouts, right of the header.
  Column {
    anchors.right: chart.right
    anchors.bottom: chart.top
    anchors.bottomMargin: 26
    spacing: 8
    Repeater {
      model: [
        { k: "M", v: lock.magnitude.toFixed(1), hot: lock.quake > 0.2 },
        { k: lock.tr("EVENTS"), v: String(lock.lit), hot: false },
        { k: lock.tr("STATUS"), v: lock.quake > 0.2 ? lock.tr("TREMOR") : (lock.lit > 0 ? lock.tr("RECORDING") : lock.tr("QUIET")), hot: lock.quake > 0.2 }
      ]
      Row {
        anchors.right: parent.right
        spacing: 14
        Text {
          text: modelData.k
          textFormat: Text.PlainText
          color: lock.withAlpha(lock.ink, 0.5)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          font.letterSpacing: 3
          anchors.baseline: value.baseline
        }
        Text {
          id: value
          text: modelData.v
          textFormat: Text.PlainText
          color: modelData.hot ? lock.red : lock.ink
          font.family: Style.font.family
          font.pixelSize: Style.font.title
          font.weight: Font.Bold
        }
      }
    }
  }

  // The chart: paper, grid, trace.
  Rectangle {
    id: chart
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
    anchors.verticalCenterOffset: Math.round(lock.height * 0.02)
    width: Math.round(lock.width * 0.72)
    height: Math.round(lock.height * 0.36)
    color: lock.withAlpha(lock.ink, 0.05)
    border.width: 1
    border.color: lock.withAlpha(lock.ink, 0.35)
    clip: true

    Canvas {
      id: trace
      anchors.fill: parent
      renderStrategy: Canvas.Cooperative
      onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        ctx.clearRect(0, 0, width, height)
        var mid = height / 2
        // Grid: a line every 10 s of paper, a faint one every 2.
        var step = width / 24
        for (var g = 0; g <= 24; g++) {
          var gx = Math.round(g * step) + 0.5
          ctx.strokeStyle = lock.withAlpha(lock.ink, g % 5 === 0 ? 0.22 : 0.08)
          ctx.lineWidth = 1
          ctx.beginPath(); ctx.moveTo(gx, 0); ctx.lineTo(gx, height); ctx.stroke()
        }
        for (var r = 1; r < 6; r++) {
          var gy = Math.round(r * height / 6) + 0.5
          ctx.strokeStyle = lock.withAlpha(lock.ink, r === 3 ? 0.25 : 0.08)
          ctx.beginPath(); ctx.moveTo(0, gy); ctx.lineTo(width, gy); ctx.stroke()
        }
        // The trace, pen colour, red while the quake lasts.
        var s = lock.samples
        var n = s.length
        var c = lock.quake > 0.05 ? Qt.rgba(lock.pen.r + (lock.red.r - lock.pen.r) * lock.quake, lock.pen.g + (lock.red.g - lock.pen.g) * lock.quake, lock.pen.b + (lock.red.b - lock.pen.b) * lock.quake, 1) : lock.pen
        ctx.strokeStyle = c
        ctx.lineWidth = 1.6
        ctx.lineJoin = "round"
        ctx.beginPath()
        for (var i = 0; i < n; i++) {
          var x = i / (n - 1) * width
          var y = mid - Math.max(-mid + 4, Math.min(mid - 4, s[i]))
          if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
        }
        ctx.stroke()
        // The pen.
        ctx.fillStyle = lock.ink
        var py = mid - Math.max(-mid + 4, Math.min(mid - 4, s[n - 1]))
        ctx.beginPath(); ctx.arc(width - 2, py, 3.5, 0, 6.2832); ctx.fill()
        ctx.strokeStyle = lock.withAlpha(lock.ink, 0.5)
        ctx.beginPath(); ctx.moveTo(width - 2, py); ctx.lineTo(width - 2, 0); ctx.stroke()
      }
    }
  }

  Timer {
    interval: 33
    running: trace.visible && lock.animating
    repeat: true
    onRunningChanged: lock.lastTick = 0
    onTriggered: {
      var now = Date.now() / 1000
      var dt = lock.lastTick > 0 ? Math.min(0.1, now - lock.lastTick) : 0.033
      lock.lastTick = now
      lock.elapsed += dt
      var amp = chart.height * 0.42
      var v = Math.sin(lock.elapsed * 7.3) * 1.2 + Math.sin(lock.elapsed * 19) * 0.8 + (Math.random() - 0.5) * 1.6
      var p = lock.packets
      for (var i = p.length - 1; i >= 0; i--) {
        var k = p[i]
        k.age += dt
        var env = Math.exp(-k.age * k.decay) * (1 - Math.exp(-k.age * 40))
        v += Math.sin(k.age * k.freq * 6.2832) * k.amp * amp * env
        if (env < 0.01 && k.age > 0.2) p.splice(i, 1)
      }
      if (lock.quake > 0.05) v += (Math.random() - 0.5) * amp * lock.quake * 0.8
      var s = lock.samples
      s.push(v)
      if (s.length > lock.sampleCount) s.splice(0, s.length - lock.sampleCount)
      lock.quake = Math.max(0, lock.quake - dt * 0.35)
      trace.requestPaint()
    }
  }

  Connections {
    target: lock
    function onFailureMessageChanged() {
      if (lock.failureMessage.length > 0) lock.scare()
    }
  }

  // The picks row: one mark per character, the characters once revealed.
  Item {
    id: picks
    anchors.left: chart.left
    anchors.right: chart.right
    anchors.top: chart.bottom
    anchors.topMargin: 18
    height: 44

    Rectangle {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      height: 1
      color: lock.withAlpha(lock.ink, 0.3)
    }
    Text {
      anchors.left: parent.left
      anchors.bottom: parent.top
      anchors.bottomMargin: 2
      text: lock.authenticatingPassword ? lock.tr("Checking…").toUpperCase() : (lock.errorState ? lock.failureMessage.toUpperCase() : lock.tr("Type your password").toUpperCase())
      textFormat: Text.PlainText
      color: lock.errorState ? lock.red : lock.withAlpha(lock.ink, 0.5)
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      font.letterSpacing: 3
    }
    Row {
      anchors.left: parent.left
      anchors.leftMargin: 4
      anchors.verticalCenter: parent.verticalCenter
      spacing: 14
      Repeater {
        model: Math.min(lock.lit, 40)
        Item {
          width: 10
          height: 30
          Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            width: 2
            height: lock.passwordVisible ? 0 : 22
            color: lock.errorState ? lock.red : lock.pen
            Component.onCompleted: { scale = 0.2; popIn.start() }
            NumberAnimation on scale { id: popIn; from: 0.2; to: 1; duration: 140; easing.type: Easing.OutBack; running: false }
          }
          Text {
            anchors.centerIn: parent
            visible: lock.passwordVisible
            text: lock.passwordText.charAt(index)
            textFormat: Text.PlainText
            color: lock.ink
            font.family: Style.font.family
            font.pixelSize: Style.font.body
          }
        }
      }
      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 2
        height: 22
        color: lock.withAlpha(lock.ink, 0.8)
        visible: lock.inputEnabled && !lock.authenticatingPassword
        SequentialAnimation on opacity {
          loops: Animation.Infinite
          running: true
          NumberAnimation { from: 1; to: 0; duration: 500 }
          NumberAnimation { from: 0; to: 1; duration: 500 }
        }
      }
    }
    EyeButton {
      lock: lock
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
    }
  }

  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 36
    opacity: lock.snapshotMode ? 0 : 1
    text: lock.failedAttempts > 0
      ? lock.tr(lock.failedAttempts === 1 ? "1 failed attempt" : "%1 failed attempts").arg(lock.failedAttempts)
      : (lock.fingerprintConfigured ? lock.fingerprintHint(lock.tr("󰆠  Touch sensor or type password")) : "")
    textFormat: Text.PlainText
    color: lock.failedAttempts > 0 ? lock.red : lock.withAlpha(lock.ink, 0.5)
    font.family: Style.font.family
    font.pixelSize: Style.font.bodySmall
    font.letterSpacing: 1
  }
}
