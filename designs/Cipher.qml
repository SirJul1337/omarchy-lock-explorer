import QtQuick
import qs.Commons
import "Ttfx.js" as Ttfx

// A block clock drawn by ttfx: it decrypts when the screen locks, slides the
// new time in every minute, catches a highlight when you start typing, and
// comes apart on a wrong password.
DesignBase {
  id: lock
  inputItem: field.input
  shakeOnFail: true
  flashOnFail: false

  readonly property int cell: Math.max(14, Math.round(Math.min(width / 120, height / 40)))

  Rectangle { anchors.fill: parent; color: lock.deepen(Color.background, 1.35) }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: { lock.wakeRequested(); lock.forcePasswordFocus() }
    onPositionChanged: lock.wakeRequested()
  }

  Column {
    anchors.centerIn: parent
    anchors.verticalCenterOffset: -Math.round(lock.height * 0.04)
    spacing: Math.round(lock.cell * 0.8)

    TtfxText {
      id: clock
      anchors.horizontalCenter: parent.horizontalCenter
      text: Ttfx.blockText(lock.clock("HH:mm").replace(/[^0-9:]/g, ""))
      effect: "decrypt"
      // decrypt is ~700 frames; at 150 fps it resolves in under five seconds.
      // Everything else plays at the normal 60.
      autoPlayRate: 150
      margin: 3
      pixelSize: lock.cell
      replayEffect: "slide"
    }

    TtfxText {
      id: caption
      anchors.horizontalCenter: parent.horizontalCenter
      text: (lock.meridiem ? lock.meridiem + "  ·  " : "") + lock.clock("dddd d MMMM")
      effect: "print"
      frameRate: 120
      margin: 1
      pixelSize: Style.font.heading
      textColor: lock.withAlpha(Color.lock.text, 0.75)
    }

    PasswordField {
      id: field
      lock: lock
      anchors.horizontalCenter: parent.horizontalCenter
      width: Math.max(360, Math.min(clock.width, 520))
      height: 50
      radius: 0
      outlineThickness: 1
      shakeOnFail: false
      showLockGlyph: false
      color: Color.lock.background
      placeholder: "passphrase"
    }
  }

  Connections {
    target: lock
    function onFailureMessageChanged() {
      if (lock.failureMessage.length === 0) return
      clock.play("unstable")
    }
  }

  Typing {
    lock: lock
    onTyped: function(index) { if (index === 0 && !clock.playing) clock.play("highlight") }
  }
}
