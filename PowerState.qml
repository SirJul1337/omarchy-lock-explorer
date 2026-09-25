import QtQuick
import Quickshell.Services.UPower

// Whether the machine is running on its battery, for "Reduce motion: On
// battery". Loaded through a Loader in Service.qml so a shell without the
// UPower module loses this one setting and nothing else.
QtObject {
  readonly property bool onBattery: UPower.onBattery
}
