import QtQuick
import qs.Commons
import qs.Ui

BorderSurface {
  id: field

  property var lock: null
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
  readonly property bool revealed: lock ? lock.passwordVisible : false
  readonly property bool showToggle: lock ? lock.showPasswordToggle : true
  readonly property int fieldFontSize: Math.round(Style.font.heading * fontScale)
  readonly property int dotFontSize: Math.round(Style.font.heading * 1.25 * fontScale)
  readonly property int dotLetterSpacing: Math.round(Style.font.heading * 0.19 * fontScale)
  readonly property real fingerprintReserve: (fingerprint ? Math.round(fingerprintIcon.implicitWidth + 12) : 0) + (showToggle ? Math.round(eyeButton.width + 8) : 0)
  readonly property real glyphReserve: showLockGlyph ? Math.round(lockGlyph.implicitWidth + 12) : 0
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

  LockInput {
    id: input
    lock: field.lock
    anchors.fill: parent
    anchors.topMargin: field.borderTop
    anchors.bottomMargin: field.borderBottom
    anchors.leftMargin: field.borderLeft + field.sidePadding + Math.max(field.fingerprintReserve, field.glyphReserve)
    anchors.rightMargin: field.borderRight + field.sidePadding + Math.max(field.fingerprintReserve, field.glyphReserve)
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
    text: field.authenticating ? "Checking…" : (field.errorState ? field.lock.failureMessage : field.placeholder)
    visible: input.text.length === 0
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
    anchors.rightMargin: field.borderRight + field.sidePadding - 6 + (field.fingerprint ? Math.round(fingerprintIcon.implicitWidth + 12) : 0)
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
    anchors.right: parent.right
    anchors.rightMargin: field.borderRight + field.sidePadding
    anchors.verticalCenter: parent.verticalCenter
    visible: field.fingerprint
    text: "󰈷"
    color: Color.lock.placeholder
    font.family: Style.font.family
    font.pixelSize: Math.round(field.fieldFontSize * 1.1)
  }
}
