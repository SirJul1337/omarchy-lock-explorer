import QtQuick
import QtQuick.Effects
import qs.Commons

// The time in the middle of the screen, over thin concentric rings in the
// theme's accent color on its background. The rings are centred on a sun that
// circles the middle of the screen once a day, so where it is tells the time of
// day: noon at the top, midnight at the bottom. The time fades out and back in
// as each minute changes.
//
// A port of https://jgarza9788.github.io/hawaiian_clock/ , which colors the
// rings as a sunset; here they follow the theme. The picture is drawn by a
// shader (shaders/solclock.frag), and since the sun moves only a few pixels a
// minute it is redrawn every few seconds, so this costs next to nothing.
DesignBase {
  id: lock
  inputItem: field.input

  // ======================================================================
  // Settings. Change a number and save: the design reloads.
  // ======================================================================

  // ---- Speed and cost -------------------------------------------------
  // How often the sun's position is worked out and the rings are redrawn, in
  // seconds. The sun moves about 3 pixels a minute, so 5 is plenty.
  property real updateSeconds: 5

  // ---- The middle -----------------------------------------------------
  // Where the middle is, as a share of the screen (0 to 1). The time sits here
  // and the sun orbits it. 0.5, 0.5 is the middle of the screen.
  property real centerX: 0.5
  property real centerY: 0.5

  // ---- The sun --------------------------------------------------------
  // How big the sun is: its radius as a percent of the shorter side of the
  // screen (18 is about a fifth of the height across).
  property real sunSize: 12
  // How much white the sun adds (0..1), the same way as the time does. 1 makes
  // a solid disc; lower makes it show as thicker rings, like the digits. Like
  // the time, the sun is blurred (see `blur`), which gives it a soft edge that
  // the hard contrast turns into blobs.
  property real sunOpacity: 1.0
  // A glow round the sun, behind the blurred layer: it thickens the rings near
  // the sun until they run together at its edge. How far it reaches past the sun
  // (a percent of the shorter side of the screen), how strong it is at the sun's
  // edge (0..1, 0 turns it off; around 0.5 gives thick rings, higher fills the
  // gaps solid), and how quickly it fades (1 is a straight fade, higher keeps it
  // close to the sun).
  property real glowSize: 12
  property real glowStrength: 0.5
  property real glowCurve: 1.5
  // Centre the rings on the sun (as on the page), so they move with it. Turn off
  // to keep the rings round the middle of the screen and move only the sun.
  property bool ringsFollowSun: true
  // How long one trip round the screen takes, in hours. 24 makes it a clock of
  // the day. Try 0.1 to watch it go.
  property real orbitHours: 24
  // How far from the middle it orbits, as a percent of the shorter side of the
  // screen.
  property real orbitRadius: 40
  // Where it starts, in degrees. 0 puts it at the bottom at midnight, and so
  // at the top at noon; the page does the same.
  property real orbitStartAngle: 0
  // Set to a position (x, y as a share of the screen, 0 to 1) to hold the sun
  // still there instead of orbiting the middle. Leave at -1 to orbit.
  property real pinnedX: -1
  property real pinnedY: -1

  // ---- Rings ----------------------------------------------------------
  // Space from one ring to the next, as a share of the big text's height. The
  // page uses 0.05.
  property real ringSpacing: 0.05
  // How much further apart the rings are the further they are from the sun, like
  // ripples on water (0 keeps them evenly spaced; 0.15 is subtle, 0.5 strong).
  property real ringSpread: 0.15
  // The rings slowly spread outward from the sun, in rings per second (0 keeps
  // them still, which costs nothing between sun moves). This redraws the screen
  // rippleFramesPerSecond times a second. Each frame a second costs about a
  // quarter of a percent of GPU on an Intel UHD 630: 12 is about 4%, 20 about
  // 5%, 30 about 9%. Keep it near the speed: at this speed anything over 12
  // looks smooth, and a faster ripple needs more.
  property real rippleSpeed: 0.12
  property real rippleFramesPerSecond: 20
  // The rings are grey ramps that the contrast below cuts into lines. This is
  // how grey the top of a ramp gets (0..1): the page uses 0.533. Just over 0.5
  // gives hair thin lines; higher makes thicker lines.
  property real peakValue: 0.5
  // How hard the cut is. The page uses 20 (its contrast(2000%)). Lower makes
  // soft edges, which also softens the sun and the numbers.
  property real contrast: 20
  // A dark shadow just inside the edges of the screen: its size in pixels and
  // how dark (0 turns it off). The page uses 25 and 1.
  property real vignetteSize: 50
  property real vignetteStrength: 0.1

  // ---- Colors ---------------------------------------------------------
  // The rings, the sun and the digits are drawn in this color (the theme's
  // accent), and everything between them in the other (the theme's background).
  property color lineColor: Color.lock.borderActive
  property color gapColor: Color.background
  // The rings far from the sun fade to this color, a dimmer accent, over farDistance
  // (a percent of the shorter side of the screen). Set farColor to lineColor to
  // keep every ring the same.
  property color farColor: Qt.rgba(lineColor.r * 0.45 + gapColor.r * 0.55, lineColor.g * 0.45 + gapColor.g * 0.55, lineColor.b * 0.45 + gapColor.b * 0.55, 1)
  property real farDistance: 120

  // ---- Time -----------------------------------------------------------
  // Size of the digits as a share of the screen's height (the page uses 0.26),
  // and how much white they add (0..1; the page fades up to 0.5). The digits
  // are only a mask for the rings, so they take the line color.
  property real numberSizeShare: 0.26
  property real numberOpacity: 0.5
  // How blurred the time and the sun are (0 is sharp, 1 is the most, 16 pixels).
  // Anything over 1 counts as 1.
  property real blur: 5.0
  // Italic and heavy, as on the page.
  property bool italic: false
  property bool heavy: true
  // Only the characters that change fade: how long one takes to fade out, and
  // back in, in milliseconds.
  property int fadeDuration: 250

  // ---- Typing ---------------------------------------------------------
  // Every key sends a ring out from the sun, and a wrong password sends a
  // red one. Turn pulses off with pulseStrength 0.
  property real pulseStrength: 0.8
  // How far the pulse travels, as a percent of the shorter side of the screen,
  // how thick it is (a percent too), and how long it takes, in milliseconds.
  property real pulseReach: 90
  property real pulseThickness: 1.6
  property int pulseDuration: 1100
  // The pulse colors: for a key (the line color by default, a touch lighter) and
  // for a wrong password.
  property color pulseColor: Qt.lighter(lineColor, 1.3)
  property color errorPulseColor: Color.lock.textError

  // ---- Driven by the design; do not set --------------------------------
  // How far through the orbit the sun is, 0..1.
  property real dayFraction: 0
  readonly property real shortSide: Math.min(lock.width, lock.height)
  readonly property real angle: dayFraction * 2 * Math.PI + orbitStartAngle * Math.PI / 180
  readonly property real middleX: lock.width * centerX
  readonly property real middleY: lock.height * centerY
  readonly property real sunX: pinnedX >= 0 ? lock.width * pinnedX : middleX + Math.sin(angle) * orbitRadius * shortSide / 100
  readonly property real sunY: pinnedY >= 0 ? lock.height * pinnedY : middleY + Math.cos(angle) * orbitRadius * shortSide / 100

  // Pulse state: 0 at the start, 1 when it has gone. And the ripple clock, in
  // rings.
  property real pulse: 1
  property color pulseNow: pulseColor
  property real ripple: 0

  function sendPulse(color) {
    if (pulseStrength <= 0) return
    pulseNow = color
    pulseAnim.restart()
  }

  NumberAnimation {
    id: pulseAnim
    target: lock
    property: "pulse"
    from: 0
    to: 1
    duration: lock.pulseDuration
    easing.type: Easing.OutCubic
  }

  Timer {
    interval: Math.round(1000 / Math.max(1, lock.rippleFramesPerSecond))
    repeat: true
    running: lock.animating && lock.rippleSpeed > 0
    onTriggered: lock.ripple = (lock.ripple + lock.rippleSpeed * interval / 1000) % 1
  }

  function updateSun() {
    var n = new Date()
    var seconds = n.getHours() * 3600 + n.getMinutes() * 60 + n.getSeconds()
    dayFraction = (seconds / (orbitHours * 3600)) % 1
  }

  Rectangle { anchors.fill: parent; color: Color.background }

  Timer {
    interval: Math.max(1, lock.updateSeconds) * 1000
    repeat: true
    running: lock.animating
    triggeredOnStart: true
    onTriggered: lock.updateSun()
  }

  // The rings, sun and numbers, drawn together as the page does. Redrawn only
  // when something moves: the sun, a character fading, a pulse or the ripple.
  ShaderEffect {
    anchors.fill: parent
    property real sunX: lock.sunX
    property real sunY: lock.sunY
    property real sunRadius: lock.sunSize * lock.shortSide / 100
    property real glowSize: lock.glowSize * lock.shortSide / 100
    property real glowStrength: lock.glowStrength
    property real glowCurve: lock.glowCurve
    property real ringX: lock.ringsFollowSun ? lock.sunX : lock.middleX
    property real ringY: lock.ringsFollowSun ? lock.sunY : lock.middleY
    property real viewWidth: width
    property real viewHeight: height
    property real em: lock.height * 0.35
    property real ringSpacing: lock.ringSpacing
    property real peakValue: lock.peakValue
    property real contrast: lock.contrast
    property real numberOpacity: lock.numberOpacity
    property real sunOpacity: lock.sunOpacity
    property real vignetteSize: lock.vignetteSize * lock.height / 1080
    property real vignetteStrength: lock.vignetteStrength
    property real ringPhase: lock.ripple
    property real ringSpread: lock.ringSpread
    property real farDistance: lock.farDistance * lock.shortSide / 100
    property real pulseRadius: lock.pulse * lock.pulseReach * lock.shortSide / 100
    property real pulseWidth: lock.pulseThickness * lock.shortSide / 100
    property real pulseAmount: (1 - lock.pulse) * lock.pulseStrength
    property color lineColor: lock.lineColor
    property color farColor: lock.farColor
    property color gapColor: lock.gapColor
    property color pulseColor: lock.pulseNow
    // The time (red) and the sun (green), blurred, as a picture.
    property variant mask: maskSource
    fragmentShader: Qt.resolvedUrl("shaders/solclock.frag.qsb")
    // The picture covers every pixel, so there is nothing to blend with.
    blending: false
    // Cached while nothing moves: the picture is drawn again only when a
    // property above changes. With the ripple on it changes all the time, so the
    // extra cached copy would only cost.
    layer.enabled: lock.rippleSpeed <= 0
    layer.smooth: true
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: { lock.wakeRequested(); lock.forcePasswordFocus() }
    onPositionChanged: lock.wakeRequested()
  }

  // The time and the sun, drawn off screen and blurred into a picture for the
  // shader above: the time in the red channel, the sun in the green.
  //
  // The time is five separate characters, so that only the ones that change
  // fade: at 19:14 turning to 19:15 only the last digit goes out and back in.
  readonly property string timeText: lock.clock("HH:mm")
  readonly property real digitSize: Math.round(lock.height * lock.numberSizeShare)
  readonly property real glyphSpacing: -digitSize * 0.05
  // How many characters are fading right now.
  property int fading: 0

  TextMetrics {
    id: metrics
    text: "0"
    font.family: Style.font.family
    font.pixelSize: lock.digitSize
    font.italic: lock.italic
    font.weight: lock.heavy ? Font.Black : Font.Normal
  }
  TextMetrics {
    id: colonMetrics
    text: ":"
    font.family: Style.font.family
    font.pixelSize: lock.digitSize
    font.italic: lock.italic
    font.weight: lock.heavy ? Font.Black : Font.Normal
  }

  // One character, which fades out, changes, and fades back in when its
  // character in the time changes.
  component Glyph: Text {
    id: glyph
    property string wanted: ""
    property bool busy: false
    text: wanted
    color: "#ff0000"
    font.family: Style.font.family
    font.pixelSize: lock.digitSize
    font.italic: lock.italic
    font.weight: lock.heavy ? Font.Black : Font.Normal
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    // The character shown follows `wanted` only through the fade.
    onWantedChanged: if (text !== wanted && text !== "") {
      if (!busy) { busy = true; lock.fading++ }
      swap.restart()
    } else text = wanted
    SequentialAnimation {
      id: swap
      NumberAnimation { target: glyph; property: "opacity"; to: 0; duration: lock.fadeDuration }
      ScriptAction { script: glyph.text = glyph.wanted }
      NumberAnimation { target: glyph; property: "opacity"; to: 1; duration: lock.fadeDuration }
      ScriptAction { script: { glyph.busy = false; lock.fading--; lock.refreshMask() } }
    }
  }

  Item {
    id: digits
    anchors.fill: parent
    visible: false

    Rectangle {
      x: lock.sunX - width / 2
      y: lock.sunY - height / 2
      width: 2 * lock.sunSize * lock.shortSide / 100
      height: width
      radius: width / 2
      color: "#00ff00"
    }

    // HH:mm, each character in a slot as wide as it is.
    Row {
      id: timeRow
      x: lock.middleX - width / 2
      y: lock.middleY - height / 2
      spacing: lock.glyphSpacing
      Repeater {
        model: 5
        Glyph {
          required property int index
          width: (index === 2 ? colonMetrics.advanceWidth : metrics.advanceWidth)
          height: metrics.height
          wanted: lock.timeText.charAt(index)
        }
      }
    }
  }
  MultiEffect {
    id: blurredDigits
    anchors.fill: parent
    source: digits
    autoPaddingEnabled: false
    blurEnabled: lock.blur > 0
    blur: Math.min(1, lock.blur)
    blurMax: 16
    visible: false
  }
  // The blurred picture is expensive to make, so it is made only when the sun
  // moves, a character changes or the window resizes, not every frame.
  ShaderEffectSource {
    id: maskSource
    sourceItem: blurredDigits
    hideSource: true
    live: lock.fading > 0
    // It is blurred already, so half the pixels each way loses nothing and
    // halves what the shader reads for every pixel it draws.
    textureSize: Qt.size(Math.max(1, Math.round(lock.width / 2)), Math.max(1, Math.round(lock.height / 2)))
  }
  function refreshMask() { maskSource.scheduleUpdate() }
  onSunXChanged: refreshMask()
  onSunYChanged: refreshMask()
  onWidthChanged: refreshMask()
  onHeightChanged: refreshMask()
  onTimeTextChanged: Qt.callLater(refreshMask)
  Component.onCompleted: Qt.callLater(refreshMask)

  Typing {
    id: typing
    lock: lock
    onTyped: lock.sendPulse(lock.pulseColor)
    onDeleted: lock.sendPulse(lock.pulseColor)
    onCleared: lock.sendPulse(lock.pulseColor)
  }

  Connections {
    target: lock
    function onFailureMessageChanged() {
      if (lock.failureMessage.length > 0) lock.sendPulse(lock.errorPulseColor)
    }
  }

  PasswordField {
    id: field
    lock: lock
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
    anchors.verticalCenterOffset: Math.round(lock.height * 0.4)
    width: 380
    height: 56
    radius: 28
    showLockGlyph: false
    color: lock.withAlpha(Color.lock.background, 0.7)
    placeholder: lock.greeting() + ", " + lock.displayName
  }

  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 12
    opacity: lock.snapshotMode ? 0 : 1
    text: lock.failedAttempts > 0
      ? lock.tr(lock.failedAttempts === 1 ? "1 failed attempt" : "%1 failed attempts").arg(lock.failedAttempts)
      : (lock.fingerprintConfigured ? lock.fingerprintHint(lock.tr("Touch the sensor or press Enter")) : lock.tr("Press Enter to unlock"))
    textFormat: Text.PlainText
    color: lock.failedAttempts > 0 ? Color.lock.textError : lock.withAlpha(Color.lock.text, 0.7)
    font.family: Style.font.family
    font.pixelSize: Style.font.bodySmall
    font.letterSpacing: 2
  }
}
