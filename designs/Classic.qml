import QtQuick
import qs.Commons

DesignBase {
  id: lock
  inputItem: field.input

  Wallpaper { anchors.fill: parent; lock: lock; blur: 1.0; dim: 0.0; contrast: -0.08; vignette: false }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: { lock.wakeRequested(); lock.forcePasswordFocus() }
    onPositionChanged: lock.wakeRequested()
  }

  PasswordField {
    id: field
    lock: lock
    anchors.centerIn: parent
    width: 381
    height: 67
    radius: Style.cornerRadius
    outlineThickness: 3
    showLockGlyph: false
    shakeOnFail: false
    placeholder: "Enter Password"
    fontScale: 1.125
  }
}
