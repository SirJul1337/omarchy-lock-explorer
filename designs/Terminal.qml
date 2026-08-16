import QtQuick
import qs.Commons

DesignBase {
  id: lock
  inputItem: input
  shakeOnFail: true

  readonly property int fontSize: Math.round(Style.font.baseSize * 1.6)
  readonly property int pad: Math.round(Math.min(width, height) * 0.08)
  readonly property color fg: Color.lock.text
  readonly property color dimFg: withAlpha(Color.lock.text, 0.55)
  readonly property string masked: "*".repeat(passwordText.length)

  Rectangle { anchors.fill: parent; color: Color.background }

  Canvas {
    anchors.fill: parent
    opacity: 0.12
    onPaint: {
      var ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)
      ctx.fillStyle = "#000000"
      for (var y = 0; y < height; y += 3) ctx.fillRect(0, y, width, 1)
    }
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: { lock.wakeRequested(); lock.forcePasswordFocus() }
    onPositionChanged: lock.wakeRequested()
  }

  LockInput {
    id: input
    lock: lock
    width: 1; height: 1
    opacity: 0
  }

  Column {
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.margins: lock.pad
    spacing: 0

    Text {
      text: "Omarchy Linux (" + lock.hostName + ") (tty1)"
      color: lock.fg; font.family: Style.font.family; font.pixelSize: lock.fontSize
    }
    Text { text: " "; font.pixelSize: lock.fontSize }
    Text {
      text: lock.hostName + " login: " + lock.userName
      color: lock.fg; font.family: Style.font.family; font.pixelSize: lock.fontSize
    }

    Row {
      spacing: 0
      Text {
        text: "Password: "
        color: lock.fg; font.family: Style.font.family; font.pixelSize: lock.fontSize
      }
      Text {
        text: lock.masked
        color: lock.fg; font.family: Style.font.family; font.pixelSize: lock.fontSize
      }
      Rectangle {
        id: cursor
        width: Math.round(lock.fontSize * 0.6); height: lock.fontSize
        anchors.verticalCenter: parent.verticalCenter
        color: lock.fg
        visible: lock.inputEnabled && !lock.authenticatingPassword
        SequentialAnimation on opacity {
          loops: Animation.Infinite
          running: cursor.visible
          NumberAnimation { from: 1; to: 0; duration: 400 }
          PauseAnimation { duration: 150 }
          NumberAnimation { from: 0; to: 1; duration: 400 }
          PauseAnimation { duration: 150 }
        }
      }
    }

    Text {
      visible: lock.authenticatingPassword
      text: "Checking credentials..."
      color: lock.dimFg; font.family: Style.font.family; font.pixelSize: lock.fontSize
    }
    Text {
      visible: lock.errorState
      text: "Login incorrect" + (lock.failedAttempts > 1 ? " (" + lock.failedAttempts + ")" : "")
      color: Color.lock.textError; font.family: Style.font.family; font.pixelSize: lock.fontSize
    }
    Text {
      visible: lock.fingerprintConfigured
      text: "(fingerprint reader ready, touch to authenticate)"
      color: lock.dimFg; font.family: Style.font.family; font.pixelSize: lock.fontSize
    }
  }

  Text {
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.margins: lock.pad
    text: Qt.formatDateTime(lock.now, "ddd MMM d HH:mm:ss yyyy") + "   ·   Esc clears   ·   Ctrl-U clears"
    color: lock.dimFg
    font.family: Style.font.family
    font.pixelSize: Style.font.body
  }
}
