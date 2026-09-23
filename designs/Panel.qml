import QtQuick
import qs.Commons
import "Ttfx.js" as Ttfx

// Half the screen in the theme accent with the Omarchy logo poured into it in
// the background color, like a cut-out; the other half a square field drawn
// in the logo's strokes, typing in blocks. A wrong password blows the cut-out
// apart.
DesignBase {
  id: lock
  inputItem: field
  flashOnFail: false

  // Stroke and block sizes follow the logo's cells so the field matches it.
  readonly property int stroke: Math.max(4, Math.round(art.cellWidth * 0.9))
  readonly property int block: Math.max(12, Math.round(height / 54))
  readonly property string bgHex: Ttfx.hex(Color.background)

  Rectangle { anchors.fill: parent; color: Color.background }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: { lock.wakeRequested(); lock.forcePasswordFocus() }
    onPositionChanged: lock.wakeRequested()
  }

  OmarchyLogo { id: logoSource }

  Rectangle {
    id: panel
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: Math.round(lock.width * 0.46)
    color: Color.lock.borderActive

    TtfxText {
      id: art
      anchors.centerIn: parent
      text: logoSource.text
      effect: "pour"
      replayEffect: "pour"
      margin: 4
      pixelSize: Math.max(8, Math.round(lock.height * 0.44 / Math.max(1, textRows) / 1.3))
      textColor: Color.background
      backgroundColor: Color.lock.borderActive
      effectOptions: ({
        pour: ["--pour-direction", "down", "--movement-speed-range", "0.6-1.0",
               "--starting-color", Ttfx.hex(Qt.lighter(Color.lock.borderActive, 1.35)),
               "--final-gradient-stops", lock.bgHex, lock.bgHex],
        unstable: ["--unstable-color", Ttfx.hex(Color.lock.textError), "--final-gradient-stops", lock.bgHex, lock.bgHex]
      })
    }
  }

  LockInput { id: field; lock: lock; width: 1; height: 1; opacity: 0 }

  // The other side stays quiet: a status line, a square field drawn with the
  // logo's thick strokes where every typed character is a block, and a hint.
  Item {
    anchors.left: panel.right
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.bottom: parent.bottom

    Column {
      anchors.centerIn: parent
      spacing: Math.round(lock.height * 0.022)

      Row {
        spacing: Math.round(lock.stroke * 1.5)
        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          width: lock.stroke * 2
          height: width
          color: lock.errorState ? Color.lock.textError : Color.lock.borderActive
        }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          readonly property string status: Ttfx.inputStatus(lock, "")
          text: (status.length > 0 ? status : "locked · " + lock.clock("HH:mm · ddd d MMM")).toLowerCase()
          color: lock.errorState ? Color.lock.textError : lock.withAlpha(Color.lock.text, 0.55)
          font.family: Style.font.family
          font.pixelSize: Style.font.title
          font.letterSpacing: 1
          textFormat: Text.PlainText
        }
      }

      Rectangle {
        id: box
        width: Math.round(lock.width * 0.3)
        height: lock.block * 2 + lock.stroke * 2
        color: "transparent"
        border.width: lock.stroke
        border.color: lock.errorState ? Color.lock.textError : Color.lock.borderActive
        Behavior on border.color { ColorAnimation { duration: 150 } }

        readonly property int fits: Math.max(1, Math.floor((width - lock.block * 2 - eye.width) / (lock.block * 1.5)) - 1)

        Row {
          id: blocks
          anchors.left: parent.left
          anchors.leftMargin: lock.block
          anchors.verticalCenter: parent.verticalCenter
          spacing: Math.round(lock.block * 0.5)
          visible: !lock.passwordVisible || lock.fido2Active

          Repeater {
            model: Math.min(lock.passwordText.length, box.fits)
            Rectangle {
              width: lock.block
              height: lock.block
              color: Color.lock.text
              scale: 0.4
              Component.onCompleted: scale = 1
              Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }
            }
          }

          // Cursor: an open square where the next block goes.
          Rectangle {
            id: cursor
            width: lock.block
            height: lock.block
            color: "transparent"
            border.width: Math.max(2, Math.round(lock.stroke / 2))
            border.color: Color.lock.borderActive
            visible: lock.inputEnabled && !lock.authenticatingPassword
            SequentialAnimation on opacity {
              loops: Animation.Infinite
              running: cursor.visible
              NumberAnimation { from: 1; to: 1; duration: 530 }
              NumberAnimation { from: 1; to: 0; duration: 1 }
              NumberAnimation { from: 0; to: 0; duration: 530 }
              NumberAnimation { from: 0; to: 1; duration: 1 }
            }
          }
        }

        Text {
          anchors.left: parent.left
          anchors.leftMargin: lock.block
          anchors.right: eye.left
          anchors.verticalCenter: parent.verticalCenter
          visible: lock.passwordVisible && !lock.fido2Active
          text: lock.passwordText
          color: Color.lock.text
          elide: Text.ElideLeft
          font.family: Style.font.family
          font.pixelSize: Math.round(lock.block * 1.4)
          textFormat: Text.PlainText
        }

        Text {
          anchors.left: parent.left
          anchors.leftMargin: lock.block * 2.6
          anchors.verticalCenter: parent.verticalCenter
          visible: lock.passwordText.length === 0 && !lock.authenticatingPassword
          text: lock.fido2Active ? "touch your key" : "password"
          color: lock.withAlpha(Color.lock.text, 0.3)
          font.family: Style.font.family
          font.pixelSize: Math.round(lock.block * 1.1)
        }

        EyeButton {
          id: eye
          lock: lock
          anchors.right: parent.right
          anchors.rightMargin: lock.block * 0.6
          anchors.verticalCenter: parent.verticalCenter
        }

        transform: Translate { id: nudge }
        SequentialAnimation {
          id: shake
          NumberAnimation { target: nudge; property: "x"; to: -10; duration: 40 }
          NumberAnimation { target: nudge; property: "x"; to: 8; duration: 70 }
          NumberAnimation { target: nudge; property: "x"; to: 0; duration: 60 }
        }
      }

      Text {
        text: lock.fingerprintHint("enter to unlock"
          + (lock.fingerprintConfigured ? " · or touch the reader" : "")
          + (lock.fido2Configured ? " · tab for your key" : "")).toLowerCase()
        textFormat: Text.PlainText
        color: lock.withAlpha(Color.lock.text, 0.28)
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        font.letterSpacing: 1
      }
    }
  }

  Connections {
    target: lock
    function onFailureMessageChanged() {
      if (lock.failureMessage.length === 0) return
      shake.restart()
      art.play("unstable")
    }
  }
}
