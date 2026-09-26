import QtQuick
import qs.Commons
import qs.Ui

BorderSurface {
  id: field
  function tr(text) { return lock && typeof lock.tr === "function" ? lock.tr(text) : text }

  property var lock: null
  // In boot-screen snapshots the box itself stays -- the boot theme puts its
  // passphrase bullets inside it -- but the contents (glyph, placeholder,
  // eye, fingerprint) go.
  readonly property bool snapshotBox: lock ? lock.snapshotMode === true : false
  // The box-free boot capture (snapshotBare) hides the whole field; opacity
  // instead of visible so surrounding layouts do not reflow between grabs.
  opacity: lock && lock.snapshotBare === true ? 0 : 1
  property string placeholder: "Enter password"
  property bool showLockGlyph: true
  property bool shakeOnFail: true
  property int outlineThickness: 2
  property real fontScale: 1.0
  property int textAlignment: TextInput.AlignHCenter
  property int sidePadding: 18

  readonly property alias input: input
  readonly property bool errorState: lock ? lock.errorState : false
  readonly property bool authenticating: lock ? lock.authenticatingPassword : false
  readonly property bool fingerprint: lock ? lock.fingerprintConfigured : false
  readonly property bool face: lock ? lock.faceConfigured : false
  readonly property bool fido2: lock ? lock.fido2Configured : false
  readonly property bool fido2Active: lock ? lock.fido2Active : false
  readonly property bool revealed: lock ? lock.passwordVisible : false
  readonly property bool showToggle: lock ? (lock.showPasswordToggle && !lock.fido2Active) : true
  readonly property int fieldFontSize: Math.round(Style.font.heading * fontScale)
  readonly property int dotFontSize: Math.round(Style.font.heading * 1.25 * fontScale)
  readonly property int dotLetterSpacing: Math.round(Style.font.heading * 0.19 * fontScale)
  readonly property real fingerprintReserve: (fingerprint ? Math.round(fingerprintIcon.implicitWidth + 12) : 0) + (face ? Math.round(faceIcon.implicitWidth + 12) : 0) + (fido2 ? Math.round(fido2Icon.implicitWidth + 12) : 0) + (showToggle ? Math.round(eyeButton.width + 8) : 0)
  // A password is typed blind, so a layout that is not a plain US keyboard is
  // said in the box. It goes with the lock glyph on the left, and is left out
  // of boot snapshots like the rest of the chrome.
  readonly property bool showLayout: lock ? ((lock.foreignLayout === true || lock.layoutSwitchable === true) && !snapshotBox && layoutFits) : false
  readonly property bool showCaps: lock ? (lock.capsLock === true && !snapshotBox) : false
  // The badge is sized from the code and comes out of the text area, and a
  // layout is not always a two-letter country code: a custom XKB layout is a
  // free-form name, and Hyprland reports it verbatim. Unbounded, one of those
  // pushes the placeholder out of the field.
  //
  // Not truncated either. Cutting `USMACFR-XPS` down to `USMA…` leaves a badge
  // opening with US, which reads as the plain-US case this is here to warn
  // about -- worse than saying nothing. A code that cannot fit is not a
  // country code, so the badge stands down and leaves the field to the text.
  readonly property real layoutBadgeMax: Math.round(fieldFontSize * 2.2)
  readonly property bool layoutFits: layoutCode.implicitWidth <= layoutBadgeMax
  readonly property real glyphReserve: (showLockGlyph ? Math.round(lockGlyph.implicitWidth + 12) : 0)
    + (showLayout ? Math.round(layoutBadge.width + 8) : 0)
    + (showCaps ? Math.round(capsBadge.width + 8) : 0)
  readonly property real dotScale: dotMetrics.advanceWidth > 0
    ? Math.min(1, (input.width - 4) / dotMetrics.advanceWidth)
    : 1

  width: 400
  height: 60
  color: Color.lock.background
  radius: Math.max(Style.cornerRadius, 12)
  clip: true
  borderSpec: errorState
    ? Border.surfaceSpec("lock", "border-error", Color.lock.borderError, field.outlineThickness, "border-alpha")
    : Border.surfaceSpec("lock", "border-active", Color.lock.borderActive, field.outlineThickness, "border-alpha")

  function focusInput() { input.forceActiveFocus() }

  TextMetrics {
    id: dotMetrics
    font.family: Style.font.family
    font.pixelSize: field.dotFontSize
    font.letterSpacing: field.dotLetterSpacing
    text: "●".repeat(input.text.length)
  }

  transform: Translate { id: shakeTranslate; x: 0 }
  SequentialAnimation {
    id: shake
    running: false
    NumberAnimation { target: shakeTranslate; property: "x"; from: 0; to: -8; duration: 40 }
    NumberAnimation { target: shakeTranslate; property: "x"; from: -8; to: 8; duration: 70 }
    NumberAnimation { target: shakeTranslate; property: "x"; from: 8; to: -6; duration: 60 }
    NumberAnimation { target: shakeTranslate; property: "x"; from: -6; to: 4; duration: 50 }
    NumberAnimation { target: shakeTranslate; property: "x"; from: 4; to: 0; duration: 40 }
  }
  Connections {
    target: field.lock
    function onFailureMessageChanged() {
      if (field.shakeOnFail && field.lock.failureMessage.length > 0) shake.restart()
    }
  }

  Text {
    id: lockGlyph
    anchors.left: parent.left
    anchors.leftMargin: field.borderLeft + field.sidePadding
    anchors.verticalCenter: parent.verticalCenter
    visible: field.showLockGlyph
    text: field.authenticating ? "󰔟" : (field.errorState ? "󰍁" : "󰌾")
    color: field.errorState ? Color.lock.textError : Color.lock.placeholder
    font.family: Style.font.family
    font.pixelSize: Math.round(field.fieldFontSize * 1.1)
  }

  Rectangle {
    id: layoutBadge
    // Above the input, so a click on it reaches the layout switch.
    z: 2
    visible: field.showLayout
    anchors.left: field.showLockGlyph ? lockGlyph.right : parent.left
    anchors.leftMargin: field.showLockGlyph ? 8 : field.borderLeft + field.sidePadding
    anchors.verticalCenter: parent.verticalCenter
    width: layoutCode.implicitWidth + 10
    height: Math.round(field.fieldFontSize * 1.15)
    radius: 3
    color: "transparent"
    border.width: 1
    border.color: Color.lock.placeholder

    Text {
      id: layoutCode
      anchors.centerIn: parent
      text: field.lock ? field.lock.keyboardLayout : ""
      textFormat: Text.PlainText
      color: Color.lock.placeholder
      font.family: Style.font.family
      font.pixelSize: Math.round(field.fieldFontSize * 0.62)
      font.letterSpacing: 1
    }

    // The next layout, when there is one to go to. The field keeps focus.
    MouseArea {
      anchors.fill: parent
      anchors.margins: -4
      enabled: field.lock ? field.lock.layoutSwitchable === true : false
      cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
      onClicked: field.lock.layoutSwitchRequested()
    }
  }

  // Caps lock earns the accent: it is the one that turns every character
  // wrong, and the reader is about to type a password they cannot see.
  Rectangle {
    id: capsBadge
    visible: field.showCaps
    anchors.left: field.showLayout ? layoutBadge.right
      : (field.showLockGlyph ? lockGlyph.right : parent.left)
    anchors.leftMargin: field.showLayout || field.showLockGlyph ? 8 : field.borderLeft + field.sidePadding
    anchors.verticalCenter: parent.verticalCenter
    width: capsLabel.implicitWidth + 10
    height: Math.round(field.fieldFontSize * 1.15)
    radius: 3
    color: "transparent"
    border.width: 1
    border.color: Color.lock.borderActive

    Text {
      id: capsLabel
      anchors.centerIn: parent
      text: "CAPS"
      textFormat: Text.PlainText
      color: Color.lock.borderActive
      font.family: Style.font.family
      font.pixelSize: Math.round(field.fieldFontSize * 0.62)
      font.letterSpacing: 1
    }
  }

  LockInput {
    id: input
    lock: field.lock
    anchors.fill: parent
    anchors.topMargin: field.borderTop
    anchors.bottomMargin: field.borderBottom
    // Mirrored only when the text is centred, which is what the mirroring is
    // for: keeping it centred between the chrome on either side. A design that
    // aligns left or right has no such need, and mirroring there opens a gap
    // the width of the opposite side's icons before the first character.
    // Each side still reserves its own chrome, so text never runs under it.
    anchors.leftMargin: field.borderLeft + field.sidePadding
      + (field.textAlignment === TextInput.AlignHCenter
        ? Math.max(field.fingerprintReserve, field.glyphReserve) : field.glyphReserve)
    anchors.rightMargin: field.borderRight + field.sidePadding
      + (field.textAlignment === TextInput.AlignHCenter
        ? Math.max(field.fingerprintReserve, field.glyphReserve) : field.fingerprintReserve)
    verticalAlignment: TextInput.AlignVCenter
    horizontalAlignment: field.textAlignment
    font.pixelSize: text.length > 0 && !field.revealed ? Math.max(1, Math.floor(field.dotFontSize * field.dotScale)) : field.fieldFontSize
    font.letterSpacing: text.length > 0 && !field.revealed ? field.dotLetterSpacing * field.dotScale : 0
    cursorVisible: activeFocus && text.length > 0 && !field.authenticating && !field.errorState
    cursorDelegate: Rectangle {
      width: 2
      color: Color.lock.text
      visible: input.cursorVisible
    }
  }

  Text {
    anchors.fill: input
    text: field.authenticating ? tr("Checking…")
      : (field.errorState ? field.lock.failureMessage
      : (field.fido2Active ? (field.lock.fido2Status.length > 0 ? field.lock.fido2Status : tr("Waiting for your key…")) : tr(field.placeholder)))
    textFormat: Text.PlainText
    visible: input.text.length === 0 && !field.snapshotBox
    color: field.authenticating ? Color.lock.text : (field.errorState ? Color.lock.textError : Color.lock.placeholder)
    font.family: Style.font.family
    font.pixelSize: field.fieldFontSize
    font.italic: !field.authenticating && field.errorState
    horizontalAlignment: field.textAlignment
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight
  }

  Item {
    id: eyeButton
    visible: field.showToggle
    width: Math.round(field.fieldFontSize * 1.6)
    height: parent.height
    anchors.right: parent.right
    anchors.rightMargin: field.borderRight + field.sidePadding - 6
      + (field.fingerprint ? Math.round(fingerprintIcon.implicitWidth + 8) : 0)
      + (field.face ? Math.round(faceIcon.implicitWidth + 8) : 0)
      + (field.fido2 ? Math.round(fido2Icon.implicitWidth + 8) : 0)
    Text {
      anchors.centerIn: parent
      text: field.revealed ? "󰈉" : "󰈈"
      color: field.revealed ? Color.lock.borderActive : Color.lock.placeholder
      font.family: Style.font.family
      font.pixelSize: Math.round(field.fieldFontSize * 1.1)
    }
    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        if (field.lock) field.lock.togglePasswordVisible()
        input.forceActiveFocus()
      }
    }
  }

  Text {
    id: fingerprintIcon
    // Beside the face icon when there is one; otherwise in the slot the face
    // icon would take. Anchoring to an invisible face icon left it on top of
    // the eye button whenever a reader was enrolled without face unlock.
    anchors.right: field.face ? faceIcon.left : parent.right
    anchors.rightMargin: field.face ? -9 : field.borderRight + field.sidePadding
      + (field.fido2 ? Math.round(fido2Icon.implicitWidth + 8) : 0)
    anchors.verticalCenter: parent.verticalCenter
    visible: field.fingerprint
    text: "󰈷"
    color: Color.lock.placeholder
    font.family: Style.font.family
    font.pixelSize: Math.round(field.fieldFontSize * 1.1)
  }

  Text {
    id: faceIcon
    anchors.right: parent.right
    anchors.rightMargin: field.borderRight + field.sidePadding
      + (field.fido2 ? Math.round(fido2Icon.implicitWidth + 8) : 0)
    anchors.verticalCenter: parent.verticalCenter
    visible: field.face
    text: "󰱻"
    color: Color.lock.placeholder
    font.family: Style.font.family
    font.pixelSize: Math.round(field.fieldFontSize * 1.1)
  }

  // Lit while the key is the active factor, dim while it is merely enrolled.
  // Click: switch to the key, or try it again when already on it.
  Text {
    id: fido2Icon
    anchors.right: parent.right
    anchors.rightMargin: field.borderRight + field.sidePadding
    anchors.verticalCenter: parent.verticalCenter
    visible: field.fido2
    text: ""
    color: field.fido2Active ? Color.lock.text : Color.lock.placeholder
    font.family: Style.font.family
    font.pixelSize: Math.round(field.fieldFontSize * 1.1)
    MouseArea {
      anchors.fill: parent
      anchors.margins: -8
      cursorShape: Qt.PointingHandCursor
      enabled: field.lock ? field.lock.inputEnabled : false
      onClicked: {
        field.lock.wakeRequested()
        field.lock.fido2Requested()
        input.forceActiveFocus()
      }
    }
  }
}
