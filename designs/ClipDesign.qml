import QtQuick
import Quickshell
import qs.Commons

// A design built around one clip: its first frame is the lock screen and the
// rest of it is the unlock. Storm, Eyes, Rally and River are this with
// different files from ~/.config/omarchy/lock-videos.
DesignBase {
  id: lock
  inputItem: field.input
  shakeOnFail: true

  property string clipName: ""
  readonly property string clipPath: clipName.length > 0
    ? Quickshell.env("HOME") + "/.config/omarchy/lock-videos/" + clipName : ""

  // What shows if the file is missing.
  Wallpaper { anchors.fill: parent; lock: lock; blur: 0.8; dim: 0.25 }

  UnlockClip {
    id: still
    anchors.fill: parent
    lock: lock
    clip: lock.clipPath
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: { lock.wakeRequested(); lock.forcePasswordFocus() }
    onPositionChanged: lock.wakeRequested()
  }

  // Everything over the picture steps aside while the clip plays.
  Item {
    id: chrome
    anchors.fill: parent
    opacity: lock.unlockPlayback ? 0 : 1
    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

    // Just enough scrim for the text, the picture stays the point.
    Rectangle {
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      height: parent.height * 0.25
      gradient: Gradient {
        GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.45) }
        GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0) }
      }
    }
    Rectangle {
      anchors.bottom: parent.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      height: parent.height * 0.3
      gradient: Gradient {
        GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0) }
        GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.5) }
      }
    }

    Column {
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.top
      anchors.topMargin: Math.round(lock.height * 0.07)
      spacing: 4

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.formatTime(lock.now, "HH:mm")
        color: Color.lock.text
        font.family: Style.font.family
        font.pixelSize: Math.round(Style.font.baseSize * 5)
        font.weight: Font.Light
        font.letterSpacing: 3
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.formatDate(lock.now, "dddd d MMMM").toUpperCase()
        color: lock.withAlpha(Color.lock.text, 0.7)
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        font.letterSpacing: 4
      }
    }

    Column {
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: Math.round(lock.height * 0.07)
      spacing: 10

      PasswordField {
        id: field
        lock: lock
        anchors.horizontalCenter: parent.horizontalCenter
        width: 400
        height: 56
        radius: height / 2
        showLockGlyph: false
        shakeOnFail: false
        placeholder: "Password"
        color: lock.withAlpha(Color.lock.background, 0.55)
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        visible: lock.clipName.length > 0 && !still.ready
        text: "Missing " + lock.clipName + " in ~/.config/omarchy/lock-videos"
        color: lock.withAlpha(Color.lock.text, 0.55)
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        font.letterSpacing: 1
      }
    }
  }
}
