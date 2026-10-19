import QtQuick
import QtQuick.Effects
import qs.Commons
import qs.Commons as Commons

// A boarding pass: the stub carries you, the pass carries the time, and the
// gate is the password.
DesignBase {
  id: lock
  inputItem: field.input
  chromeRadius: 4

  Wallpaper { anchors.fill: parent; lock: lock; blur: 0.7; dim: 0.3; vignetteTop: 0.35; vignetteMiddle: 0.1; vignetteBottom: 0.4 }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: { lock.wakeRequested(); lock.forcePasswordFocus() }
    onPositionChanged: lock.wakeRequested()
  }

  component Label: Text {
    property string caption: ""
    text: caption.toUpperCase()
    textFormat: Text.PlainText
    color: lock.withAlpha(Commons.Color.lock.text, 0.5)
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
    font.letterSpacing: 3
  }

  Row {
    id: pass
    anchors.centerIn: parent
    anchors.verticalCenterOffset: -Math.round(parent.height * 0.03)
    spacing: 0
    layer.enabled: true
    layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Qt.rgba(0, 0, 0, 0.55); shadowBlur: 1.0; shadowVerticalOffset: 10 }

    // The stub.
    Rectangle {
      width: 260
      height: 300
      radius: 6
      color: lock.withAlpha(Commons.Color.lock.background, 0.9)
      border.width: 1
      border.color: lock.withAlpha(Commons.Color.lock.text, 0.14)

      Column {
        anchors.left: parent.left
        anchors.leftMargin: 28
        anchors.verticalCenter: parent.verticalCenter
        spacing: 18
        Avatar { lock: lock; width: 64; fontSize: Style.font.heading; shadow: false }
        Column {
          spacing: 4
          Label { caption: "Passenger" }
          Text {
            text: lock.displayName
            textFormat: Text.PlainText
            color: Commons.Color.lock.text
            font.family: Style.font.family
            font.pixelSize: Style.font.heading
            font.weight: Font.DemiBold
          }
        }
        Column {
          spacing: 4
          Label { caption: "From" }
          Text {
            text: lock.hostName
            textFormat: Text.PlainText
            color: lock.withAlpha(Commons.Color.lock.text, 0.8)
            font.family: Style.font.family
            font.pixelSize: Style.font.body
          }
        }
      }
    }

    // The perforation: a dark column with a row of punched holes.
    Item {
      width: 22
      height: 300
      Rectangle { anchors.fill: parent; color: lock.withAlpha(Commons.Color.lock.background, 0.9) }
      Rectangle { anchors.fill: parent; anchors.topMargin: 6; anchors.bottomMargin: 6; color: "transparent"
        Column {
          anchors.centerIn: parent
          spacing: 10
          Repeater {
            model: 18
            Rectangle { width: 6; height: 6; radius: 3; color: lock.withAlpha(Commons.Color.lock.text, 0.22); anchors.horizontalCenter: parent.horizontalCenter }
          }
        }
      }
    }

    // The pass.
    Rectangle {
      width: 640
      height: 300
      radius: 6
      color: lock.withAlpha(Commons.Color.lock.background, 0.9)
      border.width: 1
      border.color: lock.withAlpha(Commons.Color.lock.text, 0.14)

      Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 6
        radius: 3
        color: Commons.Color.accent
      }

      Column {
        anchors.left: parent.left
        anchors.leftMargin: 32
        anchors.top: parent.top
        anchors.topMargin: 34
        spacing: 2
        Label { caption: "Departure" }
        Text {
          text: lock.clock("HH:mm")
          color: Commons.Color.lock.text
          font.family: Style.font.family
          font.pixelSize: Math.round(Style.font.baseSize * 4.6)
          font.weight: Font.Bold
          font.letterSpacing: -2
        }
      }

      Column {
        anchors.right: parent.right
        anchors.rightMargin: 32
        anchors.top: parent.top
        anchors.topMargin: 38
        spacing: 2
        Label { caption: "Date"; anchors.right: parent.right }
        Text {
          anchors.right: parent.right
          text: lock.date("ddd d MMM")
          color: Commons.Color.lock.text
          font.family: Style.font.family
          font.pixelSize: Style.font.heading
        }
      }

      Column {
        anchors.left: parent.left
        anchors.leftMargin: 32
        anchors.right: parent.right
        anchors.rightMargin: 32
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 30
        spacing: 8
        Label { caption: lock.errorState ? "Gate closed" : (lock.authenticatingPassword ? "Boarding" : "Gate") }
        PasswordField {
          id: field
          lock: lock
          width: parent.width
          height: 48
          radius: 4
          outlineThickness: 1
          showLockGlyph: false
          shakeOnFail: true
          textAlignment: TextInput.AlignLeft
          placeholder: lock.tr("Type your password")
          color: lock.withAlpha(Commons.Color.lock.text, 0.06)
        }
      }
    }
  }

  Text {
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 32
    anchors.horizontalCenter: parent.horizontalCenter
    opacity: lock.snapshotMode ? 0 : 1
    text: lock.errorState ? lock.failureMessage
      : (lock.fingerprintConfigured ? lock.fingerprintHint(lock.tr("Touch sensor or type password")) : lock.tr("Press Enter to unlock"))
    textFormat: Text.PlainText
    color: lock.errorState ? Commons.Color.lock.textError : lock.withAlpha(Commons.Color.lock.text, 0.5)
    font.family: Style.font.family
    font.pixelSize: Style.font.bodySmall
    font.letterSpacing: 2
  }
}
