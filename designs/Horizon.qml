import QtQuick
import qs.Commons
import "Ttfx.js" as Ttfx

// Event horizon: the clock's cells scatter as stars, get pulled into a black
// hole and burst back out into the time. A wrong password flings them apart.
DesignBase {
  id: lock
  inputItem: field.input
  flashOnFail: false

  Rectangle { anchors.fill: parent; color: lock.deepen(Color.background, 2.2) }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: { lock.wakeRequested(); lock.forcePasswordFocus() }
    onPositionChanged: lock.wakeRequested()
  }

  TtfxText {
    id: space
    anchors.centerIn: parent
    anchors.verticalCenterOffset: -Math.round(lock.height * 0.06)
    text: Ttfx.blockText(lock.clock("HH:mm").replace(/[^0-9:]/g, ""))
    effect: "blackhole"
    replayEffect: "blackhole"
    frameRate: 150
    pixelSize: Math.max(14, Math.round(lock.height / 40))
    columns: textColumns + 30
    rows: textRows + 14
    effectOptions: ({
      blackhole: ["--blackhole-color", Ttfx.hex(Color.lock.borderActive),
                  "--star-colors", Ttfx.hex(Color.lock.text), Ttfx.hex(Color.lock.borderActive), Ttfx.hex(Color.muted),
                  "--final-gradient-stops", Ttfx.hex(Color.lock.borderActive), Ttfx.hex(Color.lock.text)]
    })
  }

  Column {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: Math.round(lock.height * 0.1)
    spacing: 14

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: lock.clock("dddd d MMMM").toLowerCase()
      color: lock.withAlpha(Color.lock.text, 0.5)
      font.family: Style.font.family
      font.pixelSize: Style.font.heading
      font.letterSpacing: 3
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
      color: Color.lock.background
    }
  }

  Connections {
    target: lock
    function onFailureMessageChanged() {
      if (lock.failureMessage.length > 0) space.play("unstable", 60)
    }
  }
}
