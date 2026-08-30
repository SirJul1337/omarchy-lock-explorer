import QtQuick
import qs.Commons

// One labelled row in the boot layout editor. `control` picks the widget:
// "text" (free text), "dropdown" (pick from `options`), "toggle" (on/off) or
// "stepper" (-/+ around a number).
Row {
  id: field

  property string label: ""
  property string control: "text"
  property string value: ""
  property bool on: false
  property var options: []
  property string suffix: "%"    // stepper unit label
  property bool expanded: false
  property int rev: 0            // bump to reload text from `value`

  signal edited(string text)
  signal selected(string option)
  signal toggled()
  signal step(int delta)
  signal escaped()   // the text field has focus, so it forwards Escape

  readonly property color fg: Color.menu.text
  readonly property color mut: Qt.rgba(fg.r, fg.g, fg.b, 0.6)
  readonly property color accent: Color.accent

  spacing: Style.space(12)
  height: control === "dropdown" && expanded
    ? Style.space(32) + options.length * Style.space(30)
    : Style.space(32)
  // Collapse when the form reloads under us.
  onRevChanged: expanded = false

  Text {
    // Anchored to the header line, not the row center, so an expanded
    // dropdown does not drag the label down with it.
    y: (Style.space(32) - height) / 2
    width: Style.space(130)
    text: field.label
    color: field.mut
    font.family: Style.font.menuFamily
    font.pixelSize: Style.font.bodySmall
    elide: Text.ElideRight
  }

  // text
  Rectangle {
    visible: field.control === "text"
    anchors.verticalCenter: parent.verticalCenter
    width: Style.space(210)
    height: Style.space(30)
    radius: Style.space(6)
    color: Qt.rgba(field.fg.r, field.fg.g, field.fg.b, 0.06)
    border.width: 1
    border.color: input.activeFocus ? field.accent : Qt.rgba(field.fg.r, field.fg.g, field.fg.b, 0.15)

    TextInput {
      id: input
      anchors.fill: parent
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      verticalAlignment: TextInput.AlignVCenter
      clip: true
      color: field.fg
      selectionColor: field.accent
      selectedTextColor: Color.background
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.bodySmall
      text: field.value
      onTextChanged: if (activeFocus) field.edited(text)
      Keys.onEscapePressed: function(e) { field.escaped(); e.accepted = true }
      Connections {
        target: field
        function onRevChanged() {
          if (input.text !== field.value) input.text = field.value
        }
      }
    }
  }

  // dropdown
  Column {
    visible: field.control === "dropdown"
    spacing: 0

    Rectangle {
      width: Style.space(210)
      height: Style.space(30)
      radius: Style.space(6)
      color: Qt.rgba(field.fg.r, field.fg.g, field.fg.b, dropArea.containsMouse || field.expanded ? 0.12 : 0.06)
      border.width: 1
      border.color: field.expanded ? field.accent : Qt.rgba(field.fg.r, field.fg.g, field.fg.b, 0.15)

      Text {
        anchors.left: parent.left
        anchors.leftMargin: Style.space(10)
        anchors.verticalCenter: parent.verticalCenter
        text: field.value
        color: field.fg
        font.family: Style.font.menuFamily
        font.pixelSize: Style.font.bodySmall
      }
      Text {
        anchors.right: parent.right
        anchors.rightMargin: Style.space(10)
        anchors.verticalCenter: parent.verticalCenter
        text: field.expanded ? "▴" : "▾"
        color: field.mut
        font.pixelSize: Style.font.bodySmall
      }
      MouseArea {
        id: dropArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: field.expanded = !field.expanded
      }
    }

    Repeater {
      model: field.expanded ? field.options : []
      Rectangle {
        id: optionRow
        required property string modelData
        width: Style.space(210)
        height: Style.space(30)
        color: optionArea.containsMouse ? Qt.rgba(field.accent.r, field.accent.g, field.accent.b, 0.18)
             : Qt.rgba(field.fg.r, field.fg.g, field.fg.b, 0.04)

        Text {
          anchors.left: parent.left
          anchors.leftMargin: Style.space(10)
          anchors.verticalCenter: parent.verticalCenter
          text: optionRow.modelData
          color: optionRow.modelData === field.value ? field.accent : field.fg
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.bodySmall
          font.weight: optionRow.modelData === field.value ? Font.DemiBold : Font.Normal
        }
        MouseArea {
          id: optionArea
          anchors.fill: parent
          hoverEnabled: true
          onClicked: {
            // Emit before collapsing: collapsing tears down this delegate,
            // and a destroyed handler emits nothing.
            var opt = optionRow.modelData
            field.selected(opt)
            Qt.callLater(function() { field.expanded = false })
          }
        }
      }
    }
  }

  // toggle
  Rectangle {
    visible: field.control === "toggle"
    anchors.verticalCenter: parent.verticalCenter
    width: Style.space(44)
    height: Style.space(24)
    radius: height / 2
    color: field.on ? field.accent : Qt.rgba(field.fg.r, field.fg.g, field.fg.b, 0.12)
    Behavior on color { ColorAnimation { duration: 100 } }

    Rectangle {
      width: Style.space(18)
      height: Style.space(18)
      radius: width / 2
      color: Color.background
      anchors.verticalCenter: parent.verticalCenter
      x: field.on ? parent.width - width - Style.space(3) : Style.space(3)
      Behavior on x { NumberAnimation { duration: 100 } }
    }
    MouseArea { anchors.fill: parent; onClicked: field.toggled() }
  }

  // stepper
  Row {
    visible: field.control === "stepper"
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(8)

    Rectangle {
      width: Style.space(30); height: Style.space(30); radius: Style.space(6)
      color: Qt.rgba(field.fg.r, field.fg.g, field.fg.b, minusArea.containsMouse ? 0.12 : 0.06)
      Text { anchors.centerIn: parent; text: "−"; color: field.fg; font.pixelSize: Style.font.body }
      MouseArea { id: minusArea; anchors.fill: parent; hoverEnabled: true; onClicked: field.step(-1) }
    }
    Text {
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(46)
      horizontalAlignment: Text.AlignHCenter
      text: field.value + field.suffix
      color: field.fg
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.bodySmall
    }
    Rectangle {
      width: Style.space(30); height: Style.space(30); radius: Style.space(6)
      color: Qt.rgba(field.fg.r, field.fg.g, field.fg.b, plusArea.containsMouse ? 0.12 : 0.06)
      Text { anchors.centerIn: parent; text: "+"; color: field.fg; font.pixelSize: Style.font.body }
      MouseArea { id: plusArea; anchors.fill: parent; hoverEnabled: true; onClicked: field.step(1) }
    }
  }
}
