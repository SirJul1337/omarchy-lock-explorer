import QtQuick
import QtQuick.Effects
import qs.Commons

DesignBase {
  id: lock
  inputItem: field.input

  Wallpaper { anchors.fill: parent; lock: lock; blur: 0.0; dim: 0.1; vignetteTop: 0.4; vignetteMiddle: 0.05; vignetteBottom: 0.25 }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: { lock.wakeRequested(); lock.forcePasswordFocus() }
    onPositionChanged: lock.wakeRequested()
  }

  Rectangle {
    id: island
    anchors.top: parent.top
    anchors.topMargin: 28
    anchors.horizontalCenter: parent.horizontalCenter
    width: row.implicitWidth + 32
    height: 64
    radius: 32
    color: lock.withAlpha(Color.lock.background, 0.92)
    border.width: 1
    border.color: lock.withAlpha(Color.lock.text, 0.14)
    layer.enabled: true
    layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Qt.rgba(0, 0, 0, 0.5); shadowBlur: 1.0; shadowVerticalOffset: 8 }

    Row {
      id: row
      anchors.centerIn: parent
      spacing: 14

      Avatar {
        lock: lock
        width: 40
        fontSize: Style.font.heading
        anchors.verticalCenter: parent.verticalCenter
        shadow: false
      }

      PasswordField {
        id: field
        lock: lock
        anchors.verticalCenter: parent.verticalCenter
        width: 300
        height: 40
        radius: 20
        outlineThickness: 1
        showLockGlyph: false
        shakeOnFail: false
        textAlignment: TextInput.AlignLeft
        placeholder: lock.greeting() + ", " + lock.userName
        color: lock.withAlpha(Color.background, 0.5)
      }

      Rectangle { width: 1; height: 28; anchors.verticalCenter: parent.verticalCenter; color: lock.withAlpha(Color.lock.text, 0.2) }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: Qt.formatTime(lock.now, "HH:mm")
        color: Color.lock.text
        font.family: Style.font.family
        font.pixelSize: Style.font.display
        font.weight: Font.DemiBold
      }
    }
  }

  Text {
    anchors.top: island.bottom
    anchors.topMargin: 12
    anchors.horizontalCenter: parent.horizontalCenter
    text: lock.errorState ? lock.failureMessage
      : (lock.authenticatingPassword ? "Checking…" : Qt.formatDate(lock.now, "dddd d MMMM"))
    textFormat: Text.PlainText
    color: lock.errorState ? Color.lock.textError : lock.withAlpha(Color.lock.text, 0.75)
    font.family: Style.font.family
    font.pixelSize: Style.font.bodySmall
    font.letterSpacing: 2
  }

  Text {
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 32
    anchors.horizontalCenter: parent.horizontalCenter
    opacity: lock.snapshotMode ? 0 : 1
    text: lock.fingerprintConfigured ? "󰆠  Touch sensor or type password" : "󰌾  " + lock.hostName
    color: lock.withAlpha(Color.lock.text, 0.5)
    font.family: Style.font.family
    font.pixelSize: Style.font.bodySmall
    font.letterSpacing: 2
  }
}
