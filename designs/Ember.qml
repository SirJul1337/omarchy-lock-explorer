import QtQuick
import qs.Commons
import "Ttfx.js" as Ttfx

// A block clock that burns into place: ttfx's burn effect from the theme's
// text through its accent to its error red, cooling to the theme as it
// settles. Each new minute burns in again, and a wrong
// password crumbles it to dust and back.
DesignBase {
  id: lock
  inputItem: field.input
  shakeOnFail: false
  flashOnFail: false

  readonly property int cell: Math.max(14, Math.round(Math.min(width / 100, height / 34)))
  readonly property var fire: [Ttfx.hex(Qt.lighter(Color.lock.text, 1.25)), Ttfx.hex(Qt.lighter(Color.lock.borderActive, 1.3)),
                              Ttfx.hex(Color.lock.borderActive), Ttfx.hex(Color.lock.textError), Ttfx.hex(Qt.darker(Color.lock.textError, 2.2))]

  Rectangle { anchors.fill: parent; color: lock.deepen(Color.background, 1.6) }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: { lock.wakeRequested(); lock.forcePasswordFocus() }
    onPositionChanged: lock.wakeRequested()
  }

  Column {
    anchors.centerIn: parent
    spacing: Math.round(lock.cell * 1.2)

    TtfxText {
      id: clock
      anchors.horizontalCenter: parent.horizontalCenter
      text: Ttfx.blockText(lock.clock("HH:mm").replace(/[^0-9:]/g, ""))
      effect: "burn"
      replayEffect: "burn"
      margin: 2
      pixelSize: lock.cell
      effectOptions: ({
        burn: ["--starting-color", Ttfx.hex(Color.muted), "--burn-colors"].concat(lock.fire)
          .concat(["--smoke-chance", "0.25", "--final-gradient-stops", Ttfx.hex(Color.lock.borderActive), Ttfx.hex(Color.lock.text)])
      })
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: lock.clock("dddd d MMMM").toUpperCase()
      color: lock.withAlpha(Color.lock.text, 0.55)
      font.family: Style.font.family
      font.pixelSize: Style.font.body
      font.letterSpacing: 4
    }

    PasswordField {
      id: field
      lock: lock
      anchors.horizontalCenter: parent.horizontalCenter
      width: Math.max(320, clock.width * 0.7)
      height: 46
      radius: 23
      outlineThickness: 1
      showLockGlyph: false
      color: Color.lock.background
    }
  }

  Connections {
    target: lock
    function onFailureMessageChanged() {
      if (lock.failureMessage.length > 0) clock.play("crumble", 90)
    }
  }
}
