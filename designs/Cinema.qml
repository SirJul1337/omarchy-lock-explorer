import QtQuick
import qs.Commons

DesignBase {
  id: lock
  inputItem: field.input

  readonly property int barHeight: Math.round(height * 0.14)
  readonly property int pad: 40

  Wallpaper { anchors.fill: parent; lock: lock; blur: 0.0; dim: 0.05; vignette: false }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: { lock.wakeRequested(); lock.forcePasswordFocus() }
    onPositionChanged: lock.wakeRequested()
  }

  Rectangle {
    id: topBar
    anchors.top: parent.top
    width: parent.width
    height: lock.barHeight
    color: "#000000"

    Text {
      anchors.left: parent.left
      anchors.leftMargin: lock.pad
      anchors.verticalCenter: parent.verticalCenter
      text: Qt.formatTime(lock.now, "HH:mm")
      color: "#f2f2f2"
      font.family: Style.font.family
      font.pixelSize: Style.font.displayLarge
      font.weight: Font.DemiBold
    }
    Text {
      anchors.right: parent.right
      anchors.rightMargin: lock.pad
      anchors.verticalCenter: parent.verticalCenter
      text: Qt.formatDate(lock.now, "dddd d MMMM yyyy").toUpperCase()
      color: "#bdbdbd"
      font.family: Style.font.family
      font.pixelSize: Style.font.subtitle
      font.letterSpacing: 4
    }
  }

  Rectangle {
    id: bottomBar
    anchors.bottom: parent.bottom
    width: parent.width
    height: lock.barHeight
    color: "#000000"

    Column {
      anchors.centerIn: parent
      spacing: 12
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: lock.errorState ? lock.failureMessage
          : (lock.authenticatingPassword ? "Checking…"
          : lock.greeting() + ", " + lock.userName + ". Enter your password to continue.")
        textFormat: Text.PlainText
        color: lock.errorState ? Color.lock.textError : "#f2f2f2"
        font.family: Style.font.family
        font.pixelSize: Style.font.heading
        font.italic: true
      }
      PasswordField {
        id: field
        lock: lock
        anchors.horizontalCenter: parent.horizontalCenter
        width: 400
        height: 42
        radius: 4
        outlineThickness: 1
        showLockGlyph: false
        color: "#161616"
        placeholder: "Password"
      }
    }
  }
}
