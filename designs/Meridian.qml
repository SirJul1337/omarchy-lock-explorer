import QtQuick
import QtQuick.Effects
import qs.Commons
import qs.Commons as Commons

// One vertical line down the middle. The time keeps to its left, the day to
// its right, and the field sits across it.
DesignBase {
  id: lock
  inputItem: field.input
  chromeRadius: 0

  Wallpaper { anchors.fill: parent; lock: lock; blur: 0.9; dim: 0.3; vignetteTop: 0.3; vignetteMiddle: 0.2; vignetteBottom: 0.4 }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: { lock.wakeRequested(); lock.forcePasswordFocus() }
    onPositionChanged: lock.wakeRequested()
  }

  Rectangle {
    id: line
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    anchors.topMargin: Math.round(parent.height * 0.12)
    anchors.bottomMargin: Math.round(parent.height * 0.12)
    width: 1
    color: lock.withAlpha(Commons.Color.lock.text, 0.35)
  }

  // Left of the line: the time, flush against it.
  Text {
    anchors.right: line.left
    anchors.rightMargin: 36
    anchors.verticalCenter: parent.verticalCenter
    anchors.verticalCenterOffset: -Math.round(parent.height * 0.12)
    text: lock.clock("HH:mm")
    color: Commons.Color.lock.text
    font.family: Style.font.family
    font.pixelSize: Math.round(Style.font.baseSize * 8)
    font.weight: Font.Light
    font.letterSpacing: -4
    layer.enabled: true
    layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Qt.rgba(0, 0, 0, 0.5); shadowBlur: 0.8; shadowVerticalOffset: 2 }
  }

  // Right of the line: the day, the date, you.
  Column {
    anchors.left: line.right
    anchors.leftMargin: 36
    anchors.verticalCenter: parent.verticalCenter
    anchors.verticalCenterOffset: -Math.round(parent.height * 0.12)
    spacing: 8
    Text {
      text: lock.date("dddd")
      color: Commons.Color.lock.text
      font.family: Style.font.family
      font.pixelSize: Style.font.title
      font.weight: Font.DemiBold
    }
    Text {
      text: lock.date("d MMMM")
      color: lock.withAlpha(Commons.Color.lock.text, 0.65)
      font.family: Style.font.family
      font.pixelSize: Style.font.body
      font.letterSpacing: 2
    }
    Item { width: 1; height: 10 }
    Row {
      spacing: 12
      Avatar { lock: lock; width: 34; fontSize: Style.font.bodySmall; shadow: false; anchors.verticalCenter: parent.verticalCenter }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: lock.displayName
        textFormat: Text.PlainText
        color: lock.withAlpha(Commons.Color.lock.text, 0.8)
        font.family: Style.font.family
        font.pixelSize: Style.font.body
      }
    }
  }

  // Across the line, below: the field, centred on it.
  Column {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
    anchors.verticalCenterOffset: Math.round(parent.height * 0.12)
    spacing: 12
    PasswordField {
      id: field
      lock: lock
      width: 360
      height: 50
      radius: 0
      outlineThickness: 1
      showLockGlyph: false
      placeholder: lock.tr("Type password")
      color: lock.withAlpha(Commons.Color.lock.background, 0.75)
    }
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      opacity: lock.snapshotMode ? 0 : 1
      text: lock.errorState ? lock.failureMessage
        : (lock.authenticatingPassword ? lock.tr("Checking…")
           : (lock.fingerprintConfigured ? lock.fingerprintHint(lock.tr("Touch sensor or type password")) : lock.tr("Enter unlocks")))
      textFormat: Text.PlainText
      color: lock.errorState ? Commons.Color.lock.textError : lock.withAlpha(Commons.Color.lock.text, 0.5)
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      font.letterSpacing: 2
    }
  }
}
