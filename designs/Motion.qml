import QtQuick
import QtQuick.Effects
import qs.Commons

// Full bleed looping video with the clock over it. Without a video set it is
// the wallpaper instead, so the design still stands on its own.
DesignBase {
  id: lock
  inputItem: field.input

  readonly property int margin: Math.round(Math.min(width, height) * 0.08)

  VideoWallpaper {
    anchors.fill: parent
    lock: lock
    playing: lock.videoPlaying
    dim: 0.2
    vignetteTop: 0.45
    vignetteMiddle: 0.05
    vignetteBottom: 0.6
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: { lock.wakeRequested(); lock.forcePasswordFocus() }
    onPositionChanged: lock.wakeRequested()
  }

  Text {
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.margins: lock.margin
    text: lock.greeting() + ", " + lock.userName
    color: lock.withAlpha(Color.lock.text, 0.8)
    font.family: Style.font.family
    font.pixelSize: Style.font.subtitle
    font.letterSpacing: 3
  }

  Column {
    anchors.centerIn: parent
    spacing: 24

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: Qt.formatTime(lock.now, "HH:mm")
      color: Color.lock.text
      font.family: Style.font.family
      font.pixelSize: Math.round(Style.font.baseSize * 11)
      font.weight: Font.Light
      font.letterSpacing: -4
      layer.enabled: true
      layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Qt.rgba(0, 0, 0, 0.7); shadowBlur: 1.0; shadowVerticalOffset: 4 }
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: Qt.formatDate(lock.now, "dddd d MMMM").toUpperCase()
      color: lock.withAlpha(Color.lock.text, 0.75)
      font.family: Style.font.family
      font.pixelSize: Style.font.heading
      font.letterSpacing: 6
    }
  }

  Column {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: lock.margin
    spacing: 14

    PasswordField {
      id: field
      lock: lock
      anchors.horizontalCenter: parent.horizontalCenter
      width: 420
      height: 58
      radius: height / 2
      showLockGlyph: false
      placeholder: "Password"
      color: lock.withAlpha(Color.lock.background, 0.55)
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: lock.failedAttempts > 0
        ? lock.failedAttempts + " failed " + (lock.failedAttempts === 1 ? "attempt" : "attempts")
        : (lock.hasVideo ? "" : "No video yet  ·  omarchy-shell lock pickVideo")
      color: lock.failedAttempts > 0 ? Color.lock.textError : lock.withAlpha(Color.lock.text, 0.55)
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      font.letterSpacing: 1
    }
  }
}
