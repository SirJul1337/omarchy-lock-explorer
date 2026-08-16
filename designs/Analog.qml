import QtQuick
import qs.Commons

DesignBase {
  id: lock
  inputItem: field.input

  readonly property int faceSize: 300

  Wallpaper { anchors.fill: parent; lock: lock; blur: 0.9; dim: 0.12 }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: { lock.wakeRequested(); lock.forcePasswordFocus() }
    onPositionChanged: lock.wakeRequested()
  }

  Column {
    anchors.centerIn: parent
    spacing: 32

    Canvas {
      id: face
      width: lock.faceSize
      height: lock.faceSize
      anchors.horizontalCenter: parent.horizontalCenter
      property date t: lock.now
      onTChanged: requestPaint()
      onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        var c = width / 2
        var r = c - 6
        var fg = Color.lock.text
        var accent = Color.lock.borderActive
        var bg = Color.lock.background

        ctx.beginPath()
        ctx.arc(c, c, r, 0, Math.PI * 2)
        ctx.fillStyle = Qt.rgba(bg.r, bg.g, bg.b, 0.7)
        ctx.fill()
        ctx.lineWidth = 3
        ctx.strokeStyle = Qt.rgba(fg.r, fg.g, fg.b, 0.5)
        ctx.stroke()

        for (var i = 0; i < 60; i++) {
          var a = i * Math.PI / 30
          var len = i % 5 === 0 ? 14 : 6
          ctx.lineWidth = i % 5 === 0 ? 3 : 1
          ctx.strokeStyle = Qt.rgba(fg.r, fg.g, fg.b, i % 5 === 0 ? 0.9 : 0.4)
          ctx.beginPath()
          ctx.moveTo(c + Math.sin(a) * (r - 10), c - Math.cos(a) * (r - 10))
          ctx.lineTo(c + Math.sin(a) * (r - 10 - len), c - Math.cos(a) * (r - 10 - len))
          ctx.stroke()
        }

        var h = t.getHours() % 12, m = t.getMinutes(), s = t.getSeconds()
        function hand(angle, length, w, col) {
          ctx.lineWidth = w
          ctx.lineCap = "round"
          ctx.strokeStyle = col
          ctx.beginPath()
          ctx.moveTo(c - Math.sin(angle) * 14, c + Math.cos(angle) * 14)
          ctx.lineTo(c + Math.sin(angle) * length, c - Math.cos(angle) * length)
          ctx.stroke()
        }
        hand((h + m / 60) * Math.PI / 6, r * 0.5, 6, fg)
        hand((m + s / 60) * Math.PI / 30, r * 0.72, 4, fg)
        hand(s * Math.PI / 30, r * 0.8, 1.5, accent)

        ctx.beginPath()
        ctx.arc(c, c, 5, 0, Math.PI * 2)
        ctx.fillStyle = accent
        ctx.fill()
      }
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: Qt.formatDateTime(lock.now, "dddd d MMMM  ·  HH:mm")
      color: lock.withAlpha(Color.lock.text, 0.75)
      font.family: Style.font.family
      font.pixelSize: Style.font.title
      font.letterSpacing: 1
    }

    PasswordField {
      id: field
      lock: lock
      anchors.horizontalCenter: parent.horizontalCenter
      width: 360
      height: 54
      placeholder: lock.userName
    }
  }
}
