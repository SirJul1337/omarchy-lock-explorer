import QtQuick
import qs.Commons

// Slow silk ribbons drifting over a gradient, in the theme's colors. Typing
// makes them swell and pick up speed. The ribbons are drawn by a shader
// (shaders/waves.frag), so a frame costs the CPU one property update.
//
// For a closer copy of the PlayStation 3 menu waves, see Xmb.qml (not listed).
DesignBase {
  id: lock
  inputItem: field.input

  // ======================================================================
  // Settings. Change a number and save: the design reloads. Heights are a
  // share of the screen height (0 is the top, 1 the bottom); frequencies are
  // waves per screen width, roughly.
  // ======================================================================

  // ---- Speed and cost -------------------------------------------------
  // How fast the ribbons drift. 1 is a gentle sway; the default is slower
  // still, a full sway takes a couple of minutes.
  property real drift: 0.08
  // How many times a second the picture is redrawn while it is idle. At the
  // default drift the ribbons move about a pixel a frame at 6, which looks
  // smooth. Raise it if you raise the drift. While you type the rate goes up
  // with the speed, to at most maxFramesPerSecond.
  property real framesPerSecond: 24
  property real maxFramesPerSecond: 30
  // Share of the screen's pixels, each way, that the ribbons are shaded at.
  // They are soft, so well under 1 looks the same and costs much less. 1 is
  // full resolution and about doubles the GPU time.
  property real quality: 0.35

  // ---- Colors ---------------------------------------------------------
  // The ribbons and glow start from this color, the theme's accent.
  property color accentColor: Color.lock.borderActive
  // The ribbons use three colors. The first is the accent; the other two are
  // the accent turned around the color wheel by these amounts (0..1, where
  // 1 is a full turn).
  property real secondColorHueShift: 0.12
  property real thirdColorHueShift: 0.85
  // How colorful the second and third colors are at least (0 is grey).
  property real minimumSaturation: 0.35
  // Set any of these to a color to replace the theme's: for example
  // "#ff8800", or Qt.rgba(1, 0.5, 0, 1).
  property color ribbonColor1: accentColor
  property color ribbonColor2: Qt.hsla((accentColor.hslHue + secondColorHueShift) % 1, Math.max(minimumSaturation, accentColor.hslSaturation), 0.5, 1)
  property color ribbonColor3: Qt.hsla((accentColor.hslHue + thirdColorHueShift) % 1, Math.max(minimumSaturation, accentColor.hslSaturation), 0.45, 1)

  // ---- Background -----------------------------------------------------
  property color backgroundTop: Color.background
  // How much of the accent color the bottom of the screen (0 keeps it the
  // same as the top, 1 makes it the full accent).
  property real backgroundAccent: 0.4
  property color backgroundBottom: Qt.rgba(
    backgroundTop.r + (accentColor.r - backgroundTop.r) * backgroundAccent,
    backgroundTop.g + (accentColor.g - backgroundTop.g) * backgroundAccent,
    backgroundTop.b + (accentColor.b - backgroundTop.b) * backgroundAccent, 1)
  // How far down the screen the glow reaches. 1 is a straight blend from top to
  // bottom; higher keeps the top dark for longer and lights only the bottom.
  property real gradientCurve: 1.6
  // 0 turns the background gradient off (it stays the top color).
  property real gradientStrength: 1.0

  // ---- Ribbons --------------------------------------------------------
  // How many ribbons, 1 to 8. More of them cost nothing in CPU but a little
  // more GPU each.
  property real ribbons: 5
  // Where the first ribbon runs, and how far below it each next one sits.
  property real firstRibbonHeight: 0.42
  property real ribbonSpacing: 0.09
  // How fast the first ribbon moves compared to the drift, and how much faster
  // each next ribbon moves. A step above 0 makes the ribbons slide past each
  // other; 0 keeps them in step.
  property real ribbonSpeedBase: 0.55
  property real ribbonSpeedStep: 0.12

  // Each ribbon is a long, slow sway plus a shorter ripple.
  // Sway: how high it rises and falls, how many bends across the screen, and
  // how much that changes from one ribbon to the next.
  property real swayAmount: 0.11
  property real swayFrequency: 0.9
  property real swayFrequencyStep: 0.17
  // Ripple: the same three for the shorter wave. The step is taken away from
  // the frequency, so the ripples of the upper ribbons are longer.
  property real rippleAmount: 0.05
  property real rippleFrequency: 2.1
  property real rippleFrequencyStep: 0.2

  // ---- Silk -----------------------------------------------------------
  // Half the width of a ribbon at its thinnest, how much wider it swells, and
  // how many times it swells across the screen.
  property real ribbonWidthBase: 0.045
  property real ribbonWidthVariation: 0.04
  property real ribbonWidthFrequency: 1.3
  // How bright the soft body of a ribbon is, and its bright edge line.
  property real fillStrength: 0.16
  property real edgeStrength: 0.22
  // How thin the edge line is. Smaller is a finer line; raise it for a glow.
  property real edgeSharpness: 0.006

  // ---- Typing ---------------------------------------------------------
  // How much typing makes the ribbons swing wider (0 for none), and how much
  // faster they drift while it lasts.
  property real typingSwell: 0.7
  property real typingSpeedUp: 4
  // How much each key, a delete and a wrong password add (1 is the most), and
  // how fast it fades again, per second.
  property real keyEnergy: 0.25
  property real deleteEnergy: 0.1
  property real energyFade: 0.5

  // Seconds of drift, and how much you have typed lately (0..1). Both are
  // driven by the design; do not set them.
  property real time: 0
  property real energy: 0

  Rectangle { anchors.fill: parent; color: Color.background }

  Timer {
    interval: Math.round(1000 / Math.max(1, Math.min(lock.maxFramesPerSecond, lock.framesPerSecond * (1 + lock.energy * lock.typingSpeedUp))))
    repeat: true
    running: lock.animating
    onTriggered: {
      var dt = interval / 1000
      lock.time += dt * lock.drift * (1 + lock.energy * lock.typingSpeedUp)
      lock.energy = Math.max(0, lock.energy - dt * lock.energyFade)
    }
  }

  ShaderEffect {
    anchors.fill: parent
    property real time: lock.time
    property real swell: 1 + lock.energy * lock.typingSwell
    property real aspect: width / Math.max(1, height)
    property color backgroundTop: lock.backgroundTop
    property color backgroundBottom: lock.backgroundBottom
    property color ribbonColor1: lock.ribbonColor1
    property color ribbonColor2: lock.ribbonColor2
    property color ribbonColor3: lock.ribbonColor3
    property real ribbons: Math.max(1, Math.min(8, Math.round(lock.ribbons)))
    property real firstRibbonHeight: lock.firstRibbonHeight
    property real ribbonSpacing: lock.ribbonSpacing
    property real ribbonSpeedBase: lock.ribbonSpeedBase
    property real ribbonSpeedStep: lock.ribbonSpeedStep
    property real swayAmount: lock.swayAmount
    property real swayFrequency: lock.swayFrequency
    property real swayFrequencyStep: lock.swayFrequencyStep
    property real rippleAmount: lock.rippleAmount
    property real rippleFrequency: lock.rippleFrequency
    property real rippleFrequencyStep: lock.rippleFrequencyStep
    property real ribbonWidthBase: lock.ribbonWidthBase
    property real ribbonWidthVariation: lock.ribbonWidthVariation
    property real ribbonWidthFrequency: lock.ribbonWidthFrequency
    property real fillStrength: lock.fillStrength
    property real edgeStrength: lock.edgeStrength
    property real edgeSharpness: Math.max(0.0005, lock.edgeSharpness)
    property real gradientStrength: lock.gradientStrength
    property real gradientCurve: lock.gradientCurve
    fragmentShader: Qt.resolvedUrl("shaders/waves.frag.qsb")
    layer.enabled: true
    layer.smooth: true
    layer.textureSize: Qt.size(Math.max(1, Math.round(width * lock.quality)), Math.max(1, Math.round(height * lock.quality)))
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
    onTyped: lock.energy = Math.min(1, lock.energy + lock.keyEnergy)
    onDeleted: lock.energy = Math.min(1, lock.energy + lock.deleteEnergy)
    onCleared: lock.energy = 1
  }

  Connections {
    target: lock
    function onFailureMessageChanged() {
      if (lock.failureMessage.length > 0) lock.energy = 1
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
      color: lock.withAlpha(Color.lock.text, 0.75)
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
    color: lock.failedAttempts > 0 ? Color.lock.textError : lock.withAlpha(Color.lock.text, 0.55)
    font.family: Style.font.family
    font.pixelSize: Style.font.bodySmall
    font.letterSpacing: 2
  }
}
