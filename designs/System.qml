import QtQuick
import Quickshell.Io
import Quickshell.Services.UPower
import qs.Commons

DesignBase {
  id: lock
  inputItem: field.input

  property real uptimeSeconds: 0
  property real memUsedPct: 0
  property string memUsed: ""
  property string load: ""
  property string kernel: ""

  readonly property var battery: UPower.displayDevice
  readonly property bool hasBattery: battery && battery.isPresent && battery.percentage > 0
  readonly property int batteryPct: hasBattery ? Math.round(battery.percentage * 100) : 0
  readonly property bool charging: hasBattery && !UPower.onBattery

  function fmtUptime(s) {
    var d = Math.floor(s / 86400), h = Math.floor((s % 86400) / 3600), m = Math.floor((s % 3600) / 60)
    if (d > 0) return d + "d " + h + "h"
    if (h > 0) return h + "h " + m + "m"
    return m + "m"
  }

  FileView {
    id: uptimeFile
    path: "/proc/uptime"
    printErrors: false
    onLoaded: lock.uptimeSeconds = parseFloat(String(text()).split(" ")[0]) || 0
  }
  FileView {
    id: memFile
    path: "/proc/meminfo"
    printErrors: false
    onLoaded: {
      var total = 0, avail = 0
      String(text()).split("\n").forEach(function(l) {
        if (l.indexOf("MemTotal:") === 0) total = parseInt(l.replace(/\D+/g, ""))
        if (l.indexOf("MemAvailable:") === 0) avail = parseInt(l.replace(/\D+/g, ""))
      })
      if (total > 0) {
        lock.memUsedPct = (total - avail) / total
        lock.memUsed = ((total - avail) / 1048576).toFixed(1) + " / " + (total / 1048576).toFixed(0) + " GB"
      }
    }
  }
  FileView {
    id: loadFile
    path: "/proc/loadavg"
    printErrors: false
    onLoaded: lock.load = String(text()).split(" ").slice(0, 3).join("  ")
  }
  Process {
    id: unameProc
    command: ["uname", "-r"]
    running: true
    stdout: StdioCollector { id: unameOut; waitForEnd: true; onStreamFinished: lock.kernel = String(unameOut.text).trim() }
  }
  Timer {
    interval: 15000
    running: true
    repeat: true
    onTriggered: { uptimeFile.reload(); memFile.reload(); loadFile.reload() }
  }

  Wallpaper { anchors.fill: parent; lock: lock; blur: 1.0; dim: 0.3; vignette: false }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: { lock.wakeRequested(); lock.forcePasswordFocus() }
    onPositionChanged: lock.wakeRequested()
  }

  component Tile: Rectangle {
    property string label: ""
    property string value: ""
    property string sub: ""
    property real fill: -1
    property string icon: ""
    width: 200
    height: 112
    radius: 14
    color: lock.withAlpha(Color.lock.background, 0.7)
    border.width: 1
    border.color: lock.withAlpha(Color.lock.text, 0.1)
    Column {
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.margins: 16
      spacing: 4
      Row {
        spacing: 8
        Text { text: icon; color: Color.lock.borderActive; font.family: Style.font.family; font.pixelSize: Style.font.title }
        Text { text: label.toUpperCase(); color: lock.withAlpha(Color.lock.text, 0.55); font.family: Style.font.family; font.pixelSize: Style.font.caption; font.letterSpacing: 2; anchors.verticalCenter: parent.verticalCenter }
      }
      Text { text: value; color: Color.lock.text; font.family: Style.font.family; font.pixelSize: Style.font.displayLarge; font.weight: Font.DemiBold }
      Text { text: sub; color: lock.withAlpha(Color.lock.text, 0.55); font.family: Style.font.family; font.pixelSize: Style.font.caption; visible: sub.length > 0 }
    }
    Rectangle {
      visible: fill >= 0
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.margins: 12
      height: 4
      radius: 2
      color: lock.withAlpha(Color.lock.text, 0.15)
      Rectangle { width: parent.width * Math.max(0, Math.min(1, fill)); height: parent.height; radius: 2; color: Color.lock.borderActive }
    }
  }

  Column {
    anchors.centerIn: parent
    spacing: 28

    Column {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 2
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.formatTime(lock.now, "HH:mm")
        color: Color.lock.text
        font.family: Style.font.family
        font.pixelSize: Math.round(Style.font.baseSize * 7)
        font.weight: Font.DemiBold
        font.letterSpacing: -2
      }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.formatDate(lock.now, "dddd, d MMMM") + "  ·  " + lock.userName + "@" + lock.hostName
        color: lock.withAlpha(Color.lock.text, 0.7)
        font.family: Style.font.family
        font.pixelSize: Style.font.subtitle
      }
    }

    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 14
      Tile { icon: "󰅐"; label: "Uptime"; value: lock.fmtUptime(lock.uptimeSeconds); sub: lock.kernel }
      Tile { icon: "󰍛"; label: "Memory"; value: Math.round(lock.memUsedPct * 100) + "%"; sub: lock.memUsed; fill: lock.memUsedPct }
      Tile { icon: "󰓅"; label: "Load"; value: lock.load.split("  ")[0] || "-"; sub: lock.load }
      Tile {
        icon: lock.charging ? "󰂄" : "󰁹"
        label: "Battery"
        value: lock.hasBattery ? lock.batteryPct + "%" : "AC"
        sub: lock.hasBattery ? (lock.charging ? "Charging" : "On battery") : "No battery"
        fill: lock.hasBattery ? lock.batteryPct / 100 : -1
      }
    }

    PasswordField {
      id: field
      lock: lock
      anchors.horizontalCenter: parent.horizontalCenter
      width: 400
      height: 54
      placeholder: "Password"
    }
  }
}
