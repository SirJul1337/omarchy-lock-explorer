import QtQuick
import QtQuick.Effects
import qs.Commons

DesignBase {
  id: lock
  inputItem: field.input

  readonly property int margin: Math.round(Math.min(width, height) * 0.09)
  readonly property int fieldWidth: 380

  Wallpaper { anchors.fill: parent; lock: lock; blur: 0.35; dim: 0.12; vignetteTop: 0.15; vignetteMiddle: 0.15; vignetteBottom: 0.65 }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: { lock.wakeRequested(); lock.forcePasswordFocus() }
    onPositionChanged: lock.wakeRequested()
  }

  Row {
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.margins: lock.margin
    spacing: 12
    Rectangle { width: 10; height: 10; radius: 5; color: Color.lock.borderActive; anchors.verticalCenter: parent.verticalCenter }
    Text {
      text: lock.hostName.toUpperCase() + "  ·  " + lock.userName
      color: lock.withAlpha(Color.lock.text, 0.75)
      font.family: Style.font.family
      font.pixelSize: Style.font.subtitle
      font.letterSpacing: 3
    }
  }

  Text {
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: lock.margin
    opacity: lock.snapshotMode ? 0 : 1
    text: lock.fingerprintConfigured ? "󰆠  FINGERPRINT READY" : "󰌾  LOCKED"
    color: lock.withAlpha(Color.lock.text, 0.75)
    font.family: Style.font.family
    font.pixelSize: Style.font.subtitle
    font.letterSpacing: 3
  }

  Column {
    id: block
    anchors.left: parent.left
    anchors.bottom: parent.bottom
    anchors.leftMargin: lock.margin
    anchors.bottomMargin: lock.margin
    spacing: 18

    Text {
      text: Qt.formatTime(lock.now, "HH:mm")
      color: Color.lock.text
      font.family: Style.font.family
      font.pixelSize: Math.round(Style.font.baseSize * 15)
      font.weight: Font.Bold
      font.letterSpacing: -6
      lineHeight: 0.85
      layer.enabled: true
      layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Qt.rgba(0, 0, 0, 0.6); shadowBlur: 1.0; shadowVerticalOffset: 3 }
    }

    Row {
      spacing: 14
      Rectangle { width: 4; height: dateCol.implicitHeight; color: Color.lock.borderActive; radius: 2 }
      Column {
        id: dateCol
        spacing: 2
        Text {
          text: Qt.formatDate(lock.now, "dddd")
          color: Color.lock.text
          font.family: Style.font.family
          font.pixelSize: Style.font.displayLarge
          font.weight: Font.DemiBold
        }
        Text {
          text: Qt.formatDate(lock.now, "d MMMM yyyy")
          color: lock.withAlpha(Color.lock.text, 0.75)
          font.family: Style.font.family
          font.pixelSize: Style.font.heading
          font.letterSpacing: 1
        }
      }
    }

    Item { width: 1; height: 8 }

    PasswordField {
      id: field
      lock: lock
      width: lock.fieldWidth
      height: 56
      textAlignment: TextInput.AlignLeft
      placeholder: "Password"
      color: lock.withAlpha(Color.lock.background, 0.75)
    }

    Text {
      opacity: lock.snapshotMode ? 0 : 1
      text: lock.failedAttempts > 0
        ? lock.failedAttempts + " failed " + (lock.failedAttempts === 1 ? "attempt" : "attempts")
        : "Enter to unlock  ·  Esc to clear"
      color: lock.failedAttempts > 0 ? Color.lock.textError : lock.withAlpha(Color.lock.text, 0.55)
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      font.letterSpacing: 1
    }
  }
}
