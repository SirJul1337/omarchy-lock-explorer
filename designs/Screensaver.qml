import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "Ttfx.js" as Ttfx

// The Omarchy screensaver as a lock screen: your branding logo from
// ~/.config/omarchy/branding/screensaver.txt, run through one ttfx effect after
// another across the whole screen, with the clock and field tucked underneath.
DesignBase {
  id: lock
  inputItem: field.input

  property string logo: "omarchy"
  property int lastPick: -1

  FileView {
    path: Quickshell.env("HOME") + "/.config/omarchy/branding/screensaver.txt"
    printErrors: false
    onLoaded: {
      var t = String(text() || "").replace(/\s+$/, "")
      if (t.length > 0) lock.logo = t
    }
  }

  Rectangle { anchors.fill: parent; color: Color.background }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: { lock.wakeRequested(); lock.forcePasswordFocus() }
    onPositionChanged: lock.wakeRequested()
  }

  TtfxText {
    id: art
    anchors.centerIn: parent
    anchors.verticalCenterOffset: -Math.round(lock.height * 0.08)
    text: lock.logo
    effect: "beams"
    pixelSize: Math.max(12, Math.round(lock.height / 62))
    // A band around the logo rather than most of the screen: effects still
    // have room to move, and far less of the screen changes every frame.
    columns: Math.min(Math.floor(lock.width * 0.9 / Math.max(1, cellWidth)), textColumns + 40)
    rows: Math.min(Math.floor(lock.height * 0.7 / Math.max(1, cellHeight)), textRows + 14)
    replayOnTextChange: true
    onFinished: if (active) pause.restart()
  }

  // A beat on the finished logo before the next effect, like the screensaver.
  Timer {
    id: pause
    interval: 2500
    onTriggered: {
      var list = Ttfx.QUICK.concat(Ttfx.SHOWY)
      var i = Math.floor(Math.random() * list.length)
      if (i === lock.lastPick) i = (i + 1) % list.length
      lock.lastPick = i
      art.play(list[i])
    }
  }

  Connections {
    target: lock
    function onFailureMessageChanged() {
      if (lock.failureMessage.length === 0) return
      pause.stop()
      art.play("errorcorrect")
    }
  }

  Column {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: Math.round(lock.height * 0.08)
    spacing: 14

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: lock.clock("HH:mm")
      color: Color.lock.text
      font.family: Style.font.family
      font.pixelSize: Math.round(Style.font.baseSize * 3)
      font.weight: Font.DemiBold
    }

    PasswordField {
      id: field
      lock: lock
      anchors.horizontalCenter: parent.horizontalCenter
      width: 360
      height: 48
      radius: 6
      outlineThickness: 1
      showLockGlyph: false
      color: lock.withAlpha(Color.lock.background, 0.7)
    }
  }
}
