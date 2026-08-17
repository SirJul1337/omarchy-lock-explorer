import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
  id: base

  property string backgroundPath: ""
  property int backgroundVersion: 0
  property bool fingerprintConfigured: false
  property bool authenticatingPassword: false
  property string failureMessage: ""
  property int failedAttempts: 0
  property bool inputEnabled: true
  property bool loadBackground: true
  property string passwordText: ""

  signal submitPassword(string password)
  signal passwordTextEdited(string password)
  signal clearFailureRequested()
  signal wakeRequested()

  readonly property bool errorState: failureMessage.length > 0
  readonly property string userName: Quickshell.env("USER") || Quickshell.env("LOGNAME") || "user"
  readonly property string userInitial: userName.length > 0 ? userName.charAt(0).toUpperCase() : "?"
  property string hostName: Quickshell.env("HOSTNAME") || Quickshell.env("HOST") || "omarchy"
  FileView {
    path: "/etc/hostname"
    printErrors: false
    onLoaded: {
      var h = String(text() || "").trim()
      if (h.length > 0) base.hostName = h
    }
  }

  property Item inputItem: null
  property bool shakeOnFail: false
  property bool flashOnFail: true

  // Show/hide password toggle. Designs can turn the button off with
  // showPasswordToggle: false. Resets to hidden on a failed attempt and
  // when the field is cleared.
  property bool showPasswordToggle: true
  property bool passwordVisible: false
  function togglePasswordVisible() { passwordVisible = !passwordVisible }
  onPasswordTextChanged: if (passwordText.length === 0) passwordVisible = false

  transform: Translate { id: shakeTranslate }
  SequentialAnimation {
    id: shakeAnim
    NumberAnimation { target: shakeTranslate; property: "x"; from: 0; to: -14; duration: 40 }
    NumberAnimation { target: shakeTranslate; property: "x"; from: -14; to: 12; duration: 70 }
    NumberAnimation { target: shakeTranslate; property: "x"; from: 12; to: -8; duration: 60 }
    NumberAnimation { target: shakeTranslate; property: "x"; from: -8; to: 4; duration: 50 }
    NumberAnimation { target: shakeTranslate; property: "x"; from: 4; to: 0; duration: 40 }
  }
  Rectangle {
    id: failFlash
    anchors.fill: parent
    z: 1000
    color: Color.lock.textError
    opacity: 0
    visible: opacity > 0
  }
  SequentialAnimation {
    id: flashAnim
    NumberAnimation { target: failFlash; property: "opacity"; from: 0; to: 0.22; duration: 80 }
    NumberAnimation { target: failFlash; property: "opacity"; from: 0.22; to: 0; duration: 380; easing.type: Easing.OutCubic }
  }
  onFailureMessageChanged: {
    if (failureMessage.length === 0) return
    passwordVisible = false
    if (flashOnFail) flashAnim.restart()
    if (shakeOnFail) shakeAnim.restart()
  }

  property date now: new Date()
  Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: base.now = new Date()
  }

  function greeting() {
    var h = now.getHours()
    if (h < 5) return "Good night"
    if (h < 12) return "Good morning"
    if (h < 18) return "Good afternoon"
    return "Good evening"
  }

  function fileUrl(path) {
    if (!path) return ""
    var encoded = String(path).split("/").map(encodeURIComponent).join("/")
    return "file://" + encoded + "?v=" + backgroundVersion
  }

  function withAlpha(c, a) {
    return Qt.rgba(c.r, c.g, c.b, a)
  }

  function forcePasswordFocus() {
    if (inputEnabled && inputItem) inputItem.forceActiveFocus()
  }

  function clearPassword() {
    passwordTextEdited("")
  }

  onInputEnabledChanged: if (inputEnabled) Qt.callLater(forcePasswordFocus)
  Component.onCompleted: if (inputEnabled) Qt.callLater(forcePasswordFocus)
}
