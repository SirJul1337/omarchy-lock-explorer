import QtQuick
import qs.Commons
import qs.Commons as Commons

// Blueprint: a drafting sheet in the theme's colours. Grid paper, the time
// as an outlined drawing with its dimensions called out, a title block in
// the corner with the host, the user and the date, and the sign-in boxed as
// a detail. Nothing moves; a wrong password stamps the sheet REJECTED.
DesignBase {
  id: lock
  inputItem: field.input
  shakeOnFail: true
  flashOnFail: false

  readonly property color paper: lock.deepen(Commons.Color.background, 1.25)
  readonly property color ink: Commons.Color.lock.text
  readonly property color line: Commons.Color.lock.borderActive
  readonly property real minor: 24
  readonly property int sheetNo: {
    var n = lock.now
    return n.getDate() * 100 + n.getHours()
  }

  Rectangle { anchors.fill: parent; color: lock.paper }

  // The grid, drawn once per size.
  Canvas {
    id: grid
    anchors.fill: parent
    renderStrategy: Canvas.Cooperative
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      ctx.clearRect(0, 0, width, height)
      var m = lock.minor
      ctx.lineWidth = 1
      for (var x = 0; x <= width; x += m) {
        ctx.strokeStyle = lock.withAlpha(lock.ink, (x / m) % 5 === 0 ? 0.13 : 0.05)
        ctx.beginPath(); ctx.moveTo(x + 0.5, 0); ctx.lineTo(x + 0.5, height); ctx.stroke()
      }
      for (var y = 0; y <= height; y += m) {
        ctx.strokeStyle = lock.withAlpha(lock.ink, (y / m) % 5 === 0 ? 0.13 : 0.05)
        ctx.beginPath(); ctx.moveTo(0, y + 0.5); ctx.lineTo(width, y + 0.5); ctx.stroke()
      }
      // The sheet border, double ruled.
      ctx.strokeStyle = lock.withAlpha(lock.ink, 0.45)
      ctx.lineWidth = 2
      ctx.strokeRect(28.5, 28.5, width - 57, height - 57)
      ctx.lineWidth = 1
      ctx.strokeRect(36.5, 36.5, width - 73, height - 73)
      // Fold marks at the centre of each edge.
      ctx.strokeStyle = lock.withAlpha(lock.ink, 0.5)
      ctx.beginPath()
      ctx.moveTo(width / 2, 28); ctx.lineTo(width / 2, 48)
      ctx.moveTo(width / 2, height - 28); ctx.lineTo(width / 2, height - 48)
      ctx.moveTo(28, height / 2); ctx.lineTo(48, height / 2)
      ctx.moveTo(width - 28, height / 2); ctx.lineTo(width - 48, height / 2)
      ctx.stroke()
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: { lock.wakeRequested(); lock.forcePasswordFocus() }
    onPositionChanged: lock.wakeRequested()
  }

  // The drawing: the time, outlined, with its dimensions called out.
  Item {
    id: drawing
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
    anchors.verticalCenterOffset: -Math.round(lock.height * 0.16)
    width: clockText.width
    height: clockText.height

    Text {
      id: clockText
      text: lock.clock("HH:mm")
      color: lock.withAlpha(lock.ink, 0.06)
      style: Text.Outline
      styleColor: lock.ink
      font.family: Style.font.family
      font.pixelSize: Math.round(Style.font.baseSize * 12)
      font.weight: Font.Bold
      font.letterSpacing: 6
    }

    Canvas {
      id: dims
      anchors.fill: parent
      anchors.margins: -70
      renderStrategy: Canvas.Cooperative
      onWidthChanged: requestPaint()
      onHeightChanged: requestPaint()
      Connections { target: clockText; function onTextChanged() { dims.requestPaint() } }

      function arrow(ctx, x, y, dx, dy) {
        ctx.beginPath()
        ctx.moveTo(x, y)
        ctx.lineTo(x - dx * 9 - dy * 4, y - dy * 9 + dx * 4)
        ctx.lineTo(x - dx * 9 + dy * 4, y - dy * 9 - dx * 4)
        ctx.closePath()
        ctx.fill()
      }

      onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        ctx.clearRect(0, 0, width, height)
        var x0 = 70, y0 = 70, w = clockText.width, h = clockText.height
        var c = lock.line
        ctx.strokeStyle = lock.withAlpha(c, 0.9)
        ctx.fillStyle = lock.withAlpha(c, 0.9)
        ctx.lineWidth = 1
        ctx.font = "13px " + Style.font.family
        ctx.textAlign = "center"
        // Width, above.
        var ty = y0 - 34
        ctx.beginPath(); ctx.moveTo(x0, y0 - 8); ctx.lineTo(x0, ty - 10); ctx.moveTo(x0 + w, y0 - 8); ctx.lineTo(x0 + w, ty - 10); ctx.stroke()
        ctx.beginPath(); ctx.moveTo(x0, ty); ctx.lineTo(x0 + w, ty); ctx.stroke()
        arrow(ctx, x0, ty, -1, 0); arrow(ctx, x0 + w, ty, 1, 0)
        ctx.fillText(Math.round(w) + " px", x0 + w / 2, ty - 8)
        // Height, to the right.
        var tx = x0 + w + 36
        ctx.beginPath(); ctx.moveTo(x0 + w + 8, y0); ctx.lineTo(tx + 10, y0); ctx.moveTo(x0 + w + 8, y0 + h); ctx.lineTo(tx + 10, y0 + h); ctx.stroke()
        ctx.beginPath(); ctx.moveTo(tx, y0); ctx.lineTo(tx, y0 + h); ctx.stroke()
        arrow(ctx, tx, y0, 0, -1); arrow(ctx, tx, y0 + h, 0, 1)
        ctx.save()
        ctx.translate(tx + 14, y0 + h / 2)
        ctx.rotate(-Math.PI / 2)
        ctx.fillText(Math.round(h) + " px", 0, 0)
        ctx.restore()
        // Centre marks and a datum.
        ctx.strokeStyle = lock.withAlpha(c, 0.55)
        ctx.setLineDash([6, 5])
        ctx.beginPath()
        ctx.moveTo(x0 - 30, y0 + h / 2); ctx.lineTo(x0 + w + 30, y0 + h / 2)
        ctx.moveTo(x0 + w / 2, y0 - 16); ctx.lineTo(x0 + w / 2, y0 + h + 16)
        ctx.stroke()
        ctx.setLineDash([])
        ctx.beginPath(); ctx.arc(x0 + w / 2, y0 + h / 2, 5, 0, 6.2832); ctx.stroke()
        // A leader from the first digit out to the lower left.
        ctx.textAlign = "left"
        ctx.beginPath(); ctx.moveTo(x0 + 14, y0 + h - 14); ctx.lineTo(x0 - 30, y0 + h + 26); ctx.lineTo(x0 + 120, y0 + h + 26); ctx.stroke()
        ctx.beginPath(); ctx.arc(x0 + 14, y0 + h - 14, 2.5, 0, 6.2832); ctx.fill()
        ctx.fillText("A  ·  " + lock.tr("LOCAL TIME"), x0 - 26, y0 + h + 44)
      }
    }
  }

  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: drawing.bottom
    anchors.topMargin: 78
    text: lock.date("dddd, d MMMM yyyy").toUpperCase()
    color: lock.withAlpha(lock.ink, 0.7)
    font.family: Style.font.family
    font.pixelSize: Style.font.body
    font.letterSpacing: 4
  }

  // Detail B: the sign-in.
  Item {
    id: detail
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
    anchors.verticalCenterOffset: Math.round(lock.height * 0.2)
    width: 460
    height: 110

    Rectangle {
      anchors.fill: parent
      color: "transparent"
      border.width: 1
      border.color: lock.withAlpha(lock.line, 0.8)
    }
    Rectangle {
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.leftMargin: -1
      anchors.topMargin: -1
      width: tag.implicitWidth + 20
      height: 22
      color: lock.withAlpha(lock.line, 0.9)
      Text {
        id: tag
        anchors.centerIn: parent
        text: "DETAIL B  ·  " + lock.tr("ACCESS")
        color: lock.paper
        font.family: Style.font.family
        font.pixelSize: 11
        font.weight: Font.Bold
        font.letterSpacing: 2
      }
    }
    PasswordField {
      id: field
      lock: lock
      anchors.centerIn: parent
      anchors.verticalCenterOffset: 8
      width: 400
      height: 54
      radius: 0
      outlineThickness: 1
      showLockGlyph: false
      shakeOnFail: true
      color: lock.withAlpha(lock.paper, 0.9)
    }
  }

  // The title block.
  Rectangle {
    id: title
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.rightMargin: 37
    anchors.bottomMargin: 37
    width: 420
    height: rows.implicitHeight + 2
    color: lock.withAlpha(lock.paper, 0.85)
    border.width: 1
    border.color: lock.withAlpha(lock.ink, 0.6)

    Column {
      id: rows
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: 1
      Repeater {
        model: [
          { k: "PROJECT", v: lock.hostName.toUpperCase() },
          { k: "DRAWN BY", v: lock.displayName.toUpperCase() },
          { k: "DATE", v: lock.date("yyyy-MM-dd") },
          { k: "SHEET", v: "1 OF 1" + (lock.hideTime ? "" : "  ·  NO. " + lock.sheetNo) },
          { k: "SCALE", v: "1 : 1  ·  REV " + (lock.failedAttempts > 0 ? String.fromCharCode(65 + Math.min(25, lock.failedAttempts)) : "A") }
        ]
        Rectangle {
          width: rows.width
          height: 30
          color: "transparent"
          border.width: 1
          border.color: lock.withAlpha(lock.ink, 0.3)
          Text {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: modelData.k
            color: lock.withAlpha(lock.ink, 0.5)
            font.family: Style.font.family
            font.pixelSize: 11
            font.letterSpacing: 2
          }
          Text {
            anchors.left: parent.left
            anchors.leftMargin: 130
            anchors.verticalCenter: parent.verticalCenter
            text: modelData.v
            textFormat: Text.PlainText
            color: lock.ink
            font.family: Style.font.family
            font.pixelSize: 12
            font.letterSpacing: 1
          }
        }
      }
    }
  }

  // The stamp a wrong password earns.
  Text {
    anchors.centerIn: drawing
    rotation: -14
    visible: lock.failedAttempts > 0
    opacity: 0.85
    text: lock.tr("REJECTED")
    color: Commons.Color.lock.textError
    font.family: Style.font.family
    font.pixelSize: Math.round(Style.font.baseSize * 4)
    font.weight: Font.Black
    font.letterSpacing: 10
    Rectangle {
      anchors.fill: parent
      anchors.margins: -14
      color: "transparent"
      border.width: 4
      border.color: Commons.Color.lock.textError
    }
  }

  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 48
    opacity: lock.snapshotMode ? 0 : 1
    text: lock.failedAttempts > 0
      ? lock.tr(lock.failedAttempts === 1 ? "1 failed attempt" : "%1 failed attempts").arg(lock.failedAttempts)
      : (lock.fingerprintConfigured ? lock.fingerprintHint(lock.tr("󰆠  Touch sensor or type password")) : lock.tr("Enter your password to unlock"))
    textFormat: Text.PlainText
    color: lock.failedAttempts > 0 ? Commons.Color.lock.textError : lock.withAlpha(lock.ink, 0.5)
    font.family: Style.font.family
    font.pixelSize: Style.font.bodySmall
    font.letterSpacing: 2
  }
}
