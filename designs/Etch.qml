import QtQuick
import qs.Commons
import "Ttfx.js" as Ttfx

// A laser etches the greeting and the time onto the screen, sparks cooling
// into the theme accent. The new minute catches a highlight; a wrong password
// scatters the words and lets them fall back into line.
DesignBase {
  id: lock
  inputItem: field.input
  flashOnFail: false

  Wallpaper { anchors.fill: parent; lock: lock; blur: 1; dim: 0.72 }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: { lock.wakeRequested(); lock.forcePasswordFocus() }
    onPositionChanged: lock.wakeRequested()
  }

  Column {
    anchors.left: parent.left
    anchors.bottom: parent.bottom
    anchors.leftMargin: Math.round(lock.width * 0.07)
    anchors.bottomMargin: Math.round(lock.height * 0.12)
    spacing: 22

    TtfxText {
      id: words
      text: lock.greeting().toLowerCase() + ".\n" + lock.clock("HH:mm") + "  " + lock.clock("ddd d MMM").toLowerCase()
      effect: "laseretch"
      replayEffect: "highlight"
      margin: 1
      pixelSize: Math.max(24, Math.round(lock.height / 18))
      effectOptions: ({
        laseretch: ["--etch-speed", "1", "--etch-delay", "2",
                    "--laser-gradient-stops", Ttfx.hex(Qt.lighter(Color.lock.text, 1.25)), Ttfx.hex(Color.lock.borderActive),
                    "--spark-gradient-stops", Ttfx.hex(Qt.lighter(Color.lock.text, 1.25)), Ttfx.hex(Color.lock.borderActive), Ttfx.hex(Color.lock.textError),
                    "--cool-gradient-stops", Ttfx.hex(Color.lock.borderActive), Ttfx.hex(Color.muted),
                    "--final-gradient-stops", Ttfx.hex(Color.lock.text), Ttfx.hex(Color.lock.borderActive),
                    "--final-gradient-direction", "horizontal"]
      })
    }

    PasswordField {
      id: field
      lock: lock
      x: Math.round(words.cellWidth)
      width: Math.max(360, words.width * 0.45)
      height: 50
      radius: 8
      outlineThickness: 1
      showLockGlyph: false
      textAlignment: TextInput.AlignLeft
      color: lock.withAlpha(Color.lock.background, 0.5)
    }
  }

  Connections {
    target: lock
    function onFailureMessageChanged() {
      if (lock.failureMessage.length > 0) words.play("scattered")
    }
  }
}
