import QtQuick
import QtQuick.Effects
import qs.Commons

DesignBase {
  id: lock
  inputItem: field.input

  readonly property int fieldWidth: 400

  Wallpaper { anchors.fill: parent; lock: lock; blur: 0.85; dim: 0.08 }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: { lock.wakeRequested(); lock.forcePasswordFocus() }
    onPositionChanged: lock.wakeRequested()
  }

  Column {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: card.top
    anchors.bottomMargin: 48
    spacing: 4

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: Qt.formatTime(lock.now, "HH:mm")
      color: Color.lock.text
      font.family: Style.font.family
      font.pixelSize: Math.round(Style.font.baseSize * 9)
      font.weight: Font.DemiBold
      font.letterSpacing: -2
      layer.enabled: true
      layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Qt.rgba(0, 0, 0, 0.55); shadowBlur: 0.8; shadowVerticalOffset: 2 }
    }
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: Qt.formatDate(lock.now, "dddd, d MMMM")
      color: lock.withAlpha(Color.lock.text, 0.85)
      font.family: Style.font.family
      font.pixelSize: Style.font.display
      font.letterSpacing: 1
      layer.enabled: true
      layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Qt.rgba(0, 0, 0, 0.55); shadowBlur: 0.8; shadowVerticalOffset: 1 }
    }
  }

  Rectangle {
    id: card
    width: lock.fieldWidth + 64
    height: content.implicitHeight + 56
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
    anchors.verticalCenterOffset: Math.round(parent.height * 0.12)
    radius: Math.max(Style.cornerRadius, 12) + 8
    color: lock.withAlpha(Color.lock.background, 0.55)
    border.width: 1
    border.color: lock.withAlpha(Color.lock.text, 0.12)
    layer.enabled: true
    layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Qt.rgba(0, 0, 0, 0.5); shadowBlur: 1.0; shadowVerticalOffset: 12 }

    Column {
      id: content
      anchors.centerIn: parent
      width: lock.fieldWidth
      spacing: 16

      Avatar {
        anchors.horizontalCenter: parent.horizontalCenter
        lock: lock
        width: 72
        fontSize: Math.round(Style.font.baseSize * 2.6)
        borderWidth: 3
        borderColor: lock.withAlpha(Color.lock.text, 0.25)
        shadow: false
      }

      Column {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 2
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: lock.greeting() + ", " + lock.userName
          color: Color.lock.text
          font.family: Style.font.family
          font.pixelSize: Style.font.display
          font.weight: Font.DemiBold
        }
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: lock.failedAttempts > 0
            ? (lock.failedAttempts + (lock.failedAttempts === 1 ? " failed attempt" : " failed attempts"))
            : "Enter your password to unlock"
          color: lock.failedAttempts > 0 ? Color.lock.textError : Color.lock.placeholder
          font.family: Style.font.family
          font.pixelSize: Style.font.subtitle
        }
      }

      PasswordField {
        id: field
        lock: lock
        width: lock.fieldWidth
        height: 60
      }
    }
  }

  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 36
    text: lock.fingerprintConfigured ? "󰆠  Touch sensor or type password  ·  Esc clears" : "󰌾  Locked  ·  Esc clears input"
    color: lock.withAlpha(Color.lock.text, 0.55)
    font.family: Style.font.family
    font.pixelSize: Style.font.bodySmall
    font.letterSpacing: 1
  }
}
