import QtQuick
import qs.Commons

TextInput {
  id: input

  property var lock: null
  property bool syncing: false
  // Hidden in boot-screen snapshots: the boot theme brings its own entry.
  visible: !(lock && lock.snapshotMode === true)

  // A key PIN is never revealed: the eye toggle belongs to the password, and
  // its state survives a switch into key mode.
  echoMode: lock && lock.passwordVisible && !lock.fido2Active ? TextInput.Normal : TextInput.Password
  passwordCharacter: "●"
  passwordMaskDelay: 0
  activeFocusOnPress: true
  clip: true
  enabled: lock ? (lock.inputEnabled && !lock.authenticatingPassword) : false
  // Inert, not disabled: a disabled item drops focus and stops delivering
  // Keys.onPressed, and Tab has to keep working while the key is waiting.
  // Only while pam_u2f actually has an assertion open, though: with no key
  // plugged in there is nothing to protect the keystrokes from, and refusing
  // them would leave the user with no way in.
  readOnly: lock ? (lock.authenticatingPassword || (lock.fido2Active && lock.fido2Authenticating && !lock.fido2NeedsPin)) : true
  color: Color.lock.text
  selectionColor: Color.lock.selection
  selectedTextColor: Color.lock.text
  font.family: Style.font.family
  font.pixelSize: Style.font.heading

  function sync() {
    if (!lock) return
    if (input.text === lock.passwordText) return
    syncing = true
    input.text = lock.passwordText
    syncing = false
  }

  Connections {
    target: input.lock
    function onPasswordTextChanged() { input.sync() }
  }

  onLockChanged: sync()
  Component.onCompleted: sync()

  onTextChanged: {
    if (!lock || syncing) return
    lock.passwordTextEdited(text)
    if (text.length > 0) lock.wakeRequested()
    if (text.length > 0 && lock.failureMessage.length > 0) lock.clearFailureRequested()
  }

  onAccepted: {
    if (!lock) return
    var submitted = lock.passwordText
    lock.passwordTextEdited("")
    // Typed text is a PIN only while pam_u2f is asking for one. Anything else
    // typed in key mode is a password, and submitPassword leaves key mode.
    if (lock.fido2Active && lock.fido2Authenticating) {
      if (submitted.length > 0) lock.submitFido2Pin(submitted)
      else lock.fido2Requested()
      return
    }
    if (submitted.length > 0) lock.submitPassword(submitted)
    else if (lock.fido2Active) lock.fido2Requested()
    else if (lock.faceConfigured) lock.faceRequested()
  }

  Keys.onPressed: function(event) {
    if (!lock) return
    lock.wakeRequested()

    if (lock.fido2Configured && (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab)) {
      if (lock.fido2Active) lock.passwordRequested()
      else lock.fido2Requested()
      event.accepted = true
      return
    }

    // Inert while the key is waiting for a touch: Enter asks for another go.
    // Nothing retries by itself, each attempt can cost a PIN retry.
    if (lock.fido2Active && lock.fido2Authenticating && !lock.fido2NeedsPin
        && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
      lock.fido2Requested()
      event.accepted = true
      return
    }

    if (event.key === Qt.Key_Escape || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_U)) {
      lock.passwordTextEdited("")
      event.accepted = true
    } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_E) {
      if (lock.showPasswordToggle && !lock.fido2Active) lock.togglePasswordVisible()
      event.accepted = true
    }
  }
}
