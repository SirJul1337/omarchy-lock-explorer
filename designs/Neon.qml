import QtQuick
import QtQuick.Effects
import qs.Commons

DesignBase {
  id: lock
  inputItem: field.input

  readonly property color glow: errorState ? Color.lock.textError : Color.lock.borderActive

  Rectangle { anchors.fill: parent; color: Qt.darker(Color.background, 1.35) }

  Canvas {
    anchors.fill: parent
    opacity: 0.35
    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      var horizon = height * 0.62
      var g = lock.glow
      ctx.strokeStyle = Qt.rgba(g.r, g.g, g.b, 0.35)
      ctx.lineWidth = 1
      for (var i = 0; i <= 12; i++) {
        var y = horizon + Math.pow(i / 12, 2.2) * (height - horizon)
        ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(width, y); ctx.stroke()
      }
      var cx = width / 2
      for (var k = -14; k <= 14; k++) {
        ctx.beginPath()
        ctx.moveTo(cx + k * 40, horizon)
        ctx.lineTo(cx + k * 260, height)
        ctx.stroke()
      }
    }
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    property color glowColor: lock.glow
    onGlowColorChanged: requestPaint()
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: { lock.wakeRequested(); lock.forcePasswordFocus() }
    onPositionChanged: lock.wakeRequested()
  }

  Column {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
    anchors.verticalCenterOffset: -Math.round(parent.height * 0.08)
    spacing: 36

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: Qt.formatTime(lock.now, "HH:mm")
      color: Color.lock.borderActive
      font.family: Style.font.family
      font.pixelSize: Math.round(Style.font.baseSize * 11)
      font.weight: Font.Bold
      font.letterSpacing: 6
      layer.enabled: true
      layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: Color.lock.borderActive
        shadowBlur: 1.0
        shadowScale: 1.04
        shadowOpacity: 0.9
      }
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: Qt.formatDate(lock.now, "dddd  ·  d MMMM").toUpperCase()
      color: Color.lock.text
      font.family: Style.font.family
      font.pixelSize: Style.font.title
      font.letterSpacing: 6
      layer.enabled: true
      layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Color.lock.text; shadowBlur: 0.6; shadowOpacity: 0.5 }
    }

    Item {
      anchors.horizontalCenter: parent.horizontalCenter
      width: field.width
      height: field.height
      layer.enabled: true
      layer.effect: MultiEffect { shadowEnabled: true; shadowColor: lock.glow; shadowBlur: 1.0; shadowScale: 1.02; shadowOpacity: 0.8 }
      PasswordField {
        id: field
        lock: lock
        width: 380
        height: 54
        radius: 27
        showLockGlyph: false
        color: Qt.rgba(0, 0, 0, 0.55)
        placeholder: lock.userName
      }
    }
  }

  Text {
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 36
    anchors.horizontalCenter: parent.horizontalCenter
    text: lock.fingerprintConfigured ? "TOUCH SENSOR OR TYPE PASSWORD" : "TYPE PASSWORD  ·  ENTER TO UNLOCK"
    color: lock.withAlpha(Color.lock.text, 0.45)
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
    font.letterSpacing: 4
  }
}
