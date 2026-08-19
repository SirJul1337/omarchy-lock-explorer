import QtQuick
import qs.Commons

DesignBase {
  id: lock
  inputItem: field.input

  Wallpaper { anchors.fill: parent; lock: lock; blur: 1.0; dim: 0.2 }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: { lock.wakeRequested(); lock.forcePasswordFocus() }
    onPositionChanged: lock.wakeRequested()
  }

  Text {
    anchors.top: parent.top
    anchors.topMargin: 48
    anchors.horizontalCenter: parent.horizontalCenter
    text: Qt.formatTime(lock.now, "HH:mm") + "   " + Qt.formatDate(lock.now, "ddd d MMM")
    color: lock.withAlpha(Color.lock.text, 0.7)
    font.family: Style.font.family
    font.pixelSize: Style.font.title
    font.letterSpacing: 2
  }

  Column {
    anchors.centerIn: parent
    anchors.verticalCenterOffset: -20
    spacing: 22

    Item {
      anchors.horizontalCenter: parent.horizontalCenter
      width: 150; height: 150
      Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: "transparent"
        border.width: 3
        border.color: lock.errorState ? Color.lock.textError : lock.withAlpha(Color.lock.text, 0.35)
      }
      Avatar {
        anchors.centerIn: parent
        lock: lock
        width: 130
        fontSize: Math.round(Style.font.baseSize * 5)
      }
    }

    Column {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 4
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: lock.userName
        color: Color.lock.text
        font.family: Style.font.family
        font.pixelSize: Style.font.displayLarge
        font.weight: Font.DemiBold
      }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: lock.errorState ? lock.failureMessage : (lock.authenticatingPassword ? "Checking…" : lock.hostName)
        color: lock.errorState ? Color.lock.textError : lock.withAlpha(Color.lock.text, 0.55)
        font.family: Style.font.family
        font.pixelSize: Style.font.subtitle
      }
    }

    PasswordField {
      id: field
      lock: lock
      anchors.horizontalCenter: parent.horizontalCenter
      width: 340
      height: 52
      radius: 26
      showLockGlyph: false
      placeholder: "Password"
      color: lock.withAlpha(Color.lock.background, 0.6)
    }
  }

  Text {
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 36
    anchors.horizontalCenter: parent.horizontalCenter
    text: lock.fingerprintConfigured ? "󰆠  Touch sensor or press Enter" : "Press Enter to unlock"
    color: lock.withAlpha(Color.lock.text, 0.45)
    font.family: Style.font.family
    font.pixelSize: Style.font.bodySmall
    font.letterSpacing: 1
  }
}
