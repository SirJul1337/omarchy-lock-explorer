import QtQuick
import QtQuick.Effects
import qs.Commons
import qs.Commons as Commons

// Metro: the day as a transit line. Twenty-four stations, one an hour,
// snake across the screen in the theme's accent; the train is where the
// time is, between the hour just passed and the next. A station sign holds
// the clock and the next departure, the sign-in is the ticket barrier, and
// a wrong password suspends the service.
DesignBase {
  id: lock
  inputItem: field.input
  shakeOnFail: false
  flashOnFail: false

  readonly property color line: lock.withAlpha(Commons.Color.lock.borderActive, 1)
  readonly property color ink: lock.withAlpha(Commons.Color.lock.text, 1)
  readonly property color bg: lock.deepen(Commons.Color.background, 1.3)
  readonly property int hour: lock.now.getHours()
  readonly property real minuteFrac: (lock.now.getMinutes() * 60 + lock.now.getSeconds()) / 3600
  readonly property bool suspended: lock.errorState

  // The map: three rows of eight stations, read like a snake.
  readonly property int perRow: 8
  readonly property int rows: 3
  readonly property real mapLeft: Math.round(width * 0.13)
  readonly property real mapRight: Math.round(width * 0.87)
  readonly property real mapTop: Math.round(height * 0.42)
  readonly property real rowGap: Math.round(height * 0.13)

  function stationPos(h) {
    var r = Math.floor(h / perRow)
    var i = h % perRow
    var t = i / (perRow - 1)
    var x = r % 2 === 0 ? mapLeft + (mapRight - mapLeft) * t : mapRight - (mapRight - mapLeft) * t
    return { x: x, y: mapTop + r * rowGap }
  }

  Rectangle { anchors.fill: parent; color: lock.bg }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: { lock.wakeRequested(); lock.forcePasswordFocus() }
    onPositionChanged: lock.wakeRequested()
  }

  Canvas {
    id: map
    anchors.fill: parent
    renderStrategy: Canvas.Cooperative
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    Connections {
      target: lock
      function onNowChanged() { map.requestPaint() }
      function onSuspendedChanged() { map.requestPaint() }
      function onHideTimeChanged() { map.requestPaint() }
    }

    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      ctx.clearRect(0, 0, width, height)
      var lineC = lock.suspended ? Commons.Color.lock.textError : lock.line
      var turn = lock.rowGap / 2

      // The line: rows joined by half-circle turns at alternate ends.
      ctx.strokeStyle = lineC
      ctx.lineWidth = 10
      ctx.lineCap = "round"
      ctx.beginPath()
      ctx.moveTo(lock.mapLeft, lock.mapTop)
      for (var r = 0; r < lock.rows; r++) {
        var y = lock.mapTop + r * lock.rowGap
        if (r % 2 === 0) {
          ctx.lineTo(lock.mapRight, y)
          if (r < lock.rows - 1) ctx.arc(lock.mapRight, y + turn, turn, -Math.PI / 2, Math.PI / 2, false)
        } else {
          ctx.lineTo(lock.mapLeft, y)
          if (r < lock.rows - 1) ctx.arc(lock.mapLeft, y + turn, turn, -Math.PI / 2, Math.PI / 2, true)
        }
      }
      ctx.stroke()
      // A darker core to the line, the way maps print it.
      ctx.strokeStyle = lock.withAlpha(lock.bg, 0.25)
      ctx.lineWidth = 3
      ctx.stroke()

      // Stations. A boot snapshot with the clock hidden draws no train, since
      // where the train is would only be the time the snapshot was taken.
      var live = !lock.hideTime
      ctx.font = "bold 12px " + Style.font.family
      ctx.textAlign = "center"
      for (var h = 0; h < 24; h++) {
        var p = lock.stationPos(h)
        var passed = live && h <= lock.hour
        var here = live && h === lock.hour
        ctx.beginPath()
        ctx.arc(p.x, p.y, here ? 11 : 7, 0, 6.2832)
        ctx.fillStyle = passed ? lock.ink : lock.bg
        ctx.fill()
        ctx.lineWidth = here ? 4 : 3
        ctx.strokeStyle = here ? lineC : lock.ink
        ctx.stroke()
        ctx.fillStyle = lock.withAlpha(lock.ink, here ? 1 : 0.55)
        var above = Math.floor(h / lock.perRow) % 2 === 1
        ctx.fillText((h < 10 ? "0" : "") + h + ":00", p.x, p.y + (above ? -20 : 32))
      }

      if (!live) return

      // The train, between the hour just passed and the next.
      var a = lock.stationPos(lock.hour)
      var b = lock.hour < 23 ? lock.stationPos(lock.hour + 1) : a
      var tx, ty
      if (Math.abs(a.y - b.y) < 1) {
        tx = a.x + (b.x - a.x) * lock.minuteFrac
        ty = a.y
      } else {
        // Round the turn: a half circle from a down to b, bulging outwards.
        var cx = a.x, cy = (a.y + b.y) / 2
        var side = a.x > width / 2 ? 1 : -1
        var ang = -Math.PI / 2 + Math.PI * lock.minuteFrac
        tx = cx + side * Math.cos(ang) * turn
        ty = cy + Math.sin(ang) * turn
      }
      ctx.save()
      ctx.translate(tx, ty)
      ctx.fillStyle = lock.ink
      ctx.beginPath()
      ctx.roundedRect(-22, -10, 44, 20, 6, 6)
      ctx.fill()
      ctx.fillStyle = lineC
      ctx.fillRect(-16, -5, 10, 7)
      ctx.fillRect(-3, -5, 10, 7)
      ctx.fillRect(10, -5, 6, 7)
      ctx.fillStyle = lock.suspended ? Commons.Color.lock.textError : lock.withAlpha("#ffe08a", 1)
      ctx.beginPath(); ctx.arc(-19, 7, 2.5, 0, 6.2832); ctx.fill()
      ctx.beginPath(); ctx.arc(19, 7, 2.5, 0, 6.2832); ctx.fill()
      ctx.restore()
    }
  }

  // The station sign.
  Rectangle {
    id: sign
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top
    anchors.topMargin: Math.round(lock.height * 0.1)
    width: signRow.implicitWidth + 64
    height: signRow.implicitHeight + 36
    radius: 10
    color: lock.withAlpha(lock.ink, 0.06)
    border.width: 2
    border.color: lock.withAlpha(lock.ink, 0.5)

    Rectangle {
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      anchors.margins: 2
      width: 14
      radius: 8
      color: lock.suspended ? Commons.Color.lock.textError : lock.line
    }

    Row {
      id: signRow
      anchors.centerIn: parent
      spacing: 36
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: lock.clock("HH:mm")
        color: lock.ink
        font.family: Style.font.family
        font.pixelSize: Math.round(Style.font.baseSize * 6.5)
        font.weight: Font.Bold
        font.letterSpacing: -1
      }
      Column {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4
        Text {
          text: lock.date("dddd").toUpperCase() + " " + lock.tr("LINE")
          textFormat: Text.PlainText
          color: lock.suspended ? Commons.Color.lock.textError : lock.line
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
          font.weight: Font.Bold
          font.letterSpacing: 3
        }
        Text {
          text: lock.date("d MMMM yyyy")
          color: lock.withAlpha(lock.ink, 0.8)
          font.family: Style.font.family
          font.pixelSize: Style.font.body
        }
        Text {
          opacity: lock.hideTime ? 0 : 1
          text: lock.suspended ? lock.tr("SERVICE SUSPENDED")
            : (lock.hour === 23 ? lock.tr("LAST STATION") : lock.tr("NEXT %1 IN %2 MIN").arg((lock.hour + 1 < 10 ? "0" : "") + (lock.hour + 1) + ":00").arg(60 - lock.now.getMinutes()))
          textFormat: Text.PlainText
          color: lock.suspended ? Commons.Color.lock.textError : lock.withAlpha(lock.ink, 0.6)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          font.letterSpacing: 2
        }
      }
    }
  }

  // The ticket barrier.
  Column {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: Math.round(lock.height * 0.08)
    spacing: 10
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: lock.tr("TICKETS")
      color: lock.withAlpha(lock.ink, 0.5)
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      font.letterSpacing: 4
    }
    PasswordField {
      id: field
      lock: lock
      anchors.horizontalCenter: parent.horizontalCenter
      width: 400
      height: 54
      radius: 8
      outlineThickness: 2
      showLockGlyph: false
      shakeOnFail: true
      color: lock.withAlpha(lock.ink, 0.06)
      placeholder: "Tap your card"
    }
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      opacity: lock.snapshotMode ? 0 : 1
      text: lock.failedAttempts > 0
        ? lock.tr(lock.failedAttempts === 1 ? "1 failed attempt" : "%1 failed attempts").arg(lock.failedAttempts)
        : (lock.fingerprintConfigured ? lock.fingerprintHint(lock.tr("󰆠  Touch sensor or type password")) : lock.tr("Enter your password to unlock"))
      textFormat: Text.PlainText
      color: lock.failedAttempts > 0 ? Commons.Color.lock.textError : lock.withAlpha(lock.ink, 0.45)
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      font.letterSpacing: 1
    }
  }
}
