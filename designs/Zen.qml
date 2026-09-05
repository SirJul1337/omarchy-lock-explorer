import QtQuick
import QtQuick.Effects
import qs.Commons

DesignBase {
  id: lock
  inputItem: input
  shakeOnFail: true

  readonly property int dotCount: passwordText.length
  readonly property int maxDots: 24
  readonly property int dotSize: 14
  readonly property int dotGap: 14

  Wallpaper { anchors.fill: parent; lock: lock; blur: 1.0; dim: 0.25; vignetteTop: 0.4; vignetteMiddle: 0.25; vignetteBottom: 0.5 }

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

  Column {
    anchors.centerIn: parent
    anchors.verticalCenterOffset: -Math.round(parent.height * 0.06)
    spacing: 56

    Column {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 6
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.formatTime(lock.now, "HH:mm")
        color: Color.lock.text
        font.family: Style.font.family
        font.pixelSize: Math.round(Style.font.baseSize * 7)
        font.weight: Font.Light
        font.letterSpacing: 6
        layer.enabled: true
        layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Qt.rgba(0, 0, 0, 0.5); shadowBlur: 0.8; shadowVerticalOffset: 2 }
      }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.formatDate(lock.now, "dddd d MMMM").toUpperCase()
        color: lock.withAlpha(Color.lock.text, 0.65)
        font.family: Style.font.family
        font.pixelSize: Style.font.subtitle
        font.letterSpacing: 5
      }
    }

    Item {
      id: dotsArea
      anchors.horizontalCenter: parent.horizontalCenter
      width: Math.max(260, Math.min(lock.dotCount, lock.maxDots) * (lock.dotSize + lock.dotGap) + 40)
      height: 40

      Text {
        anchors.centerIn: parent
        visible: lock.passwordVisible && lock.dotCount > 0
        text: lock.passwordText
        textFormat: Text.PlainText
        color: lock.errorState ? Color.lock.textError : Color.lock.text
        font.family: Style.font.family
        font.pixelSize: Style.font.display
        font.letterSpacing: 2
      }

      Row {
        anchors.centerIn: parent
        visible: !lock.passwordVisible
        spacing: lock.dotGap
        Repeater {
          model: Math.min(lock.dotCount, lock.maxDots)
          Rectangle {
            width: lock.dotSize; height: lock.dotSize; radius: lock.dotSize / 2
            color: lock.errorState ? Color.lock.textError : Color.lock.text
            scale: 1
            Component.onCompleted: { scale = 0.2; popIn.start() }
            NumberAnimation on scale { id: popIn; from: 0.2; to: 1; duration: 140; easing.type: Easing.OutBack; running: false }
          }
        }
      }

      Rectangle {
        anchors.centerIn: parent
        width: 2; height: 22
        color: lock.withAlpha(Color.lock.text, 0.8)
        visible: lock.dotCount === 0 && lock.inputEnabled && !lock.authenticatingPassword && !lock.errorState
        SequentialAnimation on opacity {
          loops: Animation.Infinite
          running: true
          NumberAnimation { from: 1; to: 0; duration: 500 }
          NumberAnimation { from: 0; to: 1; duration: 500 }
        }
      }

      EyeButton {
        lock: lock
        anchors.left: parent.right
        anchors.leftMargin: 6
        anchors.verticalCenter: parent.verticalCenter
      }

      Rectangle {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width
        height: 1
        color: lock.errorState ? Color.lock.textError : (lock.authenticatingPassword ? Color.lock.borderActive : lock.withAlpha(Color.lock.text, 0.35))
        Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
      }
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: lock.authenticatingPassword ? "Checking…"
        : (lock.errorState ? lock.failureMessage
        : (lock.fingerprintConfigured ? "Type your password or touch the sensor" : "Type your password"))
      textFormat: Text.PlainText
      color: lock.errorState ? Color.lock.textError : lock.withAlpha(Color.lock.text, 0.55)
      font.family: Style.font.family
      font.pixelSize: Style.font.body
      font.letterSpacing: 2
      font.italic: lock.errorState
    }
  }
}
