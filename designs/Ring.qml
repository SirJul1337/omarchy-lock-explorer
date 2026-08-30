import QtQuick
import qs.Commons

DesignBase {
  id: lock
  inputItem: input
  shakeOnFail: true

  readonly property int ringSize: 320
  readonly property int ringWidth: 8
  readonly property int maxSegments: 12
  readonly property real progress: Math.min(passwordText.length, maxSegments) / maxSegments
  readonly property color ringColor: errorState ? Color.lock.textError : Color.lock.borderActive

  Wallpaper { anchors.fill: parent; lock: lock; blur: 0.9; dim: 0.15 }

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
  }

  Item {
    id: ring
    width: lock.ringSize
    height: lock.ringSize
    anchors.centerIn: parent
    anchors.verticalCenterOffset: -20

    Canvas {
      id: track
      anchors.fill: parent
      onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        var c = width / 2
        var r = c - lock.ringWidth
        ctx.lineWidth = lock.ringWidth
        ctx.strokeStyle = lock.withAlpha(Color.lock.text, 0.18)
        ctx.beginPath()
        ctx.arc(c, c, r, 0, Math.PI * 2)
        ctx.stroke()
      }
    }

    Canvas {
      id: arc
      anchors.fill: parent
      property real value: lock.progress
      property color color: lock.ringColor
      Behavior on value { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
      onValueChanged: requestPaint()
      onColorChanged: requestPaint()
      onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        if (value <= 0) return
        var c = width / 2
        var r = c - lock.ringWidth
        ctx.lineWidth = lock.ringWidth
        ctx.lineCap = "round"
        ctx.strokeStyle = color
        ctx.beginPath()
        ctx.arc(c, c, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * value)
        ctx.stroke()
      }
    }

    Canvas {
      id: spinner
      anchors.fill: parent
      visible: lock.authenticatingPassword
      onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        var c = width / 2
        var r = c - lock.ringWidth
        ctx.lineWidth = lock.ringWidth
        ctx.lineCap = "round"
        ctx.strokeStyle = Color.lock.borderActive
        ctx.beginPath()
        ctx.arc(c, c, r, 0, Math.PI * 0.4)
        ctx.stroke()
      }
      RotationAnimation on rotation {
        from: 0; to: 360; duration: 900
        loops: Animation.Infinite
        running: spinner.visible
      }
    }

    Column {
      anchors.centerIn: parent
      spacing: 6
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.formatTime(lock.now, "HH:mm")
        color: Color.lock.text
        font.family: Style.font.family
        font.pixelSize: Math.round(Style.font.baseSize * 6)
        font.weight: Font.DemiBold
        font.letterSpacing: -1
      }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.formatDate(lock.now, "ddd d MMM").toUpperCase()
        color: lock.withAlpha(Color.lock.text, 0.65)
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        font.letterSpacing: 4
      }
    }
  }

  Column {
    anchors.top: ring.bottom
    anchors.topMargin: 36
    anchors.horizontalCenter: parent.horizontalCenter
    spacing: 8
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: lock.userName
      color: Color.lock.text
      font.family: Style.font.family
      font.pixelSize: Style.font.heading
      font.weight: Font.DemiBold
    }
    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 6
      Text {
        anchors.verticalCenter: parent.verticalCenter
        opacity: lock.snapshotMode ? 0 : 1
        text: lock.authenticatingPassword ? "Checking…"
          : (lock.errorState ? lock.failureMessage
          : (lock.passwordText.length > 0
            ? (lock.passwordVisible ? lock.passwordText : lock.passwordText.length + " characters, Enter to unlock")
            : (lock.fingerprintConfigured ? "Type your password or touch the sensor" : "Type your password")))
        color: lock.errorState ? Color.lock.textError : (lock.passwordVisible && lock.passwordText.length > 0 ? Color.lock.text : lock.withAlpha(Color.lock.text, 0.55))
        font.family: Style.font.family
        font.pixelSize: lock.passwordVisible && lock.passwordText.length > 0 ? Style.font.heading : Style.font.body
        font.italic: lock.errorState
      }
      EyeButton { lock: lock; anchors.verticalCenter: parent.verticalCenter; size: Style.font.title }
    }
  }
}
