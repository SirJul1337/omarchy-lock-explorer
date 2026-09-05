import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

DesignBase {
  id: lock
  inputItem: field.input

  property string locationQuery: ""
  property var report: null
  property bool loading: true
  property string error: ""

  readonly property var current: report && report.current_condition && report.current_condition.length ? report.current_condition[0] : null
  readonly property string temp: current ? current.temp_C + "°" : "--"
  readonly property string feels: current ? current.FeelsLikeC + "°" : ""
  readonly property string desc: current && current.weatherDesc && current.weatherDesc.length ? current.weatherDesc[0].value : (loading ? "Loading weather" : (error || "No weather"))
  readonly property string area: report && report.nearest_area && report.nearest_area.length && report.nearest_area[0].areaName ? report.nearest_area[0].areaName[0].value : ""
  readonly property var days: report && report.weather ? report.weather.slice(0, 3) : []

  function glyph(code) {
    var c = parseInt(code || "0")
    if (c === 113) return "󰖙"
    if (c === 116) return "󰖕"
    if (c === 119 || c === 122) return "󰖐"
    if (c === 143 || c === 248 || c === 260) return "󰖑"
    if ([200, 386, 389, 392].indexOf(c) !== -1) return "󰖓"
    if ([179, 227, 230, 323, 326, 329, 332, 335, 338, 368, 371, 395].indexOf(c) !== -1) return "󰖘"
    if ([182, 185, 281, 284, 311, 314, 317, 320, 350, 362, 365, 374, 377].indexOf(c) !== -1) return "󰙿"
    if ([305, 308, 356, 359].indexOf(c) !== -1) return "󰖖"
    if (c >= 176) return "󰖗"
    return "󰖐"
  }

  function dayGlyph(day) {
    if (!day || !day.hourly || day.hourly.length === 0) return "󰖐"
    var h = day.hourly[Math.min(4, day.hourly.length - 1)]
    return glyph(h.weatherCode)
  }

  function refresh() {
    if (!weatherProc.running) weatherProc.running = true
  }

  FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/settings/weather.json"
    printErrors: false
    onLoaded: {
      try {
        var d = JSON.parse(text())
        var lat = parseFloat(d.latitude), lon = parseFloat(d.longitude)
        if (!isNaN(lat) && !isNaN(lon)) lock.locationQuery = lat + "," + lon
        else if (d.name) lock.locationQuery = encodeURIComponent(d.name)
      } catch (e) {}
      lock.refresh()
    }
    onLoadFailed: lock.refresh()
  }

  Process {
    id: weatherProc
    command: ["curl", "-fsS", "--max-time", "15", "https://wttr.in/" + lock.locationQuery + "?format=j1"]
    stdout: StdioCollector {
      id: weatherOut
      waitForEnd: true
      onStreamFinished: {
        try {
          lock.report = JSON.parse(String(weatherOut.text || ""))
          lock.error = ""
        } catch (e) {
          lock.error = "Weather unavailable"
        }
        lock.loading = false
      }
    }
    onExited: function(code) {
      if (code !== 0) {
        lock.error = "Weather unavailable"
        lock.loading = false
        if (!lock.retried) { lock.retried = true; retryTimer.start() }
      }
    }
  }
  property bool retried: false
  Timer { id: retryTimer; interval: 20000; onTriggered: lock.refresh() }

  Timer {
    interval: 30 * 60 * 1000
    running: true
    repeat: true
    onTriggered: lock.refresh()
  }

  Wallpaper { anchors.fill: parent; lock: lock; blur: 0.8; dim: 0.15 }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: { lock.wakeRequested(); lock.forcePasswordFocus() }
    onPositionChanged: lock.wakeRequested()
  }

  Row {
    anchors.centerIn: parent
    anchors.verticalCenterOffset: -60
    spacing: 90

    Column {
      anchors.verticalCenter: parent.verticalCenter
      spacing: 4
      Row {
        spacing: 22
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: lock.current ? lock.glyph(lock.current.weatherCode) : "󰖐"
          color: Color.lock.borderActive
          font.family: Style.font.family
          font.pixelSize: Math.round(Style.font.baseSize * 7)
        }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: lock.temp
          textFormat: Text.PlainText
          color: Color.lock.text
          font.family: Style.font.family
          font.pixelSize: Math.round(Style.font.baseSize * 8)
          font.weight: Font.DemiBold
          font.letterSpacing: -3
        }
      }
      Text {
        text: lock.desc
        textFormat: Text.PlainText
        color: Color.lock.text
        font.family: Style.font.family
        font.pixelSize: Style.font.display
      }
      Text {
        text: (lock.area ? lock.area + "  ·  " : "") + (lock.current ? "feels like " + lock.feels + "  ·  " + lock.current.humidity + "% humidity  ·  " + lock.current.windspeedKmph + " km/h" : "")
        textFormat: Text.PlainText
        color: lock.withAlpha(Color.lock.text, 0.65)
        font.family: Style.font.family
        font.pixelSize: Style.font.body
      }
      Item { width: 1; height: 14 }
      Row {
        spacing: 12
        Repeater {
          model: lock.days
          Rectangle {
            required property var modelData
            required property int index
            width: 96; height: 92; radius: 12
            color: lock.withAlpha(Color.lock.background, 0.55)
            border.width: 1
            border.color: lock.withAlpha(Color.lock.text, 0.1)
            Column {
              anchors.centerIn: parent
              spacing: 2
              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: parent.parent.index === 0 ? "Today" : Qt.formatDate(new Date(parent.parent.modelData.date), "ddd")
                color: lock.withAlpha(Color.lock.text, 0.6)
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
              }
              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: lock.dayGlyph(parent.parent.modelData)
                color: Color.lock.borderActive
                font.family: Style.font.family
                font.pixelSize: Style.font.display
              }
              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: parent.parent.modelData.maxtempC + "° / " + parent.parent.modelData.mintempC + "°"
                textFormat: Text.PlainText
                color: Color.lock.text
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
              }
            }
          }
        }
      }
    }

    Rectangle { width: 1; height: 220; color: lock.withAlpha(Color.lock.text, 0.2); anchors.verticalCenter: parent.verticalCenter }

    Column {
      anchors.verticalCenter: parent.verticalCenter
      spacing: 6
      Text {
        text: Qt.formatTime(lock.now, "HH:mm")
        color: Color.lock.text
        font.family: Style.font.family
        font.pixelSize: Math.round(Style.font.baseSize * 8)
        font.weight: Font.DemiBold
        font.letterSpacing: -2
      }
      Text {
        text: Qt.formatDate(lock.now, "dddd, d MMMM")
        color: lock.withAlpha(Color.lock.text, 0.75)
        font.family: Style.font.family
        font.pixelSize: Style.font.display
      }
    }
  }

  PasswordField {
    id: field
    lock: lock
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: Math.round(parent.height * 0.16)
    width: 400
    height: 54
    placeholder: lock.greeting() + ", " + lock.userName
  }
}
