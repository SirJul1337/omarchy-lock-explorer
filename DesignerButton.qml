import QtQuick
import qs.Commons
import qs.Commons as Commons

// A small flat button for the designer's toolbar and panels.
Rectangle {
  id: button

  property string label: ""
  property bool primary: false
  property bool active: true
  property color foreground: Commons.Color.menu.text
  property color accent: Commons.Color.accent

  signal clicked()

  width: text.implicitWidth + Style.space(20)
  height: Style.space(28)
  radius: 5
  opacity: active ? 1 : 0.4
  color: primary ? accent
    : Qt.rgba(foreground.r, foreground.g, foreground.b, area.containsMouse && active ? 0.16 : 0.07)
  border.width: 1
  border.color: primary ? accent : Qt.rgba(foreground.r, foreground.g, foreground.b, 0.15)
  Behavior on color { ColorAnimation { duration: 100 } }

  Text {
    id: text
    anchors.centerIn: parent
    text: button.label
    textFormat: Text.PlainText
    color: button.primary ? Commons.Color.background : button.foreground
    font.family: Style.font.menuFamily
    font.pixelSize: Style.font.bodySmall
    font.weight: button.primary ? Font.DemiBold : Font.Normal
  }

  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    enabled: button.active
    onClicked: button.clicked()
  }
}
