import QtQuick
import qs.Commons

DesignBase {
  id: lock
  inputItem: field.input

  readonly property int tileW: 118
  readonly property int tileH: 160
  readonly property string hh: Qt.formatTime(now, "HH")
  readonly property string mm: Qt.formatTime(now, "mm")

  Wallpaper { anchors.fill: parent; lock: lock; blur: 0.9; dim: 0.15 }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: { lock.wakeRequested(); lock.forcePasswordFocus() }
    onPositionChanged: lock.wakeRequested()
  }

  component Tile: Rectangle {
    property string digit: "0"
    width: lock.tileW
    height: lock.tileH
    radius: 14
    color: lock.withAlpha(Color.lock.background, 0.9)
    border.width: 1
    border.color: lock.withAlpha(Color.lock.text, 0.1)
    Text {
      anchors.centerIn: parent
      text: parent.digit
      color: Color.lock.text
      font.family: Style.font.family
      font.pixelSize: Math.round(lock.tileH * 0.72)
      font.weight: Font.Bold
    }
    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width
      height: 2
      color: Qt.rgba(0, 0, 0, 0.55)
    }
  }

  Column {
    anchors.centerIn: parent
    spacing: 30

    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 10
      Tile { digit: lock.hh.charAt(0) }
      Tile { digit: lock.hh.charAt(1) }
      Column {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 22
        Rectangle { width: 12; height: 12; radius: 6; color: Color.lock.borderActive }
        Rectangle { width: 12; height: 12; radius: 6; color: Color.lock.borderActive }
      }
      Tile { digit: lock.mm.charAt(0) }
      Tile { digit: lock.mm.charAt(1) }
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: Qt.formatDate(lock.now, "dddd, d MMMM yyyy").toUpperCase()
      color: lock.withAlpha(Color.lock.text, 0.7)
      font.family: Style.font.family
      font.pixelSize: Style.font.subtitle
      font.letterSpacing: 4
    }

    PasswordField {
      id: field
      lock: lock
      anchors.horizontalCenter: parent.horizontalCenter
      width: lock.tileW * 4 + 10 * 3 + 12 + 20
      height: 54
      radius: 14
      placeholder: "Password"
    }
  }
}
