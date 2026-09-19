import QtQuick
import qs.Commons
import "Ttfx.js" as Ttfx

// An editor waiting for a command: code rain resolves into the Omarchy logo,
// a status bar runs along the bottom with the mode on the left, and the
// password goes into the command line as :unlock. A wrong password prints the
// error there and scrambles the logo.
DesignBase {
  id: lock
  inputItem: input
  flashOnFail: false

  readonly property int fs: Math.max(15, Math.round(height / 44))
  readonly property color barColor: Qt.lighter(Color.background, 1.35)
  readonly property color modeColor: errorState ? Color.lock.textError
    : authenticatingPassword ? Color.lock.text : Color.lock.borderActive

  Rectangle { anchors.fill: parent; color: lock.deepen(Color.background, 1.5) }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: { lock.wakeRequested(); lock.forcePasswordFocus() }
    onPositionChanged: lock.wakeRequested()
  }

  OmarchyLogo { id: logoSource }

  LockInput { id: input; lock: lock; width: 1; height: 1; opacity: 0 }

  component Mono: Text {
    color: Color.lock.text
    font.family: Style.font.family
    font.pixelSize: lock.fs
    textFormat: Text.PlainText
    verticalAlignment: Text.AlignVCenter
  }

  TtfxText {
    id: art
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top
    text: logoSource.text
    effect: "matrix"
    replayEffect: "matrix"
    // The resolve is counted in frames: ~700 cells take 13 s at 60 fps, so it
    // runs at 150. The rain stays a band around the logo rather than the whole
    // screen, which keeps each frame cheap enough to paint at that rate.
    frameRate: 150
    autoPlayRate: 150
    pixelSize: Math.max(8, Math.round(lock.height * 0.4 / Math.max(1, textRows) / 1.3))
    columns: textColumns + 36
    rows: Math.floor((lock.height - bottom.height) / Math.max(1, cellHeight))
    effectOptions: ({
      matrix: ["--rain-time", "2", "--resolve-delay", "1",
               "--highlight-color", Ttfx.hex(Color.lock.text),
               "--rain-color-gradient", Ttfx.hex(Color.muted), Ttfx.hex(Color.lock.borderActive),
               "--final-gradient-stops", Ttfx.hex(Color.lock.borderActive), Ttfx.hex(Color.lock.text)],
      errorcorrect: ["--error-pairs", "0.05", "--error-color", Ttfx.hex(Color.lock.textError), "--correct-color", Ttfx.hex(Color.lock.borderActive),
                     "--final-gradient-stops", Ttfx.hex(Color.lock.borderActive), Ttfx.hex(Color.lock.text)]
    })
  }

  Column {
    id: bottom
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom

    Rectangle {
      width: parent.width
      height: Math.round(lock.fs * 1.9)
      color: lock.barColor

      Row {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height

        Rectangle {
          height: parent.height
          width: mode.implicitWidth + lock.fs * 1.6
          color: lock.modeColor
          Behavior on color { ColorAnimation { duration: 150 } }
          Mono {
            id: mode
            anchors.centerIn: parent
            text: lock.errorState ? "DENIED" : lock.authenticatingPassword ? "CHECKING" : lock.fido2Active ? "KEY" : "LOCKED"
            color: Color.background
            font.weight: Font.Bold
          }
        }
        Mono { height: parent.height; text: "  omarchy  "; color: lock.withAlpha(Color.lock.text, 0.6) }
        Mono { height: parent.height; text: "[+]"; color: lock.withAlpha(Color.lock.text, 0.35); visible: lock.passwordText.length > 0 }
      }

      Row {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height
        Mono { height: parent.height; text: lock.clock("ddd d MMM").toLowerCase() + "  "; color: lock.withAlpha(Color.lock.text, 0.6) }
        Rectangle {
          height: parent.height
          width: clock.implicitWidth + lock.fs * 1.6
          color: lock.modeColor
          Behavior on color { ColorAnimation { duration: 150 } }
          Mono { id: clock; anchors.centerIn: parent; text: lock.clock("HH:mm"); color: Color.background; font.weight: Font.Bold }
        }
      }
    }

    Item {
      width: parent.width
      height: Math.round(lock.fs * 2)

      Row {
        anchors.left: parent.left
        anchors.leftMargin: Math.round(lock.fs * 0.6)
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0
        visible: !lock.errorState && !lock.authenticatingPassword && !lock.fido2Active
        Mono { text: ":unlock " }
        Mono { text: Ttfx.masked(lock, "•", 40) }
        Rectangle {
          id: cursor
          anchors.verticalCenter: parent.verticalCenter
          width: Math.round(lock.fs * 0.6)
          height: Math.round(lock.fs * 1.2)
          color: Color.lock.text
          SequentialAnimation on opacity {
            loops: Animation.Infinite
            running: lock.visible
            NumberAnimation { from: 1; to: 1; duration: 530 }
            NumberAnimation { from: 1; to: 0; duration: 1 }
            NumberAnimation { from: 0; to: 0; duration: 530 }
            NumberAnimation { from: 0; to: 1; duration: 1 }
          }
        }
      }

      Mono {
        anchors.left: parent.left
        anchors.leftMargin: Math.round(lock.fs * 0.6)
        anchors.verticalCenter: parent.verticalCenter
        visible: lock.errorState || lock.authenticatingPassword || lock.fido2Active
        text: lock.errorState ? "E492: " + lock.failureMessage : "-- " + Ttfx.inputStatus(lock, "").toUpperCase() + " --"
        color: lock.errorState ? Color.lock.textError : Color.lock.text
        font.weight: lock.errorState ? Font.Normal : Font.Bold
      }

      EyeButton {
        lock: lock
        anchors.right: parent.right
        anchors.rightMargin: Math.round(lock.fs * 0.4)
        anchors.verticalCenter: parent.verticalCenter
        size: lock.fs
      }
    }
  }

  Connections {
    target: lock
    function onFailureMessageChanged() {
      if (lock.failureMessage.length > 0) art.play("errorcorrect", 150)
    }
  }
}
