import QtQuick
import Quickshell.Services.UPower

// The battery, for the designer's Battery piece.
Item {
  readonly property var device: UPower.displayDevice
  readonly property bool hasBattery: !!device && device.isPresent && device.percentage > 0
  readonly property int percent: hasBattery ? Math.round(device.percentage * 100) : 0
  readonly property bool charging: hasBattery && !UPower.onBattery
  readonly property string glyph: {
    if (!hasBattery) return "󰚥"
    if (charging) return "󰂄"
    var steps = ["󰂎", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]
    return steps[Math.max(0, Math.min(10, Math.round(percent / 10)))]
  }
}
