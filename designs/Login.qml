import QtQuick
import qs.Commons
import "Ttfx.js" as Ttfx

// The Omarchy logo decrypts on the left; on the right a terminal prompt takes
// the password with a block cursor. A wrong password knocks the logo's cells
// out of place until they correct themselves.
DesignBase {
  id: lock
  inputItem: input
  flashOnFail: false

  readonly property int fs: Math.max(16, Math.round(height / 40))

  Rectangle { anchors.fill: parent; color: lock.deepen(Color.background, 1.9) }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: { lock.wakeRequested(); lock.forcePasswordFocus() }
    onPositionChanged: lock.wakeRequested()
  }

  OmarchyLogo { id: logoSource }

  LockInput { id: input; lock: lock; width: 1; height: 1; opacity: 0 }

  component Line: Text {
    color: Color.lock.text
    font.family: Style.font.family
    font.pixelSize: lock.fs
    textFormat: Text.PlainText
  }

  Row {
    anchors.centerIn: parent
    spacing: Math.round(lock.width * 0.045)

    TtfxText {
      id: art
      anchors.verticalCenter: parent.verticalCenter
      text: logoSource.text
      effect: "decrypt"
      frameRate: 120
      autoPlayRate: 120
      replayEffect: "decrypt"
      margin: 2
      pixelSize: Math.max(8, Math.round(lock.height * 0.42 / Math.max(1, textRows) / 1.3))
      effectOptions: ({
        decrypt: ["--typing-speed", "40", "--ciphertext-colors", Ttfx.hex(Color.muted), Ttfx.hex(Color.lock.borderActive), Ttfx.hex(Color.lock.text),
                  "--final-gradient-stops", Ttfx.hex(Color.lock.borderActive), Ttfx.hex(Color.lock.text)],
        errorcorrect: ["--error-pairs", "0.05", "--error-color", Ttfx.hex(Color.lock.textError), "--correct-color", Ttfx.hex(Color.lock.borderActive),
                       "--final-gradient-stops", Ttfx.hex(Color.lock.borderActive), Ttfx.hex(Color.lock.text)]
      })
    }

    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      width: 1
      height: art.height * 0.7
      color: lock.withAlpha(Color.lock.text, 0.15)
    }

    Column {
      anchors.verticalCenter: parent.verticalCenter
      width: lock.fs * 24
      spacing: Math.round(lock.fs * 0.45)

      Line { text: "Omarchy"; color: Color.lock.borderActive; font.weight: Font.Bold; font.pixelSize: Math.round(lock.fs * 1.6) }
      Line { text: "session locked · " + lock.clock("ddd d MMM HH:mm").toLowerCase(); color: lock.withAlpha(Color.lock.text, 0.5) }
      Item { width: 1; height: lock.fs }

      Row {
        spacing: 0
        Line { text: "password "; color: lock.withAlpha(Color.lock.text, 0.55) }
        Line { text: "❯ "; color: lock.errorState ? Color.lock.textError : Color.lock.borderActive; font.weight: Font.Bold }
        Line { text: Ttfx.masked(lock, "•", 22) }
        Rectangle {
          id: cursor
          anchors.verticalCenter: parent.verticalCenter
          width: Math.round(lock.fs * 0.6)
          height: Math.round(lock.fs * 1.15)
          color: Color.lock.text
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
        Item { width: lock.fs; height: 1 }
        EyeButton { lock: lock; anchors.verticalCenter: parent.verticalCenter; size: lock.fs }
      }

      Line {
        readonly property string status: Ttfx.inputStatus(lock, "")
        text: status.length > 0 ? (lock.errorState ? "✗ " : "… ") + status : " "
        color: lock.errorState ? Color.lock.textError : lock.withAlpha(Color.lock.text, 0.6)
      }

      Line {
        text: lock.fingerprintHint("enter unlocks · esc clears" + (lock.fingerprintConfigured ? " · or touch the reader" : "")).toLowerCase()
          + (lock.fido2Configured ? " · tab for your key" : "")
        color: lock.withAlpha(Color.lock.text, 0.3)
        font.pixelSize: Math.round(lock.fs * 0.8)
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
