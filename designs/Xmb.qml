import QtQuick
import qs.Commons

// XMB style silk waves in the theme's colors, with sparkles drifting over them.
// Not listed in Designs.js: Waves is the simpler one. Add an entry to try this.
// Typing makes the waves swell and pick up speed.
//
// Modelled on the PlayStation 3 XMB recreation at
//   https://linkev.github.io/PlayStation-3-XMB/
// Its settings (spline-settings.js and particles-settings.js) are the
// properties below, with the page's names and default values, so the two can
// be compared and tuned side by side. The picture is drawn by two shaders
// (shaders/xmb.frag and shaders/sparkles.frag, which explain how the page's
// mesh is worked out per pixel), so a frame costs the CPU one property update.
DesignBase {
  id: lock
  inputItem: field.input

  // ---- Colors: the page uses one blue (37, 89, 179) at these two brightnesses.
  // Here the color is the theme's accent, normalised to the page's lightness.
  readonly property color accent: Color.lock.borderActive
  readonly property color tint: Qt.hsla(accent.hslHue, Math.max(0.55, accent.hslSaturation), 0.42, 1)
  property real gradientTopMul: 0.09
  property real gradientBotMul: 0.62
  readonly property color colorTop: Qt.rgba(tint.r * gradientTopMul, tint.g * gradientTopMul, tint.b * gradientTopMul * 1.2, 1)
  readonly property color colorBottom: Qt.rgba(tint.r * gradientBotMul, tint.g * gradientBotMul, tint.b * gradientBotMul, 1)
  // The silk and the sparkles are white on the page; here the theme's text color.
  readonly property color waveColor: Color.lock.text

  // ---- Spline settings (spline-settings.js)
  property real flowSpeed: 0.18
  property real tension: 0.12
  property real damping: 0.0001
  property real length: 0.306001
  property real spacing: 407.658
  property real timeStep: 1.0
  property real bandAmplitude: 0.200
  property real bandSecondaryAmp: 0.025
  property real travelSpeed1: 0.25
  property real travelAmp1: 0.014
  property real travelSpeed2: 0.15
  property real travelAmp2: 0.008
  property real perturbation: 0.0998587
  property real perturbationScale: 0.07
  property real waveCosAmp: 0.09
  property real waveBias: -0.1
  property real waveHeightScale: 0.5
  property real waveSoftClip: 0.22
  property real rePipelineBlend: 0.45
  property real fresnelPower: 4.0
  property real fresnelScale: 0.5
  property real waveOpacity: 0.7
  property real brightness: 0.98
  property real ffdScale1X: 5.67726
  property real ffdYAmp: 0.05
  // Constants written into spline-reverse.js: waves across the screen, and the
  // phase shift from one row of the mesh to the next.
  property real bandFreq: 6.2
  property real bandRowPhase: 1.7
  // Not modelled (they shape the page's noise kernel and z displacement):
  // reDescriptorStrength, reSyntheticDescriptorSeed, reSyntheticDescriptorMotion,
  // reKernelGain, reNormalizeGain, reKernelPhaseStep, reIndexJitter,
  // reTemporalSmooth, zDetailScale, ffdScale1Y/Z, ffdScale2X/Y/Z, ffdOffsetX/Y/Z, ffdZAmp.

  // ---- Particle settings (particles-settings.js)
  // How many sparkles. The page uses 2000, but they cost about a third of this
  // design's GPU time (roughly +2 to 3% GPU at 2000 on an Intel UHD 630, and more on
  // bigger screens), so they are off here. Raise it slowly, and measure with
  // tests/bench-lock-load.sh waves before keeping a high number. 0 turns the
  // sparkle layer off completely.
  property real count: 0
  property real particleOpacity: 0.75
  property real sizeBase: 2.6
  property real sizeVar: 1.5
  property real particleFlowSpeed: 0.18

  // Share of the screen's pixels each way that the waves are shaded at. They
  // are smooth, so well under 1 looks the same and costs much less.
  property real quality: 1.0
  property real sparkleQuality: 0.5

  // Seconds of drift, advanced faster while you type, and how much you have
  // typed lately (0..1, decays).
  property real time: 0
  property real energy: 0

  Rectangle { anchors.fill: parent; color: Color.background }

  // About 30 frames a second is plenty for something this slow, and half the
  // GPU work of following the display.
  Timer {
    interval: 33
    repeat: true
    running: lock.animating
    onTriggered: {
      lock.time += 0.033 * (1 + lock.energy * 2.5)
      lock.energy = Math.max(0, lock.energy - 0.033 * 0.5)
    }
  }

  ShaderEffect {
    anchors.fill: parent
    property real time: lock.time
    property real swell: 1 + lock.energy * 0.7
    property real pad0: 0
    property color colorTop: lock.colorTop
    property color colorBottom: lock.colorBottom
    property color waveColor: lock.waveColor
    property real flowSpeed: lock.flowSpeed
    property real tension: lock.tension
    property real damping: lock.damping
    property real length: lock.length
    property real spacing: lock.spacing
    property real timeStep: lock.timeStep
    property real bandAmplitude: lock.bandAmplitude
    property real bandFreq: lock.bandFreq
    property real bandRowPhase: lock.bandRowPhase
    property real bandSecondaryAmp: lock.bandSecondaryAmp
    property real travelSpeed1: lock.travelSpeed1
    property real travelAmp1: lock.travelAmp1
    property real travelSpeed2: lock.travelSpeed2
    property real travelAmp2: lock.travelAmp2
    property real perturbation: lock.perturbation
    property real perturbationScale: lock.perturbationScale
    property real waveCosAmp: lock.waveCosAmp
    property real waveBias: lock.waveBias
    property real waveHeightScale: lock.waveHeightScale
    property real waveSoftClip: lock.waveSoftClip
    property real rePipelineBlend: lock.rePipelineBlend
    property real fresnelPower: lock.fresnelPower
    property real fresnelScale: lock.fresnelScale
    property real waveOpacity: lock.waveOpacity
    property real brightness: lock.brightness
    property real ffdScale1X: lock.ffdScale1X
    property real ffdYAmp: lock.ffdYAmp
    fragmentShader: Qt.resolvedUrl("shaders/xmb.frag.qsb")
    // Smooth shapes, so a fraction of the pixels shades them just as well.
    layer.enabled: true
    layer.smooth: true
    layer.textureSize: Qt.size(Math.max(1, Math.round(width * lock.quality)), Math.max(1, Math.round(height * lock.quality)))
  }

  // The sparkles move even more slowly, so they redraw about 15 times a second.
  property real sparkleTime: 0
  Timer {
    interval: 66
    repeat: true
    running: lock.animating && lock.count > 0
    onTriggered: lock.sparkleTime = lock.time
  }

  ShaderEffect {
    anchors.fill: parent
    visible: lock.count > 0
    property real time: lock.sparkleTime
    property real aspect: width / Math.max(1, height)
    property real viewHeight: height
    property color color: lock.waveColor
    property real count: lock.count
    property real particleOpacity: lock.particleOpacity
    property real sizeBase: lock.sizeBase
    property real sizeVar: lock.sizeVar
    property real particleFlowSpeed: lock.particleFlowSpeed
    fragmentShader: Qt.resolvedUrl("shaders/sparkles.frag.qsb")
    blending: true
    // Sparkles are small and soft, so half the pixels each way will do.
    layer.enabled: true
    layer.smooth: true
    layer.textureSize: Qt.size(Math.max(1, Math.round(width * lock.sparkleQuality)), Math.max(1, Math.round(height * lock.sparkleQuality)))
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
    onTyped: lock.energy = Math.min(1, lock.energy + 0.25)
    onDeleted: lock.energy = Math.min(1, lock.energy + 0.1)
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
