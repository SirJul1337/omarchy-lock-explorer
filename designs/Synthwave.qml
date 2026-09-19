import QtQuick
import qs.Commons
import "Ttfx.js" as Ttfx

// A wide ttfx synthgrid: grid lines draw across the screen and the blocks
// dissolve into the clock. A sweep brings in each new minute, and a wrong
// password blows the digits out to the edges of the grid.
DesignBase {
  id: lock
  inputItem: field.input
  flashOnFail: false

  Rectangle {
    anchors.fill: parent
    gradient: Gradient {
      GradientStop { position: 0; color: lock.deepen(Color.background, 1.8) }
      GradientStop { position: 1; color: lock.deepen(Color.background, 1.1) }
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: { lock.wakeRequested(); lock.forcePasswordFocus() }
    onPositionChanged: lock.wakeRequested()
  }

  TtfxText {
    id: grid
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top
    anchors.topMargin: Math.round(lock.height * 0.1)
    text: Ttfx.blockText(lock.clock("HH:mm").replace(/[^0-9:]/g, ""))
    effect: "synthgrid"
    replayEffect: "sweep"
    pixelSize: Math.max(12, Math.round(lock.height / 56))
    columns: Math.floor(lock.width * 0.8 / Math.max(1, cellWidth))
    rows: Math.floor(lock.height * 0.55 / Math.max(1, cellHeight))
    effectOptions: ({
      synthgrid: ["--grid-gradient-stops", Ttfx.hex(Color.lock.borderActive), Ttfx.hex(Color.muted),
                  "--text-gradient-stops", Ttfx.hex(Color.lock.borderActive), Ttfx.hex(Color.lock.text),
                  "--max-active-blocks", "0.2"]
    })
  }

  Column {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: grid.bottom
    anchors.topMargin: Math.round(lock.height * 0.04)
    spacing: 18

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: lock.clock("dddd  ·  d MMMM")
      color: Color.lock.borderActive
      font.family: Style.font.family
      font.pixelSize: Style.font.title
      font.letterSpacing: 2
    }

    PasswordField {
      id: field
      lock: lock
      anchors.horizontalCenter: parent.horizontalCenter
      width: 380
      height: 48
      radius: 0
      outlineThickness: 1
      showLockGlyph: false
      shakeOnFail: false
      color: Color.lock.background
    }
  }

  Connections {
    target: lock
    function onFailureMessageChanged() {
      if (lock.failureMessage.length > 0) grid.play("unstable")
    }
  }
}
