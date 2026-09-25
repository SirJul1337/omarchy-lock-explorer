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
  property bool faceConfigured: false
  property bool fido2Configured: false
  property bool fido2Active: false
  property bool fido2Authenticating: false
  property bool fido2NeedsPin: false
  property string fido2Status: ""
  property string fingerprintStatus: ""
  property bool fingerprintStatusIsError: false
  property bool authenticatingPassword: false
  property string failureMessage: ""
  property int failedAttempts: 0
  property bool inputEnabled: true
  property bool inputBlocked: false
  property string keyboardLayout: ""
  property bool capsLock: false
  signal capsProbeRequested()
  property bool powerActions: false
  signal powerActionRequested(string action)
  property bool loadBackground: true
  property string passwordText: ""
  property string videoPath: ""
  property bool videoPlaying: true
  // False while the display is blanked. Designs stop animating then: the
  // panel is off, and a laptop should not spend its battery on a picture
  // nobody can see.
  property bool screenAwake: true
  property bool unlockPlayback: false
  property real clipSpeed: 1
  // 12-hour clocks with AM/PM, see `omarchy-shell lock setClockFormat`.
  property bool twelveHour: false
  // The wallpaper setting: a blur that replaces the design's (-1 keeps it)
  // and a shift on the design's own dim. Wallpaper reads both off the design.
  property real wallpaperBlur: -1
  property real wallpaperDim: 0
  // Size (see `omarchy-shell lock setSize`): the design is laid out on a
  // screen this many times smaller and drawn back up to fill this one, so
  // every text, field and picture in it grows and it still fits.
  property real uiScale: 1
  // Reduce motion (see `omarchy-shell lock setReduceMotion`): the design runs
  // as always underneath, keyboard and all, but what is shown is a still frame
  // of it, taken once it has settled and again whenever something it says
  // changes -- a typed character, a failed attempt, the minute on the clock.
  property bool holdStill: false
  // The design's language, see Strings.js.
  property string language: "en"
  // Pixel size of that frame; the explorer's small previews ask for less.
  property size stillTextureSize: Qt.size(0, 0)
  property bool stillReady: false

  signal submitPassword(string password)
  signal passwordTextEdited(string password)
  signal clearFailureRequested()
  signal wakeRequested()
  signal faceRequested()
  signal fido2Requested()
  signal passwordRequested()
  signal submitFido2Pin(string pin)
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
    it.faceConfigured = Qt.binding(function() { return host.faceConfigured })
    it.fido2Configured = Qt.binding(function() { return host.fido2Configured })
    it.fido2Active = Qt.binding(function() { return host.fido2Active })
    it.fido2Authenticating = Qt.binding(function() { return host.fido2Authenticating })
    it.fido2NeedsPin = Qt.binding(function() { return host.fido2NeedsPin })
    it.fido2Status = Qt.binding(function() { return host.fido2Status })
    if (it.fingerprintStatus !== undefined) it.fingerprintStatus = Qt.binding(function() { return host.fingerprintStatus })
    if (it.fingerprintStatusIsError !== undefined) it.fingerprintStatusIsError = Qt.binding(function() { return host.fingerprintStatusIsError })
    it.authenticatingPassword = Qt.binding(function() { return host.authenticatingPassword })
    it.failureMessage = Qt.binding(function() { return host.failureMessage })
    it.failedAttempts = Qt.binding(function() { return host.failedAttempts })
    it.inputEnabled = Qt.binding(function() { return host.inputEnabled })
    if (it.inputBlocked !== undefined) it.inputBlocked = Qt.binding(function() { return host.inputBlocked })
    if (it.keyboardLayout !== undefined) it.keyboardLayout = Qt.binding(function() { return host.keyboardLayout })
    if (it.capsLock !== undefined) it.capsLock = Qt.binding(function() { return host.capsLock })
    if (it.powerActions !== undefined) it.powerActions = Qt.binding(function() { return host.powerActions })
    it.loadBackground = Qt.binding(function() { return host.loadBackground })
    it.passwordText = Qt.binding(function() { return host.passwordText })
    if (it.videoPath !== undefined) it.videoPath = Qt.binding(function() { return host.videoPath })
    if (it.videoPlaying !== undefined) it.videoPlaying = Qt.binding(function() { return host.videoPlaying })
    if (it.screenAwake !== undefined) it.screenAwake = Qt.binding(function() { return host.screenAwake })
    if (it.unlockPlayback !== undefined) it.unlockPlayback = Qt.binding(function() { return host.unlockPlayback })
    if (it.clipSpeed !== undefined) it.clipSpeed = Qt.binding(function() { return host.clipSpeed })
    if (it.twelveHour !== undefined) it.twelveHour = Qt.binding(function() { return host.twelveHour })
    if (it.wallpaperBlur !== undefined) it.wallpaperBlur = Qt.binding(function() { return host.wallpaperBlur })
    if (it.wallpaperDim !== undefined) it.wallpaperDim = Qt.binding(function() { return host.wallpaperDim })
    if (it.language !== undefined) it.language = Qt.binding(function() { return host.language })
  }

  Item {
    id: stage
    width: host.width / host.uiScale
    height: host.height / host.uiScale
    scale: host.uiScale
    transformOrigin: Item.TopLeft

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
  }

  ShaderEffectSource {
    id: stillFrame
    anchors.fill: parent
    sourceItem: stage
    live: false
    hideSource: host.holdStill && host.stillReady
    visible: host.holdStill && host.stillReady
    textureSize: host.stillTextureSize.width > 0 ? host.stillTextureSize
                 : Qt.size(Math.ceil(host.width * Screen.devicePixelRatio), Math.ceil(host.height * Screen.devicePixelRatio))
  }

  // A design animates in, and many animate what changed (dots popping in, a
  // shake on a wrong password): the first frame waits for that, and each
  // change is taken twice, once straight after and once when it has settled.
  function restill() {
    stillReady = false
    if (holdStill) settleTimer.restart()
  }
  function regrab() {
    if (!holdStill || !stillReady) return
    quickGrab.restart()
    lateGrab.restart()
  }
  onHoldStillChanged: restill()
  onItemChanged: restill()
  onUiScaleChanged: regrab()
  Timer { id: settleTimer; interval: 2500; onTriggered: { stillFrame.scheduleUpdate(); host.stillReady = true } }
  Timer { id: quickGrab; interval: 120; onTriggered: stillFrame.scheduleUpdate() }
  Timer { id: lateGrab; interval: 700; onTriggered: stillFrame.scheduleUpdate() }
  Timer {
    property int minute: -1
    running: host.holdStill
    repeat: true
    interval: 1000
    onTriggered: {
      var m = new Date().getMinutes()
      if (m !== minute) { minute = m; host.regrab() }
    }
  }
  Connections {
    target: host
    function onPasswordTextChanged() { host.regrab() }
    function onFailureMessageChanged() { host.regrab() }
    function onFailedAttemptsChanged() { host.regrab() }
    function onAuthenticatingPasswordChanged() { host.regrab() }
    function onFingerprintStatusChanged() { host.regrab() }
    function onFido2StatusChanged() { host.regrab() }
    function onFido2ActiveChanged() { host.regrab() }
    function onCapsLockChanged() { host.regrab() }
    function onKeyboardLayoutChanged() { host.regrab() }
    function onInputBlockedChanged() { host.regrab() }
    function onTwelveHourChanged() { host.regrab() }
    function onWallpaperBlurChanged() { host.regrab() }
    function onWallpaperDimChanged() { host.regrab() }
    function onBackgroundVersionChanged() { host.restill() }
    function onAvatarVersionChanged() { host.regrab() }
    function onLanguageChanged() { host.regrab() }
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
    function onFaceRequested() { host.faceRequested() }
    function onFido2Requested() { host.fido2Requested() }
    function onPasswordRequested() { host.passwordRequested() }
    function onSubmitFido2Pin(pin) { host.submitFido2Pin(pin) }
    function onPowerActionRequested(action) { host.powerActionRequested(action) }
    function onCapsProbeRequested() { host.capsProbeRequested() }
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
          readOnly: host.inputBlocked
          Keys.onPressed: host.wakeRequested()
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
        textFormat: Text.PlainText
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
