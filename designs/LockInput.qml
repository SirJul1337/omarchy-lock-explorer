import QtQuick
import qs.Commons

TextInput {
  id: input

  property var lock: null
  property bool syncing: false

  echoMode: TextInput.Password
  passwordCharacter: "●"
  passwordMaskDelay: 0
  activeFocusOnPress: true
  clip: true
  enabled: lock ? (lock.inputEnabled && !lock.authenticatingPassword) : false
  readOnly: lock ? lock.authenticatingPassword : true
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
    if (submitted.length > 0) lock.submitPassword(submitted)
  }

  Keys.onPressed: function(event) {
    if (!lock) return
    lock.wakeRequested()
    if (event.key === Qt.Key_Escape || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_U)) {
      lock.passwordTextEdited("")
      event.accepted = true
    }
  }
}
