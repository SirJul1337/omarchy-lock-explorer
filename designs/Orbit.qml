import QtQuick
import qs.Commons
import "Ttfx.js" as Ttfx

// Four launchers circle the screen edge and fire the clock together from the
// middle out. A wrong password spins the digits into rings before they
// settle back.
DesignBase {
  id: lock
  inputItem: field.input
  flashOnFail: false

  Wallpaper { anchors.fill: parent; lock: lock; blur: 1; dim: 0.7 }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: { lock.wakeRequested(); lock.forcePasswordFocus() }
    onPositionChanged: lock.wakeRequested()
  }

  TtfxText {
    id: orbit
    anchors.centerIn: parent
    anchors.verticalCenterOffset: -Math.round(lock.height * 0.06)
    text: Ttfx.blockText(lock.clock("HH:mm").replace(/[^0-9:]/g, ""))
    effect: "orbittingvolley"
    replayEffect: "orbittingvolley"
    frameRate: 90
    pixelSize: Math.max(14, Math.round(lock.height / 36))
    columns: Math.floor(lock.width * 0.6 / Math.max(1, cellWidth))
    rows: Math.floor(lock.height * 0.62 / Math.max(1, cellHeight))
    effectOptions: ({
      orbittingvolley: ["--launch-delay", "20", "--volley-size", "0.05",
                        "--top-launcher-symbol", "●", "--right-launcher-symbol", "●",
                        "--bottom-launcher-symbol", "●", "--left-launcher-symbol", "●",
                        "--final-gradient-stops", Ttfx.hex(Color.lock.borderActive), Ttfx.hex(Color.lock.text)],
      rings: ["--spin-duration", "60", "--disperse-duration", "40", "--spin-disperse-cycles", "1",
              "--ring-colors", Ttfx.hex(Color.lock.textError), Ttfx.hex(Color.lock.borderActive), Ttfx.hex(Color.lock.text),
              "--final-gradient-stops", Ttfx.hex(Color.lock.borderActive), Ttfx.hex(Color.lock.text)]
    })
  }

  PasswordField {
    id: field
    lock: lock
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: Math.round(lock.height * 0.12)
    width: 360
    height: 50
    radius: 25
    outlineThickness: 1
    showLockGlyph: false
    color: lock.withAlpha(Color.lock.background, 0.55)
  }

  Connections {
    target: lock
    function onFailureMessageChanged() {
      if (lock.failureMessage.length > 0) orbit.play("rings", 60)
    }
  }
}
