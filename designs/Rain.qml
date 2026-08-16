import QtQuick
import qs.Commons

DesignBase {
  id: lock
  inputItem: field.input

  readonly property int cellSize: 20
  readonly property string glyphs: "ｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝ0123456789ABCDEFXYZ<>*+-="
  property var drops: []

  Rectangle { anchors.fill: parent; color: Qt.darker(Color.background, 1.4) }

  Canvas {
    id: canvas
    anchors.fill: parent
    renderStrategy: Canvas.Cooperative

    function resetDrops() {
      var cols = Math.ceil(width / lock.cellSize)
      var d = []
      for (var i = 0; i < cols; i++) d.push({ y: Math.random() * -50, speed: 0.4 + Math.random() * 0.8 })
      lock.drops = d
      if (available) { var ctx = getContext("2d"); ctx.reset() }
    }
    onWidthChanged: resetDrops()
    onHeightChanged: resetDrops()
    onAvailableChanged: if (available) resetDrops()

    onPaint: {
      var ctx = getContext("2d")
      var bg = Qt.darker(Color.background, 1.4)
      ctx.fillStyle = Qt.rgba(bg.r, bg.g, bg.b, 0.18)
      ctx.fillRect(0, 0, width, height)
      ctx.font = "bold " + (lock.cellSize - 4) + "px " + Style.font.family
      var accent = Color.lock.borderActive
      var head = Color.lock.text
      var rows = height / lock.cellSize
      var d = lock.drops
      for (var i = 0; i < d.length; i++) {
        var ch = lock.glyphs.charAt(Math.floor(Math.random() * lock.glyphs.length))
        var x = i * lock.cellSize
        var y = Math.floor(d[i].y) * lock.cellSize
        ctx.fillStyle = Qt.rgba(accent.r, accent.g, accent.b, 0.85)
        ctx.fillText(ch, x, y)
        ctx.fillStyle = Qt.rgba(head.r, head.g, head.b, 0.9)
        ctx.fillText(lock.glyphs.charAt(Math.floor(Math.random() * lock.glyphs.length)), x, y + lock.cellSize)
        d[i].y += d[i].speed
        if (d[i].y > rows + 10 && Math.random() > 0.97) { d[i].y = Math.random() * -20; d[i].speed = 0.4 + Math.random() * 0.8 }
      }
    }
  }

  Timer {
    interval: 66
    running: canvas.visible
    repeat: true
    onTriggered: canvas.requestPaint()
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: { lock.wakeRequested(); lock.forcePasswordFocus() }
    onPositionChanged: lock.wakeRequested()
  }

  Rectangle {
    anchors.centerIn: parent
    width: box.implicitWidth + 80
    height: box.implicitHeight + 64
    radius: 6
    color: Qt.rgba(0, 0, 0, 0.72)
    border.width: 1
    border.color: lock.withAlpha(Color.lock.borderActive, 0.6)

    Column {
      id: box
      anchors.centerIn: parent
      spacing: 18
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.formatTime(lock.now, "HH:mm:ss")
        color: Color.lock.borderActive
        font.family: Style.font.family
        font.pixelSize: Math.round(Style.font.baseSize * 6)
        font.weight: Font.Bold
        font.letterSpacing: 2
      }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "wake up, " + lock.userName + "..."
        color: lock.withAlpha(Color.lock.text, 0.8)
        font.family: Style.font.family
        font.pixelSize: Style.font.heading
      }
      PasswordField {
        id: field
        lock: lock
        anchors.horizontalCenter: parent.horizontalCenter
        width: 380
        height: 50
        radius: 4
        outlineThickness: 1
        color: Qt.rgba(0, 0, 0, 0.6)
        placeholder: "follow the white rabbit"
      }
    }
  }
}
