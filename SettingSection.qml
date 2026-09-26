import QtQuick
import qs.Commons

// One group on the explorer's Settings page: a heading, a line on what the
// group is for, and its rows. `explorer` is the Explorer root, for its colors
// and font, so every section is drawn the same way.
Rectangle {
  id: section

  property var explorer: null
  property string title: ""
  property string description: ""
  default property alias rows: body.data

  readonly property real pad: Style.space(24)

  width: parent ? parent.width : 0
  height: column.implicitHeight + pad * 2
  radius: explorer ? explorer.cornerRadius : 0
  color: explorer ? Qt.rgba(explorer.foreground.r, explorer.foreground.g, explorer.foreground.b, 0.035) : "transparent"
  border.width: 1
  border.color: explorer ? Qt.rgba(explorer.foreground.r, explorer.foreground.g, explorer.foreground.b, 0.09) : "transparent"

  Column {
    id: column
    x: section.pad
    y: section.pad
    width: section.width - section.pad * 2
    spacing: Style.space(20)

    Column {
      width: parent.width
      spacing: Style.space(4)

      Text {
        text: section.title
        textFormat: Text.PlainText
        color: section.explorer ? section.explorer.foreground : "white"
        font.family: section.explorer ? section.explorer.fontFamily : Style.font.family
        font.pixelSize: Style.font.title
        font.weight: Font.DemiBold
      }

      Text {
        visible: section.description.length > 0
        width: parent.width
        wrapMode: Text.WordWrap
        text: section.description
        textFormat: Text.PlainText
        color: section.explorer ? section.explorer.muted : "gray"
        font.family: section.explorer ? section.explorer.fontFamily : Style.font.family
        font.pixelSize: Style.font.bodySmall
      }
    }

    Column {
      id: body
      width: parent.width
      spacing: Style.space(20)
    }
  }
}
