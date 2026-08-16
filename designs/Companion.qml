import QtQuick
import qs.Commons

// Shown on monitors that are not the input monitor. Still takes keyboard
// input so typing works wherever focus lands.
DesignBase {
  id: lock
  inputItem: input
  shakeOnFail: true

  Wallpaper { anchors.fill: parent; lock: lock; blur: 1.0; dim: 0.2 }

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

  Column {
    anchors.centerIn: parent
    spacing: 8
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: Qt.formatTime(lock.now, "HH:mm")
      color: Color.lock.text
      font.family: Style.font.family
      font.pixelSize: Math.round(Style.font.baseSize * 9)
      font.weight: Font.DemiBold
      font.letterSpacing: -2
    }
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: Qt.formatDate(lock.now, "dddd, d MMMM")
      color: lock.withAlpha(Color.lock.text, 0.75)
      font.family: Style.font.family
      font.pixelSize: Style.font.display
    }
    Item { width: 1; height: 16 }
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: lock.errorState ? lock.failureMessage
        : (lock.authenticatingPassword ? "Checking…"
        : (lock.passwordText.length > 0 ? "●".repeat(Math.min(lock.passwordText.length, 24)) : "󰌾"))
      color: lock.errorState ? Color.lock.textError : lock.withAlpha(Color.lock.text, 0.55)
      font.family: Style.font.family
      font.pixelSize: Style.font.heading
      font.letterSpacing: 4
    }
  }
}
