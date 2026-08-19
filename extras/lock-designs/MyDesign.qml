// Copy this file to ~/.config/omarchy/lock-designs/ and edit it.
// The import below points at the plugin's shared parts (DesignBase,
// PasswordField, LockInput, Wallpaper, Avatar). Keep it as is.
import QtQuick
import qs.Commons
import "../plugins/io.github.sirjul1337.lock-explorer/designs"

DesignBase {
  id: lock
  inputItem: field.input

  Wallpaper { anchors.fill: parent; lock: lock; blur: 0.7; dim: 0.1 }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: { lock.wakeRequested(); lock.forcePasswordFocus() }
    onPositionChanged: lock.wakeRequested()
  }

  Column {
    anchors.centerIn: parent
    spacing: 24

    // The user's picture, or their initial when none is set.
    Avatar {
      anchors.horizontalCenter: parent.horizontalCenter
      lock: lock
      width: 96
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: Qt.formatTime(lock.now, "HH:mm")
      color: Color.lock.text
      font.family: Style.font.family
      font.pixelSize: Math.round(Style.font.baseSize * 8)
      font.weight: Font.DemiBold
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: "Hello " + lock.userName + ", this is my design"
      color: lock.withAlpha(Color.lock.text, 0.75)
      font.family: Style.font.family
      font.pixelSize: Style.font.heading
    }

    PasswordField {
      id: field
      lock: lock
      anchors.horizontalCenter: parent.horizontalCenter
      width: 380
      height: 54
    }
  }
}
