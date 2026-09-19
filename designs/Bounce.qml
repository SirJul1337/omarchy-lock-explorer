import QtQuick
import qs.Commons
import "Ttfx.js" as Ttfx

// The clock rains down as bouncing balls that land as its digits. Each new
// minute pours in from above, and a wrong password crumbles it.
DesignBase {
  id: lock
  inputItem: field.input
  shakeOnFail: true
  flashOnFail: false

  Wallpaper { anchors.fill: parent; lock: lock; blur: 0.9; dim: 0.55 }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: { lock.wakeRequested(); lock.forcePasswordFocus() }
    onPositionChanged: lock.wakeRequested()
  }

  TtfxText {
    id: clock
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: field.top
    anchors.bottomMargin: Math.round(lock.height * 0.05)
    text: Ttfx.blockText(lock.clock("HH:mm").replace(/[^0-9:]/g, ""))
    effect: "bouncyballs"
    replayEffect: "pour"
    pixelSize: Math.max(16, Math.round(lock.height / 30))
    anchorText: "s"
    columns: textColumns + 16
    // Tall canvas so the balls fall from near the top of the screen.
    rows: Math.floor((lock.height * 0.62) / Math.max(1, cellHeight))
    effectOptions: ({
      bouncyballs: ["--ball-symbols", "●", "o", "•", "--ball-delay", "2",
                    "--ball-colors", Ttfx.hex(Color.lock.borderActive), Ttfx.hex(Color.lock.text), Ttfx.hex(Color.lock.textError),
                    "--final-gradient-stops", Ttfx.hex(Color.lock.borderActive), Ttfx.hex(Color.lock.text)]
    })
  }

  PasswordField {
    id: field
    lock: lock
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: Math.round(lock.height * 0.22)
    width: 360
    height: 52
    radius: 26
    showLockGlyph: false
    shakeOnFail: false
    color: lock.withAlpha(Color.lock.background, 0.6)
  }

  Connections {
    target: lock
    function onFailureMessageChanged() {
      if (lock.failureMessage.length > 0) clock.play("crumble", 90)
    }
  }
}
