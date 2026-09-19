import QtQuick
import qs.Commons
import "Ttfx.js" as Ttfx

// A laser etches a large Omarchy logo, and the password is typed into its
// hollow middle: no box, just the dots. A wrong password crumbles the logo
// around them and sweeps it back.
DesignBase {
  id: lock
  inputItem: input
  flashOnFail: false

  Rectangle { anchors.fill: parent; color: lock.deepen(Color.background, 2) }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: { lock.wakeRequested(); lock.forcePasswordFocus() }
    onPositionChanged: lock.wakeRequested()
  }

  OmarchyLogo { id: logoSource }

  LockInput { id: input; lock: lock; width: 1; height: 1; opacity: 0 }

  TtfxText {
    id: art
    anchors.centerIn: parent
    text: logoSource.text
    effect: "laseretch"
    replayEffect: "laseretch"
    margin: 3
    pixelSize: Math.max(8, Math.round(lock.height * 0.66 / Math.max(1, textRows) / 1.3))
    effectOptions: ({
      laseretch: ["--etch-speed", "8",
                  "--laser-gradient-stops", Ttfx.hex(Qt.lighter(Color.lock.text, 1.25)), Ttfx.hex(Color.lock.borderActive),
                  "--spark-gradient-stops", Ttfx.hex(Qt.lighter(Color.lock.text, 1.25)), Ttfx.hex(Color.lock.borderActive),
                  "--cool-gradient-stops", Ttfx.hex(Color.lock.borderActive), Ttfx.hex(Color.muted),
                  "--final-gradient-stops", Ttfx.hex(Color.lock.borderActive), Ttfx.hex(Color.lock.text)],
      crumble: ["--final-gradient-stops", Ttfx.hex(Color.lock.borderActive), Ttfx.hex(Color.lock.text)]
    })
  }

  // The logo's hollow is roughly the middle 55% by 50% of it.
  Column {
    anchors.centerIn: art
    width: art.width * 0.5
    spacing: Math.round(lock.height * 0.022)

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: lock.greeting().toLowerCase()
      color: lock.withAlpha(Color.lock.text, 0.45)
      font.family: Style.font.family
      font.pixelSize: Style.font.heading
      font.letterSpacing: 3
    }

    Item {
      anchors.horizontalCenter: parent.horizontalCenter
      width: parent.width
      height: Math.round(lock.height * 0.05)

      Text {
        anchors.centerIn: parent
        visible: lock.passwordText.length > 0
        text: Ttfx.masked(lock, "●", 14)
        color: lock.errorState ? Color.lock.textError : Color.lock.text
        font.family: Style.font.family
        font.pixelSize: Math.round(lock.height * 0.034)
        font.letterSpacing: Math.round(lock.height * 0.008)
        textFormat: Text.PlainText
      }

      Text {
        anchors.centerIn: parent
        visible: lock.passwordText.length === 0
        text: Ttfx.inputStatus(lock, "type to unlock")
        color: lock.errorState ? Color.lock.textError : lock.withAlpha(Color.lock.text, lock.authenticatingPassword ? 0.9 : 0.35)
        font.family: Style.font.family
        font.pixelSize: Style.font.title
        font.italic: lock.errorState
        textFormat: Text.PlainText
      }

      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        width: parent.width * (lock.passwordText.length > 0 ? 0.8 : 0.3)
        height: 2
        radius: 1
        color: lock.errorState ? Color.lock.textError : Color.lock.borderActive
        opacity: 0.7
        Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
      }
    }

    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 10
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: lock.clock("HH:mm") + "  ·  " + lock.clock("ddd d MMM").toLowerCase()
        color: lock.withAlpha(Color.lock.text, 0.35)
        font.family: Style.font.family
        font.pixelSize: Style.font.body
      }
      EyeButton { lock: lock; anchors.verticalCenter: parent.verticalCenter; size: Style.font.body }
    }
  }

  Connections {
    target: lock
    function onFailureMessageChanged() {
      if (lock.failureMessage.length > 0) art.play("crumble", 150)
    }
  }
}
