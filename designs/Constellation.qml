import QtQuick
import qs.Commons

// Each character puts a star in the sky and draws the line to the one before
// it, so a password writes out its own figure. Backspace takes the last star
// back, a wrong password burns the lines red.
DesignBase {
  id: lock
  inputItem: field.input
  shakeOnFail: true
  flashOnFail: false

  readonly property int maxStars: 18
  // Between the clock and the field, with room for the scatter either side.
  readonly property real bandY: height * 0.5
  property bool alarm: false

  Wallpaper { anchors.fill: parent; lock: lock; blur: 1.0; dim: 0.45; vignetteTop: 0.5; vignetteMiddle: 0.25; vignetteBottom: 0.55 }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: { lock.wakeRequested(); lock.forcePasswordFocus() }
    onPositionChanged: lock.wakeRequested()
  }

  // Stable pseudo random in 0..1, so a slot always lands in the same place.
  function scatter(seed) {
    var v = Math.sin(seed * 12.9898 + 4.1414) * 43758.5453
    return v - Math.floor(v)
  }

  function starPoint(index) {
    var slot = index % lock.maxStars
    var t = (slot + 0.5) / lock.maxStars
    return {
      px: lock.width * (0.12 + 0.76 * t),
      py: lock.bandY + (lock.scatter(slot) - 0.5) * lock.height * 0.3
    }
  }

  ListModel { id: stars }

  Typing {
    lock: lock
    onTyped: function(index) { stars.append(lock.starPoint(index)) }
    onDeleted: if (stars.count > 0) stars.remove(stars.count - 1)
    onCleared: stars.clear()
  }

  Connections {
    target: lock
    function onFailureMessageChanged() {
      if (lock.failureMessage.length === 0) return
      lock.alarm = true
      alarmTimer.restart()
    }
  }

  Timer { id: alarmTimer; interval: 900; onTriggered: lock.alarm = false }

  // The sky the constellation is drawn on.
  Repeater {
    model: 70
    delegate: Rectangle {
      required property int index
      readonly property real seed: index + 1
      width: 1 + lock.scatter(seed * 3) * 2
      height: width
      radius: width / 2
      x: lock.width * lock.scatter(seed)
      y: lock.height * lock.scatter(seed * 7)
      color: lock.withAlpha(Color.lock.text, 0.12 + lock.scatter(seed * 11) * 0.35)

      SequentialAnimation on opacity {
        loops: Animation.Infinite
        running: lock.visible
        NumberAnimation { to: 0.35; duration: 1400 + Math.round(lock.scatter(seed * 5) * 2600) }
        NumberAnimation { to: 1.0; duration: 1400 + Math.round(lock.scatter(seed * 13) * 2600) }
      }
    }
  }

  // The figure grows left to right through its slots, so slide it along to
  // keep the drawn part of it in the middle of the screen.
  Item {
    id: figure
    width: lock.width
    height: lock.height

    readonly property real slotWidth: lock.width * 0.76 / lock.maxStars
    readonly property int used: Math.min(stars.count, lock.maxStars)
    // No anchors here on purpose, an anchored item ignores x.
    x: used > 0 ? lock.width / 2 - (lock.width * 0.12 + slotWidth * used / 2) : 0
    Behavior on x { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

    // Lines first, so the stars sit on top of them.
    Repeater {
      model: stars
      delegate: Rectangle {
        required property int index
        required property real px
        required property real py
        readonly property var prev: index > 0 ? stars.get(index - 1) : null

        visible: prev !== null
        x: prev ? prev.px : 0
        y: (prev ? prev.py : 0) - height / 2
        width: prev ? Math.sqrt(Math.pow(px - prev.px, 2) + Math.pow(py - prev.py, 2)) : 0
        height: 2
        transformOrigin: Item.Left
        rotation: prev ? Math.atan2(py - prev.py, px - prev.px) * 180 / Math.PI : 0
        color: lock.alarm ? Color.lock.textError : lock.withAlpha(Color.lock.borderActive, 0.55)
        Behavior on color { ColorAnimation { duration: 200 } }

        opacity: 0
        Component.onCompleted: opacity = 1
        Behavior on opacity { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
      }
  }

  Repeater {
    model: stars
    delegate: Item {
      required property real px
      required property real py
      x: px
      y: py

      Rectangle {
        anchors.centerIn: parent
        width: 26
        height: 26
        radius: 13
        color: lock.withAlpha(lock.alarm ? Color.lock.textError : Color.lock.borderActive, 0.18)
      }

      Rectangle {
        anchors.centerIn: parent
        width: 9
        height: 9
        radius: 4.5
        color: lock.alarm ? Color.lock.textError : Color.lock.text
        Behavior on color { ColorAnimation { duration: 200 } }
      }

      scale: 0
      Component.onCompleted: scale = 1
      Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutBack } }
    }
  }
  }

  Column {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top
    anchors.topMargin: Math.round(lock.height * 0.1)
    spacing: 6

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: Qt.formatTime(lock.now, "HH:mm")
      color: Color.lock.text
      font.family: Style.font.family
      font.pixelSize: Math.round(Style.font.baseSize * 7)
      font.weight: Font.Light
      font.letterSpacing: 4
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: Qt.formatDate(lock.now, "dddd d MMMM").toUpperCase()
      color: lock.withAlpha(Color.lock.text, 0.6)
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      font.letterSpacing: 5
    }
  }

  Column {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: Math.round(lock.height * 0.12)
    spacing: 12

    PasswordField {
      id: field
      lock: lock
      anchors.horizontalCenter: parent.horizontalCenter
      width: 380
      height: 54
      radius: height / 2
      showLockGlyph: false
      shakeOnFail: false
      placeholder: "Password"
      color: lock.withAlpha(Color.lock.background, 0.55)
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: stars.count === 0 ? "Type to draw" : stars.count + (stars.count === 1 ? " star" : " stars")
      color: lock.withAlpha(Color.lock.text, 0.5)
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      font.letterSpacing: 2
    }
  }
}
