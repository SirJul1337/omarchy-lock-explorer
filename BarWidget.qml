import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// A lock in the bar. The bar loads this as a custom QML module, put into the
// layout by extras/bar-icon.sh (Settings > System > Bar icon). A click opens
// what `omarchy-shell lock explore` opens (the side panel or the full
// explorer, see Settings > System > Opens as), a right click always the full
// explorer.
Item {
  id: root

  property var bar: null
  property string moduleName: ""
  property var settings: ({})

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰌾"
    slotSize: Style.bar.statusSlot
    tooltipText: "Lock screen"

    onPressed: function(b) {
      if (b === Qt.RightButton) Quickshell.execDetached(["omarchy-shell", "lock", "exploreFull"])
      else Quickshell.execDetached(["omarchy-shell", "lock", "explore"])
    }
  }
}
