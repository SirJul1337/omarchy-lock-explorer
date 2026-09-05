import QtQuick
import qs.Commons

DesignBase {
  id: lock
  inputItem: field.input

  readonly property int barHeight: 72
  readonly property int pad: 28

  Wallpaper { anchors.fill: parent; lock: lock; blur: 0.0; dim: 0.05; vignetteTop: 0.1; vignetteMiddle: 0.0; vignetteBottom: 0.35 }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: { lock.wakeRequested(); lock.forcePasswordFocus() }
    onPositionChanged: lock.wakeRequested()
  }

  Rectangle {
    id: bar
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    height: lock.barHeight
    color: lock.withAlpha(Color.lock.background, 0.82)

    Rectangle {
      anchors.top: parent.top
      width: parent.width
      height: 1
      color: lock.withAlpha(Color.lock.text, 0.14)
    }

    Row {
      anchors.left: parent.left
      anchors.leftMargin: lock.pad
      anchors.verticalCenter: parent.verticalCenter
      spacing: 12
      Avatar {
        lock: lock
        width: 34
        fontSize: Style.font.title
        anchors.verticalCenter: parent.verticalCenter
        shadow: false
      }
      Column {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1
        Text {
          text: lock.userName + "@" + lock.hostName
          color: Color.lock.text
          font.family: Style.font.family
          font.pixelSize: Style.font.subtitle
          font.weight: Font.DemiBold
        }
        Text {
          text: lock.errorState ? lock.failureMessage
            : (lock.authenticatingPassword ? "Checking…"
            : (lock.fingerprintConfigured ? "Locked, touch sensor or type password" : "Locked"))
          textFormat: Text.PlainText
          color: lock.errorState ? Color.lock.textError : lock.withAlpha(Color.lock.text, 0.55)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }
      }
    }

    PasswordField {
      id: field
      lock: lock
      anchors.centerIn: parent
      width: 380
      height: 42
      radius: Math.max(Style.cornerRadius, 8)
      outlineThickness: 1
      textAlignment: TextInput.AlignLeft
      placeholder: "Password"
      color: lock.withAlpha(Color.background, 0.6)
    }

    Row {
      anchors.right: parent.right
      anchors.rightMargin: lock.pad
      anchors.verticalCenter: parent.verticalCenter
      spacing: 14
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: Qt.formatDate(lock.now, "ddd d MMM")
        color: lock.withAlpha(Color.lock.text, 0.65)
        font.family: Style.font.family
        font.pixelSize: Style.font.subtitle
      }
      Rectangle { width: 1; height: 24; color: lock.withAlpha(Color.lock.text, 0.2); anchors.verticalCenter: parent.verticalCenter }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: Qt.formatTime(lock.now, "HH:mm")
        color: Color.lock.text
        font.family: Style.font.family
        font.pixelSize: Style.font.display
        font.weight: Font.DemiBold
      }
    }
  }
}
