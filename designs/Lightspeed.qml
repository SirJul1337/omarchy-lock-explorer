import QtQuick
import qs.Commons

// The jump to lightspeed. Stars stream out from the middle of the screen and
// stretch into streaks as the ship speeds up. Every keystroke is a burst of
// speed, a wrong password is a full jump.
DesignBase {
  id: lock
  inputItem: field.input

  // 0 is a slow cruise, 1 is the stars fully stretched.
  property real boost: 0

  Rectangle { anchors.fill: parent; color: Color.background }

  // How fast the ship is going, and how far it has gone. The stars themselves
  // are drawn by a shader (shaders/lightspeed.frag) from these two numbers, so
  // a frame costs the CPU three property updates, not a redraw.
  property real speed: 0.12
  property real depth: 0

  FrameAnimation {
    running: lock.animating
    onTriggered: {
      var dt = Math.min(0.1, frameTime)
      var target = 0.12 + lock.boost * 3.4
      lock.speed += (target - lock.speed) * Math.min(1, dt * 4)
      lock.boost = Math.max(0, lock.boost - dt * 0.8)
      lock.depth += lock.speed * dt * 0.35
    }
  }

  ShaderEffect {
    anchors.fill: parent
    property real depth: lock.depth
    property real speed: lock.speed
    property real pad: 0
    property vector2d viewSize: Qt.vector2d(width, height)
    property color base: Color.lock.text
    property color accent: Color.lock.borderActive
    fragmentShader: Qt.resolvedUrl("shaders/lightspeed.frag.qsb")
    blending: true
    // Drawn into a half size texture and scaled up: a quarter of the pixels
    // to shade, and a star is only a pixel or two wide anyway.
    layer.enabled: true
    layer.smooth: true
    layer.textureSize: Qt.size(Math.max(1, Math.round(width * 0.5)), Math.max(1, Math.round(height * 0.5)))
  }

  // A soft glow where the stars come from, brighter the faster you go.
  Rectangle {
    anchors.centerIn: parent
    width: Math.min(lock.width, lock.height) * (0.5 + lock.boost * 0.5)
    height: width
    radius: width / 2
    opacity: 0.05 + lock.boost * 0.2
    gradient: Gradient {
      GradientStop { position: 0; color: Color.lock.borderActive }
      GradientStop { position: 1; color: "transparent" }
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: { lock.wakeRequested(); lock.forcePasswordFocus() }
    onPositionChanged: lock.wakeRequested()
  }

  Typing {
    id: typing
    lock: lock
    onTyped: lock.boost = Math.min(1, lock.boost + 0.3 + Math.min(0.3, typing.cadence * 0.05))
    onDeleted: lock.boost = Math.min(1, lock.boost + 0.12)
    onCleared: lock.boost = 1
  }

  Connections {
    target: lock
    function onFailureMessageChanged() {
      if (lock.failureMessage.length > 0) lock.boost = 1
    }
  }

  Column {
    anchors.centerIn: parent
    anchors.verticalCenterOffset: -Math.round(lock.height * 0.08)
    spacing: 6
    opacity: lock.snapshotMode ? 0 : 1

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: lock.clock("HH:mm")
      color: Color.lock.text
      font.family: Style.font.family
      font.pixelSize: Math.round(Style.font.baseSize * 9)
      font.weight: Font.Light
      font.letterSpacing: 4
    }
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: lock.date("dddd, d MMMM")
      color: lock.withAlpha(Color.lock.text, 0.7)
      font.family: Style.font.family
      font.pixelSize: Style.font.heading
      font.letterSpacing: 2
    }
  }

  PasswordField {
    id: field
    lock: lock
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
    anchors.verticalCenterOffset: Math.round(lock.height * 0.16)
    width: 380
    height: 56
    radius: 28
    showLockGlyph: false
    color: lock.withAlpha(Color.lock.background, 0.55)
    placeholder: lock.greeting() + ", " + lock.displayName
  }

  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 40
    opacity: lock.snapshotMode ? 0 : 1
    text: lock.failedAttempts > 0
      ? lock.tr(lock.failedAttempts === 1 ? "1 failed attempt" : "%1 failed attempts").arg(lock.failedAttempts)
      : (lock.fingerprintConfigured ? lock.fingerprintHint(lock.tr("Touch the sensor or press Enter")) : lock.tr("Press Enter to unlock"))
    textFormat: Text.PlainText
    color: lock.failedAttempts > 0 ? Color.lock.textError : lock.withAlpha(Color.lock.text, 0.45)
    font.family: Style.font.family
    font.pixelSize: Style.font.bodySmall
    font.letterSpacing: 2
  }
}
