import QtQuick
import Quickshell.Io
import "Designs.js" as Designs

Item {
  id: host

  property string designId: Designs.DEFAULT_ID
  property int revision: 0
  property bool fadeIn: false

  property string backgroundPath: ""
  property int backgroundVersion: 0
  property string avatarPath: ""
  property int avatarVersion: 0
  property bool fingerprintConfigured: false
  property bool authenticatingPassword: false
  property string failureMessage: ""
  property int failedAttempts: 0
  property bool inputEnabled: true
  property bool loadBackground: true
  property string passwordText: ""
  property string videoPath: ""
  property bool videoPlaying: true
  property bool unlockPlayback: false
  property real clipSpeed: 1

  signal submitPassword(string password)
  signal passwordTextEdited(string password)
  signal clearFailureRequested()
  signal wakeRequested()
  signal unlockFinished()

  readonly property var design: {
    var r = revision
    return Designs.resolve(designId)
  }
  readonly property bool isUserDesign: design && design.path ? true : false
  readonly property string userLocalPath: isUserDesign ? decodeURIComponent(String(design.path).replace(/^file:\/\//, "")) : ""
  property Item userItem: null
  readonly property Item item: userItem !== null ? userItem : loader.item
  readonly property bool ready: item !== null
  property string loadError: ""
  // A broken design must never leave a locked screen without a password
  // field: a failed user design or built-in falls back to Classic through the
  // Loader, and if even that fails the emergency field at the bottom of this
  // file still takes the password.
  property bool designFallback: false

  opacity: fadeIn ? 0 : 1
  Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
  Component.onCompleted: if (fadeIn) opacity = 1

  function forcePasswordFocus() {
    if (item && typeof item.forcePasswordFocus === "function") { item.forcePasswordFocus(); return }
    if (!ready) emergencyInput.forceActiveFocus()
  }

  onDesignIdChanged: designFallback = false

  function attach(it) {
    it.backgroundPath = Qt.binding(function() { return host.backgroundPath })
    it.backgroundVersion = Qt.binding(function() { return host.backgroundVersion })
    it.avatarPath = Qt.binding(function() { return host.avatarPath })
    it.avatarVersion = Qt.binding(function() { return host.avatarVersion })
    it.fingerprintConfigured = Qt.binding(function() { return host.fingerprintConfigured })
    it.authenticatingPassword = Qt.binding(function() { return host.authenticatingPassword })
    it.failureMessage = Qt.binding(function() { return host.failureMessage })
    it.failedAttempts = Qt.binding(function() { return host.failedAttempts })
    it.inputEnabled = Qt.binding(function() { return host.inputEnabled })
    it.loadBackground = Qt.binding(function() { return host.loadBackground })
    it.passwordText = Qt.binding(function() { return host.passwordText })
    if (it.videoPath !== undefined) it.videoPath = Qt.binding(function() { return host.videoPath })
    if (it.videoPlaying !== undefined) it.videoPlaying = Qt.binding(function() { return host.videoPlaying })
    if (it.unlockPlayback !== undefined) it.unlockPlayback = Qt.binding(function() { return host.unlockPlayback })
    if (it.clipSpeed !== undefined) it.clipSpeed = Qt.binding(function() { return host.clipSpeed })
  }

  // Built-in designs come through the Loader; it also carries the Classic
  // fallback when the selected design (user or built-in) failed to load.
  Loader {
    id: loader
    anchors.fill: parent
    source: {
      if (host.designFallback) return Qt.resolvedUrl("designs/Classic.qml")
      if (host.design && !host.isUserDesign) return Qt.resolvedUrl("designs/" + host.design.file)
      return ""
    }
    onLoaded: host.attach(item)
    onStatusChanged: {
      if (status === Loader.Error) {
        host.loadError = sourceComponent ? sourceComponent.errorString() : "failed to load"
        console.warn("lock-explorer: failed to load design", host.designId, host.loadError)
        // One step down, never a loop: Classic failing too leaves the
        // emergency field.
        if (!host.designFallback) host.designFallback = true
      } else if (status === Loader.Ready && !host.designFallback) {
        host.loadError = ""
      }
    }
  }

  // User designs are compiled from their file contents so edits and new files
  // are picked up without a shell restart.
  Item {
    id: userContainer
    anchors.fill: parent
  }

  FileView {
    id: userFile
    path: host.userLocalPath
    printErrors: false
    onLoaded: host.rebuildUser()
    onLoadFailed: { host.loadError = "Cannot read " + host.userLocalPath }
  }

  onRevisionChanged: if (isUserDesign && userLocalPath.length > 0) userFile.reload()

  function rebuildUser() {
    if (userItem) { userItem.destroy(); userItem = null }
    if (!isUserDesign) return
    try {
      var obj = Qt.createQmlObject(userFile.text(), userContainer, design.path)
      obj.anchors.fill = userContainer
      attach(obj)
      userItem = obj
      loadError = ""
      designFallback = false
      if (inputEnabled) Qt.callLater(forcePasswordFocus)
    } catch (e) {
      var msg = String(e)
      if (e.qmlErrors && e.qmlErrors.length) {
        msg = e.qmlErrors.map(function(err) { return err.fileName.split("/").pop() + ":" + err.lineNumber + ": " + err.message }).join("\n")
      }
      loadError = msg
      designFallback = true
      console.warn("lock-explorer: failed to load design", designId, msg)
    }
  }

  onIsUserDesignChanged: if (!isUserDesign && userItem) { userItem.destroy(); userItem = null }

  Connections {
    target: host.item
    ignoreUnknownSignals: true
    function onSubmitPassword(password) { host.submitPassword(password) }
    function onPasswordTextEdited(password) { host.passwordTextEdited(password) }
    function onClearFailureRequested() { host.clearFailureRequested() }
    function onWakeRequested() { host.wakeRequested() }
    function onUnlockFinished() { host.unlockFinished() }
  }

  // Last line of defense: if nothing rendered at all — the design AND the
  // Classic fallback both failed — this bare field with no dependencies
  // outside QtQuick still takes the password, so a locked screen can always
  // be unlocked.
  Rectangle {
    visible: !host.ready
    anchors.fill: parent
    color: "#16181c"
    onVisibleChanged: if (visible && host.inputEnabled) emergencyInput.forceActiveFocus()

    Column {
      anchors.centerIn: parent
      spacing: 16
      width: 420

      Text {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: "The lock screen design failed to load"
        color: "#dddddd"
        font.pixelSize: 18
      }

      Rectangle {
        width: parent.width
        height: 52
        radius: 8
        color: "#24272c"
        border.width: 1
        border.color: host.failureMessage.length > 0 ? "#c96a6a" : "#565b63"

        TextInput {
          id: emergencyInput
          anchors.fill: parent
          anchors.margins: 14
          verticalAlignment: TextInput.AlignVCenter
          echoMode: TextInput.Password
          passwordCharacter: "●"
          color: "#eeeeee"
          font.pixelSize: 18
          enabled: host.inputEnabled && !host.authenticatingPassword
          onTextChanged: host.passwordTextEdited(text)
          onAccepted: host.submitPassword(text)
        }
      }

      Text {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        text: host.failureMessage.length > 0 ? host.failureMessage
          : (host.authenticatingPassword ? "Checking…"
          : "Type your password and press Enter" + (host.loadError.length > 0 ? "\n\n" + host.loadError : ""))
        color: host.failureMessage.length > 0 ? "#c96a6a" : "#8a9099"
        font.pixelSize: 12
      }
    }

    Connections {
      target: host
      function onPasswordTextChanged() {
        if (emergencyInput.text !== host.passwordText) emergencyInput.text = host.passwordText
      }
    }
  }
}
