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

  signal submitPassword(string password)
  signal passwordTextEdited(string password)
  signal clearFailureRequested()
  signal wakeRequested()

  readonly property var design: {
    var r = revision
    return Designs.resolve(designId)
  }
  readonly property bool isUserDesign: design && design.path ? true : false
  readonly property string userLocalPath: isUserDesign ? decodeURIComponent(String(design.path).replace(/^file:\/\//, "")) : ""
  property Item userItem: null
  readonly property Item item: isUserDesign ? userItem : loader.item
  readonly property bool ready: item !== null
  property string loadError: ""

  opacity: fadeIn ? 0 : 1
  Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
  Component.onCompleted: if (fadeIn) opacity = 1

  function forcePasswordFocus() {
    if (item && typeof item.forcePasswordFocus === "function") item.forcePasswordFocus()
  }

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
  }

  // Built-in designs come through the Loader.
  Loader {
    id: loader
    anchors.fill: parent
    source: host.design && !host.isUserDesign ? Qt.resolvedUrl("designs/" + host.design.file) : ""
    onLoaded: host.attach(item)
    onStatusChanged: {
      if (status === Loader.Error) {
        host.loadError = sourceComponent ? sourceComponent.errorString() : "failed to load"
        console.warn("lock-explorer: failed to load design", host.designId, host.loadError)
      } else if (status === Loader.Ready) {
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
      if (inputEnabled) Qt.callLater(forcePasswordFocus)
    } catch (e) {
      var msg = String(e)
      if (e.qmlErrors && e.qmlErrors.length) {
        msg = e.qmlErrors.map(function(err) { return err.fileName.split("/").pop() + ":" + err.lineNumber + ": " + err.message }).join("\n")
      }
      loadError = msg
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
  }
}
