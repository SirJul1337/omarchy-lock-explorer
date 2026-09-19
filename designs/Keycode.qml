import QtQuick
import qs.Commons
import "Ttfx.js" as Ttfx

// A grid draws and dissolves into the Omarchy logo; under it the password is
// a row of square cells that fill as you type. A wrong password turns the
// cells red, shakes them and blows the logo apart.
DesignBase {
  id: lock
  inputItem: input
  flashOnFail: false

  readonly property int cell: Math.max(22, Math.round(height / 28))
  readonly property int typed: passwordText.length
  readonly property int slots: Math.min(24, Math.max(8, typed + 1))

  Rectangle { anchors.fill: parent; color: lock.deepen(Color.background, 2.1) }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: { lock.wakeRequested(); lock.forcePasswordFocus() }
    onPositionChanged: lock.wakeRequested()
  }

  OmarchyLogo { id: logoSource }

  LockInput { id: input; lock: lock; width: 1; height: 1; opacity: 0 }

  Column {
    anchors.centerIn: parent
    spacing: Math.round(lock.height * 0.045)

    TtfxText {
      id: art
      anchors.horizontalCenter: parent.horizontalCenter
      text: logoSource.text
      effect: "synthgrid"
      replayEffect: "synthgrid"
      columns: textColumns + 14
      rows: textRows + 6
      pixelSize: Math.max(8, Math.round(lock.height * 0.36 / Math.max(1, textRows) / 1.3))
      effectOptions: ({
        synthgrid: ["--grid-gradient-stops", Ttfx.hex(Color.lock.borderActive), Ttfx.hex(Color.muted),
                    "--text-gradient-stops", Ttfx.hex(Color.lock.borderActive), Ttfx.hex(Color.lock.text),
                    "--max-active-blocks", "0.2"],
        unstable: ["--unstable-color", Ttfx.hex(Color.lock.textError),
                   "--final-gradient-stops", Ttfx.hex(Color.lock.borderActive), Ttfx.hex(Color.lock.text)]
      })
    }

    Item {
      id: cells
      anchors.horizontalCenter: parent.horizontalCenter
      width: row.width
      height: lock.cell

      transform: Translate { id: shift }
      SequentialAnimation {
        id: shake
        NumberAnimation { target: shift; property: "x"; to: -12; duration: 40 }
        NumberAnimation { target: shift; property: "x"; to: 10; duration: 70 }
        NumberAnimation { target: shift; property: "x"; to: -6; duration: 60 }
        NumberAnimation { target: shift; property: "x"; to: 0; duration: 50 }
      }

      Row {
        id: row
        spacing: Math.round(lock.cell * 0.3)

        Repeater {
          model: lock.slots
          Rectangle {
            id: slot
            required property int index
            readonly property bool filled: index < lock.typed
            readonly property bool current: index === lock.typed && lock.inputEnabled && !lock.authenticatingPassword
            width: lock.cell
            height: lock.cell
            radius: Math.round(lock.cell * 0.14)
            color: filled ? Color.lock.borderActive : "transparent"
            border.width: filled ? 0 : 1
            border.color: lock.errorState ? Color.lock.textError
              : current ? Color.lock.text : lock.withAlpha(Color.lock.text, 0.22)
            scale: filled ? 1 : 0.86
            Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }
            Behavior on color { ColorAnimation { duration: 120 } }

            Text {
              anchors.centerIn: parent
              visible: slot.filled && lock.passwordVisible && !lock.fido2Active
              text: lock.passwordText.charAt(slot.index)
              color: Color.background
              font.family: Style.font.family
              font.pixelSize: Math.round(lock.cell * 0.55)
              font.weight: Font.Bold
            }

            SequentialAnimation on opacity {
              loops: Animation.Infinite
              running: slot.current
              onRunningChanged: if (!running) slot.opacity = 1
              NumberAnimation { from: 1; to: 0.35; duration: 500 }
              NumberAnimation { from: 0.35; to: 1; duration: 500 }
            }
          }
        }
      }

      // Checking: the whole row breathes.
      SequentialAnimation on opacity {
        loops: Animation.Infinite
        running: lock.authenticatingPassword
        onRunningChanged: if (!running) cells.opacity = 1
        NumberAnimation { from: 1; to: 0.4; duration: 350 }
        NumberAnimation { from: 0.4; to: 1; duration: 350 }
      }

      EyeButton {
        lock: lock
        anchors.left: row.right
        anchors.leftMargin: Math.round(lock.cell * 0.5)
        anchors.verticalCenter: row.verticalCenter
      }
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: Ttfx.inputStatus(lock, lock.clock("dddd d MMMM").toLowerCase())
      color: lock.errorState ? Color.lock.textError : lock.withAlpha(Color.lock.text, 0.45)
      font.family: Style.font.family
      font.pixelSize: Style.font.heading
      font.letterSpacing: 2
      textFormat: Text.PlainText
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
