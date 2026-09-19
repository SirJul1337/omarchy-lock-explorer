import QtQuick
import qs.Commons
import "Ttfx.js" as Ttfx

// A paused tape: VCR on-screen display around a clock that tracks badly.
// It glitches in on lock, blips now and then and on every new minute, and a
// wrong password rewinds with red tracking lines.
DesignBase {
  id: lock
  inputItem: field.input
  flashOnFail: false

  readonly property int osdSize: Math.max(22, Math.round(lock.height / 26))
  property bool rewinding: false

  Rectangle { anchors.fill: parent; color: lock.deepen(Color.background, 1.3) }

  Canvas {
    anchors.fill: parent
    opacity: 0.18
    onPaint: {
      var ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)
      ctx.fillStyle = "#000000"
      for (var y = 0; y < height; y += 4) ctx.fillRect(0, y, width, 2)
    }
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: { lock.wakeRequested(); lock.forcePasswordFocus() }
    onPositionChanged: lock.wakeRequested()
  }

  component Osd: Text {
    color: Color.lock.text
    font.family: Style.font.family
    font.pixelSize: lock.osdSize
    font.weight: Font.Bold
    style: Text.Outline
    styleColor: Qt.rgba(0, 0, 0, 0.5)
  }

  Osd {
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.margins: Math.round(lock.height * 0.07)
    text: lock.rewinding ? "◀◀ REW" : "▮▮ PAUSE"
    SequentialAnimation on opacity {
      loops: Animation.Infinite
      running: lock.visible
      NumberAnimation { from: 1; to: 1; duration: 900 }
      NumberAnimation { from: 1; to: 0; duration: 1 }
      NumberAnimation { from: 0; to: 0; duration: 500 }
      NumberAnimation { from: 0; to: 1; duration: 1 }
    }
  }

  Osd {
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: Math.round(lock.height * 0.07)
    text: "SP"
  }

  Osd {
    anchors.left: parent.left
    anchors.bottom: parent.bottom
    anchors.margins: Math.round(lock.height * 0.07)
    text: lock.clock("HH:mm:ss")
    font.pixelSize: Math.round(lock.osdSize * 0.8)
  }

  Osd {
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.margins: Math.round(lock.height * 0.07)
    text: lock.clock("MMM. d yyyy").toUpperCase()
    font.pixelSize: Math.round(lock.osdSize * 0.8)
  }

  Column {
    anchors.centerIn: parent
    spacing: Math.round(lock.height * 0.05)

    TtfxText {
      id: tape
      anchors.horizontalCenter: parent.horizontalCenter
      text: Ttfx.blockText(lock.clock("HH:mm").replace(/[^0-9:]/g, ""))
      effect: "vhstape"
      replayEffect: "blip"
      margin: 4
      pixelSize: Math.max(14, Math.round(lock.height / 34))
      effectOptions: ({
        vhstape: ["--total-glitch-time", "200", "--final-gradient-stops", Ttfx.hex(Color.lock.text), Ttfx.hex(Color.lock.text)],
        blip: { effect: "vhstape", args: ["--total-glitch-time", "45", "--glitch-line-chance", "0.2",
                "--final-gradient-stops", Ttfx.hex(Color.lock.text), Ttfx.hex(Color.lock.text)] },
        rewind: { effect: "vhstape", args: ["--total-glitch-time", "80", "--glitch-line-chance", "0.35", "--noise-chance", "0.05",
                  "--glitch-line-colors", Ttfx.hex(Qt.lighter(Color.lock.text, 1.25)), Ttfx.hex(Color.lock.textError), Ttfx.hex(Qt.lighter(Color.lock.text, 1.25)),
                  "--final-gradient-stops", Ttfx.hex(Color.lock.text), Ttfx.hex(Color.lock.text)] }
      })
      onFinished: lock.rewinding = false
    }

    PasswordField {
      id: field
      lock: lock
      anchors.horizontalCenter: parent.horizontalCenter
      width: 380
      height: 50
      radius: 0
      outlineThickness: 2
      showLockGlyph: false
      color: Color.lock.background
      placeholder: "PASSWORD"
    }
  }

  // Tracking slips every so often while it sits there.
  Timer {
    interval: 17000
    repeat: true
    running: lock.visible
    onTriggered: if (!tape.playing) tape.play("blip")
  }

  Connections {
    target: lock
    function onFailureMessageChanged() {
      if (lock.failureMessage.length === 0) return
      lock.rewinding = true
      tape.play("rewind")
    }
  }
}
