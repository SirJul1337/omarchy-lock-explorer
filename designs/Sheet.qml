import QtQuick
import QtQuick.Effects
import qs.Commons

DesignBase {
  id: lock
  inputItem: field.input

  readonly property int sheetHeight: Math.round(height * 0.36)

  Wallpaper { anchors.fill: parent; lock: lock; blur: 0.0; dim: 0.05; vignetteTop: 0.35; vignetteMiddle: 0.05; vignetteBottom: 0.1 }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: { lock.wakeRequested(); lock.forcePasswordFocus() }
    onPositionChanged: lock.wakeRequested()
  }

  Column {
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.margins: 64
    spacing: 2
    Text {
      text: Qt.formatTime(lock.now, "HH:mm")
      color: Color.lock.text
      font.family: Style.font.family
      font.pixelSize: Math.round(Style.font.baseSize * 8)
      font.weight: Font.DemiBold
      font.letterSpacing: -2
      layer.enabled: true
      layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Qt.rgba(0, 0, 0, 0.6); shadowBlur: 1.0; shadowVerticalOffset: 2 }
    }
    Text {
      text: Qt.formatDate(lock.now, "dddd, d MMMM")
      color: lock.withAlpha(Color.lock.text, 0.85)
      font.family: Style.font.family
      font.pixelSize: Style.font.display
      layer.enabled: true
      layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Qt.rgba(0, 0, 0, 0.6); shadowBlur: 1.0; shadowVerticalOffset: 1 }
    }
  }

  Rectangle {
    id: sheet
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.bottomMargin: -32
    height: lock.sheetHeight + 32
    radius: 32
    color: lock.withAlpha(Color.lock.background, 0.94)

    Rectangle {
      anchors.top: parent.top
      anchors.topMargin: 12
      anchors.horizontalCenter: parent.horizontalCenter
      width: 44; height: 5; radius: 3
      color: lock.withAlpha(Color.lock.text, 0.25)
    }

    Column {
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.top
      anchors.topMargin: 44
      spacing: 18

      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 14
        Rectangle {
          width: 48; height: 48; radius: 24
          anchors.verticalCenter: parent.verticalCenter
          color: Color.lock.borderActive
          Text {
            anchors.centerIn: parent
            text: lock.userInitial
            color: Color.background
            font.family: Style.font.family
            font.pixelSize: Style.font.display
            font.weight: Font.Bold
          }
        }
        Column {
          anchors.verticalCenter: parent.verticalCenter
          spacing: 2
          Text {
            text: lock.greeting() + ", " + lock.userName
            color: Color.lock.text
            font.family: Style.font.family
            font.pixelSize: Style.font.display
            font.weight: Font.DemiBold
          }
          Text {
            text: lock.errorState ? lock.failureMessage : (lock.authenticatingPassword ? "Checking…" : "Enter your password to unlock")
            color: lock.errorState ? Color.lock.textError : lock.withAlpha(Color.lock.text, 0.6)
            font.family: Style.font.family
            font.pixelSize: Style.font.subtitle
          }
        }
      }

      PasswordField {
        id: field
        lock: lock
        anchors.horizontalCenter: parent.horizontalCenter
        width: 440
        height: 56
        placeholder: "Password"
        color: lock.withAlpha(Color.background, 0.6)
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: lock.fingerprintConfigured ? "󰆠  Touch sensor or press Enter" : "Press Enter to unlock  ·  Esc clears"
        color: lock.withAlpha(Color.lock.text, 0.45)
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        font.letterSpacing: 1
      }
    }
  }
}
