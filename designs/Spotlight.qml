import QtQuick
import qs.Commons
import "Ttfx.js" as Ttfx

// A dark stage: three spotlights sweep over the clock, meet in the middle and
// light it up. A wrong password sends out a single quick searchlight.
DesignBase {
  id: lock
  inputItem: field.input
  shakeOnFail: true
  flashOnFail: false

  Rectangle { anchors.fill: parent; color: lock.deepen(Color.background, 2.4) }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: { lock.wakeRequested(); lock.forcePasswordFocus() }
    onPositionChanged: lock.wakeRequested()
  }

  Column {
    anchors.centerIn: parent
    spacing: Math.round(lock.height * 0.04)

    TtfxText {
      id: stage
      anchors.horizontalCenter: parent.horizontalCenter
      text: Ttfx.blockText(lock.clock("HH:mm").replace(/[^0-9:]/g, ""))
      effect: "spotlights"
      replayEffect: "spotlights"
      margin: 3
      pixelSize: Math.max(14, Math.round(lock.height / 30))
      effectOptions: ({
        spotlights: ["--search-duration", "200", "--spotlight-count", "3", "--beam-width-ratio", "2.5",
                     "--final-gradient-stops", Ttfx.hex(Color.lock.borderActive), Ttfx.hex(Color.lock.text)],
        searchlight: { effect: "spotlights", args: ["--search-duration", "60", "--spotlight-count", "1",
                     "--final-gradient-stops", Ttfx.hex(Color.lock.textError), Ttfx.hex(Color.lock.text)] }
      })
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: lock.clock("dddd d MMMM")
      color: lock.withAlpha(Color.lock.text, 0.4)
      font.family: Style.font.family
      font.pixelSize: Style.font.title
      font.letterSpacing: 2
    }

    PasswordField {
      id: field
      lock: lock
      anchors.horizontalCenter: parent.horizontalCenter
      width: 340
      height: 46
      radius: 23
      outlineThickness: 1
      showLockGlyph: false
      shakeOnFail: false
      color: Qt.rgba(1, 1, 1, 0.04)
    }
  }

  Connections {
    target: lock
    function onFailureMessageChanged() {
      if (lock.failureMessage.length > 0) stage.play("searchlight")
    }
  }
}
