import QtQuick
import qs.Commons

// The field throws embers. A handful per keystroke, more the faster you type,
// a red shower on a wrong password. Plain items on a parabola rather than
// QtQuick.Particles, so it draws the same everywhere.
DesignBase {
  id: lock
  inputItem: field.input
  shakeOnFail: true
  flashOnFail: false

  Wallpaper { anchors.fill: parent; lock: lock; blur: 0.9; dim: 0.35; vignetteTop: 0.4; vignetteMiddle: 0.15; vignetteBottom: 0.5 }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: { lock.wakeRequested(); lock.forcePasswordFocus() }
    onPositionChanged: lock.wakeRequested()
  }

  Item { id: embers; anchors.fill: parent; z: 5 }

  Component {
    id: emberComponent
    Rectangle {
      id: ember

      property real originX: 0
      property real originY: 0
      property real vx: 0
      property real vy: -200
      property real gravity: 420
      property real span: 1400
      property real spread: 6

      // One animated number, position follows from it, so the thing actually
      // arcs instead of sliding in a straight line.
      property real t: 0

      x: originX + vx * t - width / 2
      y: originY + vy * t + 0.5 * gravity * t * t - height / 2
      width: spread * (1 - t * 0.7)
      height: width
      radius: width / 2
      antialiasing: true
      opacity: Math.max(0, 1 - t * t)

      Rectangle {
        anchors.centerIn: parent
        width: parent.width * 2.8
        height: width
        radius: width / 2
        color: parent.color
        opacity: 0.25
      }

      NumberAnimation on t {
        from: 0
        to: span / 1000
        duration: ember.span
        easing.type: Easing.Linear
        running: true
        onFinished: ember.destroy()
      }
    }
  }

  function throwEmbers(count, tint, power) {
    var origin = field.mapToItem(lock, field.width / 2, field.height / 2)
    for (var i = 0; i < count; i++) {
      var angle = (-90 + (Math.random() - 0.5) * 110) * Math.PI / 180
      var speed = power * (0.6 + Math.random() * 0.8)
      emberComponent.createObject(embers, {
        originX: origin.x + (Math.random() - 0.5) * field.width * 0.9,
        originY: origin.y,
        vx: Math.cos(angle) * speed,
        vy: Math.sin(angle) * speed,
        span: 900 + Math.random() * 900,
        spread: 7 + Math.random() * 9,
        color: Qt.lighter(tint, 1.2)
      })
    }
  }

  Typing {
    id: typing
    lock: lock
    onTyped: lock.throwEmbers(8 + Math.min(12, Math.round(typing.cadence * 3)), Color.lock.borderActive, 230)
    onDeleted: lock.throwEmbers(3, lock.withAlpha(Color.lock.text, 0.8), 140)
    onCleared: lock.throwEmbers(26, Color.lock.borderActive, 300)
  }

  Connections {
    target: lock
    function onFailureMessageChanged() {
      if (lock.failureMessage.length === 0) return
      lock.throwEmbers(60, Color.lock.textError, 380)
    }
  }

  // A few embers drifting up on their own, so it is never quite still.
  Timer {
    interval: 900
    running: lock.visible
    repeat: true
    onTriggered: {
      var e = emberComponent.createObject(embers, {
        originX: lock.width * (0.1 + Math.random() * 0.8),
        originY: lock.height * 0.95,
        vx: (Math.random() - 0.5) * 30,
        vy: -40 - Math.random() * 40,
        gravity: -8,
        span: 4000 + Math.random() * 2000,
        spread: 4 + Math.random() * 3,
        color: lock.withAlpha(Color.lock.borderActive, 0.7)
      })
    }
  }

  Column {
    anchors.centerIn: parent
    anchors.verticalCenterOffset: -Math.round(lock.height * 0.08)
    spacing: 8

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: Qt.formatTime(lock.now, "HH:mm")
      color: Color.lock.text
      font.family: Style.font.family
      font.pixelSize: Math.round(Style.font.baseSize * 10)
      font.weight: Font.DemiBold
      font.letterSpacing: -2
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: lock.greeting() + ", " + lock.userName
      color: lock.withAlpha(Color.lock.text, 0.7)
      font.family: Style.font.family
      font.pixelSize: Style.font.title
      font.letterSpacing: 1
    }
  }

  PasswordField {
    id: field
    lock: lock
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
    anchors.verticalCenterOffset: Math.round(lock.height * 0.18)
    width: 400
    height: 58
    radius: 10
    showLockGlyph: false
    shakeOnFail: false
    placeholder: "Password"
    color: lock.withAlpha(Color.lock.background, 0.6)
  }
}
