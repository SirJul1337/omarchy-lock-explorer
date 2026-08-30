import QtQuick
import qs.Commons

// Every keystroke drops into the water. Rings spread and fade, a wrong password
// throws one big red wave, and the surface never sits completely still.
DesignBase {
  id: lock
  inputItem: field.input
  shakeOnFail: true
  flashOnFail: false

  Wallpaper { anchors.fill: parent; lock: lock; blur: 0.7; dim: 0.2; vignetteTop: 0.3; vignetteMiddle: 0.1; vignetteBottom: 0.4 }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: function(mouse) {
      lock.wakeRequested()
      lock.forcePasswordFocus()
      lock.splash(mouse.x, mouse.y, 260, Color.lock.borderActive, 0.4)
    }
    onPositionChanged: lock.wakeRequested()
  }

  Item { id: ripples; anchors.fill: parent }

  Component {
    id: rippleComponent
    Rectangle {
      id: ring
      property real cx: 0
      property real cy: 0
      property real spread: 240
      property real peak: 0.5
      property bool filled: false

      x: cx - spread / 2
      y: cy - spread / 2
      width: spread
      height: spread
      radius: spread / 2
      color: filled ? Qt.rgba(border.color.r, border.color.g, border.color.b, 0.12) : "transparent"
      border.width: filled ? 0 : 2
      opacity: 0
      scale: 0.08
      antialiasing: true

      ParallelAnimation {
        running: true
        NumberAnimation { target: ring; property: "scale"; from: 0.08; to: 1; duration: ring.filled ? 700 : 1500; easing.type: Easing.OutCubic }
        SequentialAnimation {
          NumberAnimation { target: ring; property: "opacity"; from: 0; to: ring.peak; duration: 110 }
          NumberAnimation { target: ring; property: "opacity"; to: 0; duration: ring.filled ? 590 : 1390; easing.type: Easing.InQuad }
        }
        onFinished: ring.destroy()
      }
    }
  }

  function splash(x, y, spread, tint, peak) {
    var strength = peak === undefined ? 0.5 : peak
    var ring = rippleComponent.createObject(ripples, { cx: x, cy: y, spread: spread, peak: strength, filled: false })
    if (ring) ring.border.color = tint
    var drop = rippleComponent.createObject(ripples, { cx: x, cy: y, spread: spread * 0.35, peak: strength * 0.7, filled: true })
    if (drop) drop.border.color = tint
  }

  // Keystrokes land on the field, spread out along it so a long password does
  // not stack every ring in the same spot.
  function keySplash() {
    var point = field.mapToItem(lock, field.width * (0.12 + Math.random() * 0.76), field.height / 2)
    lock.splash(point.x, point.y, 200 + Math.random() * 140, Color.lock.borderActive, 0.55)
  }

  Typing {
    lock: lock
    onTyped: lock.keySplash()
    onDeleted: {
      var point = field.mapToItem(lock, field.width / 2, field.height / 2)
      lock.splash(point.x, point.y, 120, lock.withAlpha(Color.lock.text, 0.9), 0.3)
    }
  }

  Connections {
    target: lock
    function onFailureMessageChanged() {
      if (lock.failureMessage.length === 0) return
      var point = field.mapToItem(lock, field.width / 2, field.height / 2)
      lock.splash(point.x, point.y, Math.max(lock.width, lock.height) * 1.1, Color.lock.textError, 0.5)
    }
  }

  // The surface keeps moving on its own, the way water does.
  Timer {
    id: drip
    interval: 3000
    running: true
    repeat: true
    onTriggered: {
      interval = 2500 + Math.round(Math.random() * 4000)
      lock.splash(lock.width * (0.1 + Math.random() * 0.8),
                  lock.height * (0.1 + Math.random() * 0.8),
                  160 + Math.random() * 220,
                  lock.withAlpha(Color.lock.text, 0.5), 0.18)
    }
  }

  Column {
    anchors.centerIn: parent
    anchors.verticalCenterOffset: -Math.round(lock.height * 0.06)
    spacing: 10

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: Qt.formatTime(lock.now, "HH:mm")
      color: Color.lock.text
      font.family: Style.font.family
      font.pixelSize: Math.round(Style.font.baseSize * 9)
      font.weight: Font.Light
      font.letterSpacing: 2
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: Qt.formatDate(lock.now, "dddd d MMMM")
      color: lock.withAlpha(Color.lock.text, 0.7)
      font.family: Style.font.family
      font.pixelSize: Style.font.title
      font.letterSpacing: 2
    }
  }

  PasswordField {
    id: field
    lock: lock
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
    anchors.verticalCenterOffset: Math.round(lock.height * 0.16)
    width: 400
    height: 58
    radius: height / 2
    showLockGlyph: false
    shakeOnFail: false
    placeholder: "Password"
    color: lock.withAlpha(Color.lock.background, 0.6)
  }
}
