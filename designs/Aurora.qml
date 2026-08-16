import QtQuick
import QtQuick.Effects
import qs.Commons

DesignBase {
  id: lock
  inputItem: field.input

  readonly property color c1: Color.lock.borderActive
  readonly property color c2: Qt.hsla((c1.hslHue + 0.12) % 1, Math.max(0.35, c1.hslSaturation), 0.5, 1)
  readonly property color c3: Qt.hsla((c1.hslHue + 0.85) % 1, Math.max(0.35, c1.hslSaturation), 0.45, 1)

  Rectangle { anchors.fill: parent; color: Color.background }

  Item {
    id: blobs
    anchors.fill: parent
    layer.enabled: true
    layer.effect: MultiEffect { blurEnabled: true; blur: 1.0; blurMax: 64; blurMultiplier: 2.5 }

    Rectangle {
      id: b1
      width: lock.width * 0.55; height: width; radius: width / 2
      color: lock.c1; opacity: 0.6
      x: -width * 0.2; y: -height * 0.3
      SequentialAnimation on x {
        loops: Animation.Infinite
        NumberAnimation { to: lock.width * 0.15; duration: 16000; easing.type: Easing.InOutSine }
        NumberAnimation { to: -b1.width * 0.2; duration: 16000; easing.type: Easing.InOutSine }
      }
      SequentialAnimation on y {
        loops: Animation.Infinite
        NumberAnimation { to: lock.height * 0.1; duration: 13000; easing.type: Easing.InOutSine }
        NumberAnimation { to: -b1.height * 0.3; duration: 13000; easing.type: Easing.InOutSine }
      }
    }
    Rectangle {
      id: b2
      width: lock.width * 0.5; height: width; radius: width / 2
      color: lock.c2; opacity: 0.5
      x: lock.width * 0.6; y: lock.height * 0.4
      SequentialAnimation on x {
        loops: Animation.Infinite
        NumberAnimation { to: lock.width * 0.35; duration: 19000; easing.type: Easing.InOutSine }
        NumberAnimation { to: lock.width * 0.6; duration: 19000; easing.type: Easing.InOutSine }
      }
      SequentialAnimation on y {
        loops: Animation.Infinite
        NumberAnimation { to: lock.height * 0.65; duration: 15000; easing.type: Easing.InOutSine }
        NumberAnimation { to: lock.height * 0.4; duration: 15000; easing.type: Easing.InOutSine }
      }
    }
    Rectangle {
      id: b3
      width: lock.width * 0.4; height: width; radius: width / 2
      color: lock.c3; opacity: 0.45
      x: lock.width * 0.2; y: lock.height * 0.7
      SequentialAnimation on x {
        loops: Animation.Infinite
        NumberAnimation { to: lock.width * 0.5; duration: 21000; easing.type: Easing.InOutSine }
        NumberAnimation { to: lock.width * 0.2; duration: 21000; easing.type: Easing.InOutSine }
      }
      SequentialAnimation on y {
        loops: Animation.Infinite
        NumberAnimation { to: lock.height * 0.3; duration: 17000; easing.type: Easing.InOutSine }
        NumberAnimation { to: lock.height * 0.7; duration: 17000; easing.type: Easing.InOutSine }
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: { lock.wakeRequested(); lock.forcePasswordFocus() }
    onPositionChanged: lock.wakeRequested()
  }

  Column {
    anchors.centerIn: parent
    spacing: 40

    Column {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 4
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.formatTime(lock.now, "HH:mm")
        color: Color.lock.text
        font.family: Style.font.family
        font.pixelSize: Math.round(Style.font.baseSize * 9)
        font.weight: Font.Light
        font.letterSpacing: 4
      }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.formatDate(lock.now, "dddd, d MMMM")
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
      width: 380
      height: 56
      radius: 28
      showLockGlyph: false
      color: lock.withAlpha(Color.lock.background, 0.4)
      placeholder: lock.greeting() + ", " + lock.userName
    }
  }

  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 40
    text: lock.failedAttempts > 0
      ? lock.failedAttempts + " failed " + (lock.failedAttempts === 1 ? "attempt" : "attempts")
      : (lock.fingerprintConfigured ? "Touch the sensor or press Enter" : "Press Enter to unlock")
    color: lock.failedAttempts > 0 ? Color.lock.textError : lock.withAlpha(Color.lock.text, 0.45)
    font.family: Style.font.family
    font.pixelSize: Style.font.bodySmall
    font.letterSpacing: 2
  }
}
