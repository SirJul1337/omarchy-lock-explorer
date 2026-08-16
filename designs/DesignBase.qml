import QtQuick
import Quickshell
import Quickshell.Io

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
    if (inputItem) inputItem.forceActiveFocus()
  }

  function clearPassword() {
    passwordTextEdited("")
  }

  onInputEnabledChanged: if (inputEnabled) Qt.callLater(forcePasswordFocus)
  Component.onCompleted: if (inputEnabled) Qt.callLater(forcePasswordFocus)
}
