import QtQuick
import QtQuick.Effects
import qs.Commons
import qs.Commons as Commons

// The time as a marquee: digits bigger than the screen, cut off by its bottom
// edge, and a quiet field above them.
DesignBase {
  id: lock
  inputItem: field.input
  mediaStripAtBottom: false
  chromeRadius: 2

  Wallpaper { anchors.fill: parent; lock: lock; blur: 0.5; dim: 0.35; vignetteTop: 0.3; vignetteMiddle: 0.15; vignetteBottom: 0.7 }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: { lock.wakeRequested(); lock.forcePasswordFocus() }
    onPositionChanged: lock.wakeRequested()
  }

  // The digits sit on the bottom edge: a third of them is off the screen.
  Text {
    id: marquee
    anchors.left: parent.left
    anchors.leftMargin: -Math.round(parent.width * 0.02)
    anchors.bottom: parent.bottom
    anchors.bottomMargin: -Math.round(height * 0.34)
    text: lock.clock("HH:mm")
    color: lock.withAlpha(Commons.Color.lock.text, 0.92)
    font.family: Style.font.family
    font.pixelSize: Math.round(parent.height * 0.62)
    font.weight: Font.Black
    font.letterSpacing: -Math.round(parent.height * 0.02)
    // At this size Qt renders the glyphs from a distance field, and its
    // interpolated outline turns the curves (the 8, the colon, the bowls)
    // into visible polygons. The native rasterizer keeps them smooth.
    renderType: Text.NativeRendering
    layer.enabled: true
    layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Qt.rgba(0, 0, 0, 0.6); shadowBlur: 1.0; shadowVerticalOffset: 6 }
  }

  Column {
    anchors.left: parent.left
    anchors.leftMargin: Math.round(parent.width * 0.06)
    anchors.top: parent.top
    anchors.topMargin: Math.round(parent.height * 0.1)
    spacing: 6
    Text {
      text: lock.date("dddd").toUpperCase()
      color: Commons.Color.lock.text
      font.family: Style.font.family
      font.pixelSize: Style.font.heading
      font.weight: Font.DemiBold
      font.letterSpacing: 6
    }
    Text {
      text: lock.date("d MMMM yyyy")
      color: lock.withAlpha(Commons.Color.lock.text, 0.65)
      font.family: Style.font.family
      font.pixelSize: Style.font.body
      font.letterSpacing: 2
    }
  }

  Column {
    anchors.right: parent.right
    anchors.rightMargin: Math.round(parent.width * 0.06)
    anchors.top: parent.top
    anchors.topMargin: Math.round(parent.height * 0.1)
    spacing: 10
    Avatar { lock: lock; width: 56; fontSize: Style.font.heading; anchors.right: parent.right }
    Text {
      anchors.right: parent.right
      text: lock.greeting() + ", " + lock.displayName
      textFormat: Text.PlainText
      color: lock.withAlpha(Commons.Color.lock.text, 0.8)
      font.family: Style.font.family
      font.pixelSize: Style.font.body
    }
  }

  Column {
    anchors.left: parent.left
    anchors.leftMargin: Math.round(parent.width * 0.06)
    anchors.bottom: parent.bottom
    anchors.bottomMargin: Math.round(parent.height * 0.44)
    spacing: 10
    PasswordField {
      id: field
      lock: lock
      width: 420
      height: 52
      radius: 2
      outlineThickness: 1
      showLockGlyph: true
      textAlignment: TextInput.AlignLeft
      placeholder: lock.tr("Enter password")
      color: lock.withAlpha(Commons.Color.lock.background, 0.55)
    }
    Text {
      opacity: lock.snapshotMode ? 0 : 1
      text: lock.errorState ? lock.failureMessage
        : (lock.authenticatingPassword ? lock.tr("Checking…")
           : (lock.fingerprintConfigured ? lock.fingerprintHint(lock.tr("Touch sensor or type password")) : lock.tr("Enter to unlock")))
      textFormat: Text.PlainText
      color: lock.errorState ? Commons.Color.lock.textError : lock.withAlpha(Commons.Color.lock.text, 0.5)
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      font.letterSpacing: 2
    }
  }
}
