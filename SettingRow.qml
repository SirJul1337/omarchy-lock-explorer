import QtQuick
import qs.Commons

// One setting: its name in a column on the left, the choices on the right
// (wrapping onto more lines when there are many), and a line of help under
// them. Rows with a control of their own put it in as a child; it goes
// between the choices and the help.
Item {
  id: row

  property var explorer: null
  property string label: ""
  property string help: ""
  // [{ id, name }]; `current` is the id that is picked.
  property var options: []
  property var current: undefined
  signal picked(var id)
  default property alias extra: extraBox.data

  readonly property real labelWidth: Math.min(Style.space(240), width * 0.34)
  readonly property color fg: explorer ? explorer.foreground : "white"

  width: parent ? parent.width : 0
  height: Math.max(labelText.implicitHeight + labelText.y, controls.implicitHeight)

  Text {
    id: labelText
    y: Style.space(6)
    width: row.labelWidth - Style.space(18)
    wrapMode: Text.WordWrap
    text: row.label
    textFormat: Text.PlainText
    color: row.fg
    font.family: row.explorer ? row.explorer.fontFamily : Style.font.family
    font.pixelSize: Style.font.body
  }

  Column {
    id: controls
    x: row.labelWidth
    width: row.width - row.labelWidth
    spacing: Style.space(8)

    Flow {
      width: parent.width
      spacing: Style.space(6)
      visible: row.options.length > 0

      Repeater {
        model: row.options
        Rectangle {
          id: chip
          required property var modelData
          readonly property bool current: modelData.id === row.current
          width: chipLabel.implicitWidth + Style.space(26)
          height: Style.space(34)
          radius: row.explorer ? row.explorer.cornerRadius : 0
          color: current ? (row.explorer ? row.explorer.accent : "steelblue")
                         : Qt.rgba(row.fg.r, row.fg.g, row.fg.b, chipArea.containsMouse ? 0.13 : 0.06)
          border.width: current ? 0 : 1
          border.color: Qt.rgba(row.fg.r, row.fg.g, row.fg.b, 0.10)
          Behavior on color { ColorAnimation { duration: 100 } }

          Text {
            id: chipLabel
            anchors.centerIn: parent
            text: chip.modelData.name
            textFormat: Text.PlainText
            color: chip.current ? Color.background : row.fg
            font.family: row.explorer ? row.explorer.fontFamily : Style.font.family
            font.pixelSize: Style.font.bodySmall
            font.weight: chip.current ? Font.DemiBold : Font.Normal
          }

          MouseArea {
            id: chipArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.picked(chip.modelData.id)
          }
        }
      }
    }

    Item {
      id: extraBox
      width: parent.width
      height: childrenRect.height
      visible: children.length > 0
    }

    Text {
      visible: row.help.length > 0
      width: parent.width
      wrapMode: Text.WordWrap
      text: row.help
      textFormat: Text.PlainText
      color: row.explorer ? row.explorer.muted : "gray"
      font.family: row.explorer ? row.explorer.fontFamily : Style.font.family
      font.pixelSize: Style.font.bodySmall
      lineHeight: 1.15
    }
  }
}
