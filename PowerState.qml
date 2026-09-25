import QtQuick
import Quickshell.Services.UPower

// The machine's power, for "Reduce motion: On battery" and the low-battery
// warning on the lock screen. Loaded through a Loader in Service.qml so a
// shell without the UPower module loses these and nothing else.
QtObject {
  readonly property var device: UPower.displayDevice
  readonly property bool onBattery: UPower.onBattery
  readonly property bool hasBattery: !!device && device.isPresent === true && device.percentage > 0
  readonly property int percent: hasBattery ? Math.round(device.percentage * 100) : -1
}
