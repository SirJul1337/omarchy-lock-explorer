import QtQuick
import qs.Commons
import "Ttfx.js" as Ttfx

// Shells launch from the bottom of the screen, burst in the theme colors and
// the sparks fall into place as the clock. Every new minute gets its own
// show; a wrong password crumbles the digits.
DesignBase {
  id: lock
  inputItem: field.input
  shakeOnFail: true
  flashOnFail: false

  Wallpaper { anchors.fill: parent; lock: lock; blur: 1; dim: 0.78 }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: { lock.wakeRequested(); lock.forcePasswordFocus() }
    onPositionChanged: lock.wakeRequested()
  }

  TtfxText {
    id: show
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top
    text: Ttfx.blockText(lock.clock("HH:mm").replace(/[^0-9:]/g, ""))
    effect: "fireworks"
    replayEffect: "fireworks"
    frameRate: 90
    pixelSize: Math.max(14, Math.round(lock.height / 40))
    columns: Math.floor(lock.width * 0.9 / Math.max(1, cellWidth))
    rows: Math.floor(lock.height * 0.7 / Math.max(1, cellHeight))
    effectOptions: ({
      fireworks: ["--launch-delay", "20", "--firework-volume", "0.08", "--firework-symbol", "●",
                  "--firework-colors", Ttfx.hex(Color.lock.borderActive), Ttfx.hex(Color.lock.text), Ttfx.hex(Color.lock.textError), Ttfx.hex(Qt.lighter(Color.lock.borderActive, 1.4)),
                  "--final-gradient-stops", Ttfx.hex(Color.lock.borderActive), Ttfx.hex(Color.lock.text)]
    })
  }

  Column {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: show.bottom
    spacing: 16

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: lock.greeting()
      color: Color.lock.text
      font.family: Style.font.family
      font.pixelSize: Style.font.title
    }

    PasswordField {
      id: field
      lock: lock
      anchors.horizontalCenter: parent.horizontalCenter
      width: 360
      height: 50
      radius: 25
      showLockGlyph: false
      shakeOnFail: false
      color: lock.withAlpha(Color.lock.background, 0.6)
    }
  }

  Connections {
    target: lock
    function onFailureMessageChanged() {
      if (lock.failureMessage.length > 0) show.play("crumble")
    }
  }
}
