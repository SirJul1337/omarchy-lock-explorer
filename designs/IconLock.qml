import QtQuick
import qs.Commons
import "Ttfx.js" as Ttfx

// Shared layout for the logo designs: the square Omarchy logo animated by
// ttfx, a small clock and date under it, and the field. Each design picks the
// effects. The logo comes from OmarchyLogo, so it follows the branding.
DesignBase {
  id: lock
  inputItem: field.input
  flashOnFail: false

  // Played when the screen locks.
  property string logoEffect: "beams"
  property int logoRate: 60
  // Played on a wrong password.
  property string failEffect: "unstable"
  property int failRate: 60
  // Played every idleInterval ms while nothing else is, 0 for never.
  property string idleEffect: ""
  property int idleRate: 60
  property int idleInterval: 0
  property var effectOptions: ({})

  // How much of the screen height the logo takes, and the room around it in
  // cells for effects that throw characters about.
  property real logoScale: 0.4
  property int padColumns: 12
  property int padRows: 6
  property real backgroundDarkness: 1.8
  property bool wallpaper: false
  property string placeholder: "Enter password"

  readonly property alias logo: art

  OmarchyLogo { id: logoSource }

  Rectangle {
    anchors.fill: parent
    visible: !lock.wallpaper
    color: lock.deepen(Color.background, lock.backgroundDarkness)
  }

  Wallpaper {
    anchors.fill: parent
    visible: lock.wallpaper
    lock: lock
    blur: 1
    dim: 0.75
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: { lock.wakeRequested(); lock.forcePasswordFocus() }
    onPositionChanged: lock.wakeRequested()
  }

  TtfxText {
    id: art
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
    anchors.verticalCenterOffset: -Math.round(lock.height * 0.1)
    text: logoSource.text
    effect: lock.logoEffect
    frameRate: lock.logoRate
    autoPlayRate: lock.logoRate
    replayEffect: lock.logoEffect
    // A cell is about 1.3 times as tall as the font's pixel size.
    pixelSize: Math.max(8, Math.round(lock.height * lock.logoScale / Math.max(1, textRows) / 1.3))
    columns: textColumns + lock.padColumns
    rows: textRows + lock.padRows
    effectOptions: lock.effectOptions
    onFinished: if (lock.idleInterval > 0) idle.restart()
  }

  Timer {
    id: idle
    interval: lock.idleInterval
    onTriggered: {
      if (art.playing || lock.idleEffect.length === 0) return
      art.play(lock.idleEffect, lock.idleRate)
    }
  }

  Column {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: art.bottom
    anchors.topMargin: Math.round(lock.height * 0.01)
    spacing: 14

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: lock.clock("HH:mm") + "   " + lock.clock("ddd d MMM")
      color: lock.withAlpha(Color.lock.text, 0.7)
      font.family: Style.font.family
      font.pixelSize: Style.font.title
      font.letterSpacing: 2
    }

    PasswordField {
      id: field
      lock: lock
      anchors.horizontalCenter: parent.horizontalCenter
      width: 360
      height: 48
      radius: 24
      outlineThickness: 1
      showLockGlyph: false
      color: Color.lock.background
      placeholder: lock.placeholder
    }
  }

  Connections {
    target: lock
    function onFailureMessageChanged() {
      if (lock.failureMessage.length === 0) return
      idle.stop()
      art.play(lock.failEffect, lock.failRate)
    }
  }
}
