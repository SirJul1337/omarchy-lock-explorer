import QtQuick
import qs.Commons
import "Ttfx.js" as Ttfx

// ttfx's matrix: code rain across the top of the screen that settles into the
// clock. Every new minute rains again, and a wrong password swaps the digits
// around until they correct themselves.
DesignBase {
  id: lock
  inputItem: field.input
  flashOnFail: false

  Rectangle { anchors.fill: parent; color: lock.deepen(Color.background, 1.7) }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: { lock.wakeRequested(); lock.forcePasswordFocus() }
    onPositionChanged: lock.wakeRequested()
  }

  TtfxText {
    id: rain
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top
    text: Ttfx.blockText(lock.clock("HH:mm").replace(/[^0-9:]/g, ""))
    effect: "matrix"
    replayEffect: "matrix"
    pixelSize: Math.max(12, Math.round(lock.height / 48))
    columns: Math.floor(lock.width / Math.max(1, cellWidth))
    rows: Math.floor(lock.height * 0.62 / Math.max(1, cellHeight))
    anchorText: "s"
    effectOptions: ({
      matrix: ["--rain-time", "3", "--resolve-delay", "2",
               "--highlight-color", Ttfx.hex(Color.lock.text),
               "--rain-color-gradient", Ttfx.hex(Color.muted), Ttfx.hex(Color.lock.borderActive),
               "--final-gradient-stops", Ttfx.hex(Color.lock.borderActive), Ttfx.hex(Color.lock.text)]
    })
  }

  Column {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: rain.bottom
    anchors.topMargin: Math.round(lock.height * 0.05)
    spacing: 18

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: lock.clock("yyyy-MM-dd  ddd").toLowerCase()
      color: lock.withAlpha(Color.lock.borderActive, 0.8)
      font.family: Style.font.family
      font.pixelSize: Style.font.title
      font.letterSpacing: 3
    }

    PasswordField {
      id: field
      lock: lock
      anchors.horizontalCenter: parent.horizontalCenter
      width: 380
      height: 46
      radius: 0
      outlineThickness: 1
      showLockGlyph: false
      color: Color.lock.background
      placeholder: "access code"
    }
  }

  Connections {
    target: lock
    function onFailureMessageChanged() {
      if (lock.failureMessage.length > 0) rain.play("errorcorrect")
    }
  }
}
