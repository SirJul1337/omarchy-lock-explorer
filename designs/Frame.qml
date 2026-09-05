import QtQuick
import qs.Commons

DesignBase {
  id: lock
  inputItem: field.input

  readonly property int inset: 56
  readonly property int captionHeight: 150

  Rectangle { anchors.fill: parent; color: Color.background }
  Rectangle { anchors.fill: parent; color: Color.lock.background }

  Item {
    id: photo
    x: lock.inset
    y: lock.inset
    width: lock.width - lock.inset * 2
    height: lock.height - lock.inset - lock.captionHeight
    clip: true
    Wallpaper {
      x: -photo.x; y: -photo.y
      width: lock.width; height: lock.height
      lock: lock
      blur: 0.0; dim: 0; vignette: false
    }
    Rectangle { anchors.fill: parent; color: "transparent"; border.width: 1; border.color: Qt.rgba(0, 0, 0, 0.5) }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: { lock.wakeRequested(); lock.forcePasswordFocus() }
    onPositionChanged: lock.wakeRequested()
  }

  Item {
    id: caption
    x: lock.inset
    y: photo.y + photo.height
    width: photo.width
    height: lock.captionHeight

    Column {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      spacing: 4
      Text {
        text: Qt.formatTime(lock.now, "HH:mm")
        color: Color.lock.text
        font.family: Style.font.family
        font.pixelSize: Math.round(Style.font.baseSize * 4)
        font.weight: Font.DemiBold
      }
      Text {
        text: Qt.formatDate(lock.now, "dddd d MMMM yyyy")
        color: lock.withAlpha(Color.lock.text, 0.65)
        font.family: Style.font.family
        font.pixelSize: Style.font.subtitle
        font.letterSpacing: 1
      }
    }

    PasswordField {
      id: field
      lock: lock
      anchors.centerIn: parent
      width: 380
      height: 52
      radius: 6
      outlineThickness: 1
      color: lock.withAlpha(Color.background, 0.5)
      placeholder: "Password"
    }

    Column {
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: 4
      Text {
        anchors.right: parent.right
        text: lock.userName
        color: Color.lock.text
        font.family: Style.font.family
        font.pixelSize: Style.font.display
        font.weight: Font.DemiBold
      }
      Text {
        anchors.right: parent.right
        text: lock.errorState ? lock.failureMessage : (lock.authenticatingPassword ? "Checking…" : lock.hostName)
        textFormat: Text.PlainText
        color: lock.errorState ? Color.lock.textError : lock.withAlpha(Color.lock.text, 0.65)
        font.family: Style.font.family
        font.pixelSize: Style.font.subtitle
      }
    }
  }
}
