import QtQuick
import qs.Commons

// Show/hide password button for designs that draw their own input.
Item {
  id: button
  property var lock: null
  property int size: Math.round(Style.font.heading * 1.1)
  readonly property bool revealed: lock ? lock.passwordVisible : false
  visible: lock ? lock.showPasswordToggle : true
  width: Math.round(size * 1.6)
  height: Math.round(size * 1.6)
  Text {
    anchors.centerIn: parent
    text: button.revealed ? "󰈉" : "󰈈"
    color: button.revealed ? Color.lock.borderActive : Color.lock.placeholder
    font.family: Style.font.family
    font.pixelSize: button.size
  }
  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: {
      if (button.lock) { button.lock.togglePasswordVisible(); button.lock.forcePasswordFocus() }
    }
  }
}
