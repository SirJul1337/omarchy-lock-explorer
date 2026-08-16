import QtQuick
import "Designs.js" as Designs

Item {
  id: host

  property string designId: Designs.DEFAULT_ID

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

  readonly property var design: Designs.resolve(designId)
  readonly property bool ready: loader.status === Loader.Ready

  function forcePasswordFocus() {
    if (loader.item && typeof loader.item.forcePasswordFocus === "function") loader.item.forcePasswordFocus()
  }

  Loader {
    id: loader
    anchors.fill: parent
    source: host.design ? Qt.resolvedUrl("designs/" + host.design.file) : ""

    onLoaded: {
      var it = item
      it.backgroundPath = Qt.binding(function() { return host.backgroundPath })
      it.backgroundVersion = Qt.binding(function() { return host.backgroundVersion })
      it.fingerprintConfigured = Qt.binding(function() { return host.fingerprintConfigured })
      it.authenticatingPassword = Qt.binding(function() { return host.authenticatingPassword })
      it.failureMessage = Qt.binding(function() { return host.failureMessage })
      it.failedAttempts = Qt.binding(function() { return host.failedAttempts })
      it.inputEnabled = Qt.binding(function() { return host.inputEnabled })
      it.loadBackground = Qt.binding(function() { return host.loadBackground })
      it.passwordText = Qt.binding(function() { return host.passwordText })
    }

    onStatusChanged: {
      if (status === Loader.Error)
        console.warn("lock-explorer: failed to load design", host.designId, sourceComponent ? sourceComponent.errorString() : "")
    }
  }

  Connections {
    target: loader.item
    ignoreUnknownSignals: true
    function onSubmitPassword(password) { host.submitPassword(password) }
    function onPasswordTextEdited(password) { host.passwordTextEdited(password) }
    function onClearFailureRequested() { host.clearFailureRequested() }
    function onWakeRequested() { host.wakeRequested() }
  }
}
