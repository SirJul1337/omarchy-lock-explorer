import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland
import qs.Commons
import "Designs.js" as Designs

Item {
  id: root

  property var shell: null
  property var manifest: null
  property string omarchyPath: ""

  // selected design lives on this plugin's entry in shell.json
  readonly property string pluginId: manifest && manifest.id ? String(manifest.id) : "io.github.sirjul1337.lock-explorer"
  property string designOverride: ""
  readonly property string configuredDesignId: {
    var cfg = shell ? shell.shellConfig : null
    var list = cfg && Array.isArray(cfg.plugins) ? cfg.plugins : []
    for (var i = 0; i < list.length; i++) {
      var entry = list[i]
      if (entry && String(entry.id || "") === pluginId && entry.design) return String(entry.design)
    }
    return Designs.DEFAULT_ID
  }
  readonly property string designId: designOverride.length > 0 ? designOverride : configuredDesignId

  // "all" or an output name (see `omarchy-shell lock monitors`). Other
  // monitors get the companion screen.
  property string inputMonitorOverride: ""
  readonly property string configuredInputMonitor: {
    var cfg = shell ? shell.shellConfig : null
    var list = cfg && Array.isArray(cfg.plugins) ? cfg.plugins : []
    for (var i = 0; i < list.length; i++) {
      var entry = list[i]
      if (entry && String(entry.id || "") === pluginId && entry.inputMonitor) return String(entry.inputMonitor)
    }
    return "all"
  }
  readonly property string inputMonitor: inputMonitorOverride.length > 0 ? inputMonitorOverride : configuredInputMonitor

  // How the lock screen leaves the screen when the password checks out. Off by
  // default, the unlock stays instant until it is turned on. Saved on the
  // plugin entry as `unlock` and `unlockMs`.
  readonly property var unlockAnimations: ["fade", "zoom", "rise", "none"]
  readonly property int defaultUnlockDuration: 400
  property string unlockOverride: ""
  property int unlockDurationOverride: -1
  readonly property string configuredUnlock: {
    var cfg = shell ? shell.shellConfig : null
    var list = cfg && Array.isArray(cfg.plugins) ? cfg.plugins : []
    for (var i = 0; i < list.length; i++) {
      var entry = list[i]
      if (entry && String(entry.id || "") === pluginId && entry.unlock) return String(entry.unlock)
    }
    return "none"
  }
  readonly property int configuredUnlockDuration: {
    var cfg = shell ? shell.shellConfig : null
    var list = cfg && Array.isArray(cfg.plugins) ? cfg.plugins : []
    for (var i = 0; i < list.length; i++) {
      var entry = list[i]
      if (entry && String(entry.id || "") === pluginId && entry.unlockMs !== undefined)
        return Math.max(0, Math.min(2000, Number(entry.unlockMs) || 0))
    }
    return defaultUnlockDuration
  }
  readonly property string unlockAnimation: {
    var value = unlockOverride.length > 0 ? unlockOverride : configuredUnlock
    return unlockAnimations.indexOf(value) === -1 ? "none" : value
  }
  readonly property int unlockDuration: unlockDurationOverride >= 0 ? unlockDurationOverride : configuredUnlockDuration
  readonly property bool unlockAnimated: unlockAnimation !== "none" && unlockDuration > 0

  // Avatar picture for the designs that show the user. The chosen path lives on
  // the plugin entry in shell.json; "none" there means the user cleared it and
  // wants the initial back, an empty setting falls back to the usual dotfiles.
  property string avatarOverride: ""
  readonly property string configuredAvatar: {
    var cfg = shell ? shell.shellConfig : null
    var list = cfg && Array.isArray(cfg.plugins) ? cfg.plugins : []
    for (var i = 0; i < list.length; i++) {
      var entry = list[i]
      if (entry && String(entry.id || "") === pluginId && entry.avatar) return String(entry.avatar)
    }
    return ""
  }
  property string detectedAvatar: ""
  property int avatarVersion: 0
  readonly property string avatarSetting: avatarOverride.length > 0 ? avatarOverride : configuredAvatar
  readonly property string avatarPath: avatarSetting === "none" ? ""
    : (avatarSetting.length > 0 ? avatarSetting : detectedAvatar)
  readonly property string avatarUrl: {
    if (avatarPath.length === 0) return ""
    var encoded = String(avatarPath).split("/").map(encodeURIComponent).join("/")
    return "file://" + encoded + "?v=" + avatarVersion
  }

  readonly property string backgroundUrl: {
    if (backgroundPath.length === 0) return ""
    var encoded = String(backgroundPath).split("/").map(encodeURIComponent).join("/")
    return "file://" + encoded + "?v=" + backgroundVersion
  }

  function showsInput(screen) {
    if (inputMonitor === "all" || !screen) return true
    var names = []
    var screens = Quickshell.screens || []
    for (var i = 0; i < screens.length; i++) if (screens[i] && screens[i].name) names.push(screens[i].name)
    if (names.indexOf(inputMonitor) === -1) return true
    return screen.name === inputMonitor
  }

  function pluginEntry() {
    var cfg = shell ? shell.shellConfig : null
    var list = cfg && Array.isArray(cfg.plugins) ? cfg.plugins : []
    for (var i = 0; i < list.length; i++)
      if (list[i] && String(list[i].id || "") === pluginId) return Util.cloneJson(list[i])
    return {}
  }

  function setInputMonitor(name) {
    var value = String(name || "all")
    inputMonitorOverride = value
    if (shell && typeof shell.updateEntryInline === "function") {
      var current = pluginEntry()
      if (value === "all") delete current.inputMonitor
      else current.inputMonitor = value
      shell.updateEntryInline(pluginId, current)
    }
    logEvent("input-monitor=" + value)
    return true
  }

  function setUnlockAnimation(name) {
    var value = String(name || "").trim().toLowerCase()
    if (unlockAnimations.indexOf(value) === -1) return false

    unlockOverride = value
    if (shell && typeof shell.updateEntryInline === "function") {
      var current = pluginEntry()
      if (value === "none") delete current.unlock
      else current.unlock = value
      shell.updateEntryInline(pluginId, current)
    }
    logEvent("unlock=" + value)
    return true
  }

  function setUnlockDuration(ms) {
    var text = String(ms === undefined ? "" : ms).trim()
    var value = Math.round(Number(text))
    if (text.length === 0 || !isFinite(value) || value < 0 || value > 2000) return false

    unlockDurationOverride = value
    if (shell && typeof shell.updateEntryInline === "function") {
      var current = pluginEntry()
      if (value === defaultUnlockDuration) delete current.unlockMs
      else current.unlockMs = value
      shell.updateEntryInline(pluginId, current)
    }
    logEvent("unlock-ms=" + value)
    return true
  }

  property string previewDesignId: ""
  property string previewTyped: ""
  property string previewFailure: ""
  property bool previewUnlocking: false
  Timer { id: previewFailureTimer; interval: 2500; onTriggered: root.previewFailure = "" }

  // Runs the unlock animation on the preview so it can be seen without locking.
  Timer {
    id: previewUnlockTimer
    interval: Math.max(1, root.unlockDuration + 80)
    repeat: false
    onTriggered: {
      root.previewVisible = false
      root.previewDesignId = ""
      root.previewTyped = ""
      root.previewUnlocking = false
    }
  }

  readonly property string userDesignsDir: home + "/.config/omarchy/lock-designs"
  property int designsRevision: 0

  function rescanUserDesigns() {
    if (!userDesignsProc.running) userDesignsProc.running = true
  }

  // Bumps the revision so every LockHost showing a user design reloads it.
  function reloadDesigns() {
    designsRevision += 1
  }

  readonly property string pluginDir: {
    var u = String(Qt.resolvedUrl("."))
    return decodeURIComponent(u.replace(/^file:\/\//, "")).replace(/\/$/, "")
  }

  signal designCustomized(string id, string path)

  function customizeDesign(id) {
    var d = String(id || "") === "new"
      ? { id: "new", file: "MyDesign.qml", name: "new", template: true }
      : Designs.byId(String(id || ""))
    if (!d) return false
    if (d.path) { designCustomized(d.id, decodeURIComponent(d.path.replace(/^file:\/\//, ""))); return true }
    var source = d.template ? pluginDir + "/extras/lock-designs/" + d.file : pluginDir + "/designs/" + d.file
    if (customizeProc.running) return false
    var importLine = 'import "../plugins/' + pluginId + '/designs"'
    customizeProc.command = ["bash", "-c", customizeScript, "customize", source, userDesignsDir, d.file.replace(/\.qml$/, ""), d.template ? "" : importLine, d.name]
    customizeProc.running = true
    return true
  }

  readonly property string customizeScript: '
set -e
src="$1"; dir="$2"; base="$3"; imp="$4"; name="$5"
mkdir -p "$dir"
target="$dir/$base.qml"; n=2
while [[ -e "$target" ]]; do target="$dir/$base$n.qml"; n=$((n+1)); done
{
  if [[ $name == new ]]; then echo "// New design. Edit it in the explorer (E) or with:"; else echo "// Customized copy of the $name design. Edit it here or with:"; fi
  echo "//   omarchy-shell lock editDesign my-$(basename "$target" .qml | tr "[:upper:]" "[:lower:]")"
  awk -v imp="$imp" \'
    /^import / { last = NR }
    { lines[NR] = $0 }
    END { for (i = 1; i <= NR; i++) { print lines[i]; if (i == last && imp != "") print imp } }
  \' "$src"
} > "$target"
echo "$target"
'

  Process {
    id: customizeProc
    stdout: StdioCollector {
      id: customizeOut
      waitForEnd: true
      onStreamFinished: {
        var target = String(customizeOut.text || "").trim()
        if (target.length === 0) return
        var d = Designs.fromUserFile(target)
        Designs.setUser(Designs.USER.concat([d]))
        root.designsRevision += 1
        root.designCustomized(d.id, target)
        root.rescanUserDesigns()
      }
    }
  }

  // ------------------------------------------------------------------ avatar

  function setAvatar(path) {
    var value = String(path || "").trim()
    if (value.indexOf("file://") === 0) value = decodeURIComponent(value.replace(/^file:\/\//, ""))
    var setting = value.length > 0 ? value : "none"
    avatarOverride = setting
    if (shell && typeof shell.updateEntryInline === "function") {
      var current = pluginEntry()
      current.avatar = setting
      shell.updateEntryInline(pluginId, current)
    }
    avatarVersion += 1
    logEvent("avatar=" + setting)
    return true
  }

  function clearAvatar() {
    return setAvatar("")
  }

  // Back to the detected ~/.face and friends.
  function resetAvatar() {
    avatarOverride = ""
    if (shell && typeof shell.updateEntryInline === "function") {
      var current = pluginEntry()
      delete current.avatar
      shell.updateEntryInline(pluginId, current)
    }
    avatarVersion += 1
    detectAvatar()
    logEvent("avatar=auto")
    return true
  }

  function detectAvatar() {
    if (!detectAvatarProc.running) detectAvatarProc.running = true
  }

  // The desktop file chooser, so picking a picture is a normal file dialog.
  // The explorer grabs the keyboard, so it closes itself before asking for one
  // and comes back when the dialog is answered.
  property bool avatarPickReopens: false
  function pickAvatar(reopenExplorer) {
    if (avatarPickProc.running) return false
    avatarPickReopens = reopenExplorer === true
    avatarPickProc.running = true
    return true
  }

  readonly property string detectAvatarScript: '
for f in "$HOME/.config/omarchy/lock-avatar.png" "$HOME/.config/omarchy/lock-avatar.jpg" \
         "$HOME/.config/omarchy/lock-avatar.jpeg" "$HOME/.config/omarchy/lock-avatar.webp" \
         "$HOME/.face" "$HOME/.face.icon" "/var/lib/AccountsService/icons/$USER"; do
  [[ -f $f ]] && { echo "$f"; exit 0; }
done
'

  Process {
    id: detectAvatarProc
    command: ["bash", "-c", root.detectAvatarScript]
    stdout: StdioCollector {
      id: detectAvatarOut
      waitForEnd: true
      onStreamFinished: {
        var found = String(detectAvatarOut.text || "").trim().split("\n")[0] || ""
        if (found !== root.detectedAvatar) {
          root.detectedAvatar = found
          root.avatarVersion += 1
        }
      }
    }
  }

  Process {
    id: avatarPickProc
    command: ["omarchy-file-select", "--title", "Pick a lock screen avatar", "--extensions", "png jpg jpeg webp"]
    stdout: StdioCollector {
      id: avatarPickOut
      waitForEnd: true
      onStreamFinished: {
        var picked = String(avatarPickOut.text || "").trim().split("\n")[0] || ""
        if (picked.length > 0) root.setAvatar(picked)
        if (root.avatarPickReopens && root.shell && typeof root.shell.summon === "function")
          root.shell.summon(root.pluginId, "{}")
        root.avatarPickReopens = false
      }
    }
  }

  function setDesign(id) {
    var d = Designs.byId(String(id || ""))
    if (!d) return false
    designOverride = d.id
    if (shell && typeof shell.updateEntryInline === "function") {
      var current = pluginEntry()
      current.design = d.id
      shell.updateEntryInline(pluginId, current)
    }
    logEvent("design=" + d.id)
    return true
  }

  readonly property string home: Quickshell.env("HOME")
  readonly property string stateHome: home + "/.local/state"
  readonly property string userName: Quickshell.env("USER") || Quickshell.env("LOGNAME")
  readonly property string currentBackgroundLink: stateHome + "/omarchy/current/background"

  property bool lockRequested: false
  property bool pendingSessionLock: false
  property bool authenticatingPassword: false
  property bool fingerprintAuthenticating: false
  property bool passwordPamConfigured: false
  property bool fingerprintConfigured: false
  property bool previewVisible: false
  property string enteredPassword: ""
  property string pendingPassword: ""
  property string failureMessage: ""
  property int failedAttempts: 0
  property string backgroundPath: ""
  property int backgroundVersion: 0
  property string lastEvent: "init"
  property string lastEventAt: ""
  property bool strandedLock: false
  property bool strandedLockResolved: false
  property bool unlocking: false

  // With `misc:session_lock_xray` the compositor keeps drawing the desktop
  // under the lock surface, so the unlock fades straight into it and the
  // wallpaper the animation otherwise lands on would only be in the way.
  property bool sessionLockXray: false

  readonly property bool locked: lockRequested || sessionLock.locked || sessionLock.secure
  readonly property bool authenticating: authenticatingPassword || fingerprintAuthenticating

  function realScreenCount() {
    var screens = Quickshell.screens || []
    var count = 0

    for (var i = 0; i < screens.length; i++) {
      var screen = screens[i]
      if (screen && screen.name && screen.width > 0 && screen.height > 0) count += 1
    }

    return count
  }

  function hasRealScreen() {
    return realScreenCount() > 0
  }

  function queueSessionLock() {
    pendingSessionLock = true
    if (!sessionLockStabilizeTimer.running) logEvent("lock-pending: screen-stabilizing")
    sessionLockStabilizeTimer.restart()
    if (!pendingSessionLockTimer.running) pendingSessionLockTimer.start()
  }

  function requestSessionLock() {
    if (!lockRequested || sessionLock.locked || sessionLock.secure) return
    if (sessionLockStabilizeTimer.running) return

    if (!hasRealScreen()) {
      if (!pendingSessionLock || lastEvent !== "lock-pending: no-real-screen") logEvent("lock-pending: no-real-screen")
      pendingSessionLock = true
      if (!pendingSessionLockTimer.running) pendingSessionLockTimer.start()
      return
    }

    pendingSessionLock = false
    pendingSessionLockTimer.stop()
    sessionLock.locked = true
  }

  // ext-session-lock outlives its client, and a restart carries no lock over, so
  // a session locked this early is an orphan behind Hyprland's failsafe. Outputs
  // are often still absent here, so ask until the answer means something.
  function checkStrandedLock() {
    if (strandedLockResolved || strandedLockCheckProc.running) return

    // A lock this shell took is nobody's orphan.
    if (locked || lockRequested) {
      strandedLockResolved = true
      return
    }

    strandedLockCheckProc.running = true
  }

  function recoverStrandedLock() {
    if (!strandedLock || locked || !passwordPamConfigured) return

    strandedLock = false
    logEvent("lock-stranded: recovering")
    beginLock()
  }

  function refreshBackground() {
    if (!readlinkProc.running) readlinkProc.running = true
  }

  function refreshFingerprintStatus() {
    if (!fingerprintCheckProc.running) fingerprintCheckProc.running = true
  }

  function refreshSessionLockXray() {
    if (!sessionLockXrayProc.running) sessionLockXrayProc.running = true
  }

  function logEvent(event) {
    lastEvent = event
    lastEventAt = new Date().toISOString()
    console.log("omarchy lock " + lastEventAt + " " + event)
  }

  function resetAuthenticationState() {
    enteredPassword = ""
    pendingPassword = ""
    failureMessage = ""
    failedAttempts = 0
    authenticatingPassword = false
    fingerprintAuthenticating = false
    fingerprintRetryTimer.stop()
    if (passwordPam.active) passwordPam.abort()
    if (fingerprintPam.active) fingerprintPam.abort()
  }

  function beginLock() {
    if (!passwordPamConfigured) {
      logEvent("lock-denied: missing-pam")
      return false
    }

    cancelUnlockAnimation()
    resetAuthenticationState()
    lockRequested = true
    armBlankTimer()
    logEvent("lock-requested")
    queueSessionLock()

    Qt.callLater(function() {
      root.refreshBackground()
      root.refreshFingerprintStatus()
      root.refreshSessionLockXray()
      root.rescanUserDesigns()
    })

    return true
  }

  function finishUnlock() {
    if (!root.locked && !lockRequested) return
    if (unlocking) return

    lockRequested = false
    pendingSessionLock = false
    sessionLockStabilizeTimer.stop()
    pendingSessionLockTimer.stop()
    resetAuthenticationState()
    idleBlankTimer.stop()
    runWake()

    // The surface has to stay up while it animates away -- dropping the lock
    // first takes the screen with it. The timer also releases the lock if the
    // animation never runs, so nothing can leave the session stuck behind it.
    if (unlockAnimated && (sessionLock.locked || sessionLock.secure)) {
      unlocking = true
      logEvent("unlocking=" + unlockAnimation)
      unlockTimer.restart()
      return
    }

    releaseLock()
  }

  function releaseLock() {
    unlockTimer.stop()
    unlocking = false
    sessionLock.locked = false
    logEvent("unlocked")
  }

  function cancelUnlockAnimation() {
    if (!unlocking) return
    unlockTimer.stop()
    unlocking = false
    logEvent("unlock-cancelled")
  }

  function armBlankTimer() {
    idleBlankTimer.armedAt = Date.now()
    idleBlankTimer.restart()
  }

  function runWake() {
    if (!wakeProcess.running) wakeProcess.running = true
    if (lockRequested) armBlankTimer()
  }

  function runBlank() {
    if (!blankProcess.running) blankProcess.running = true
  }

  function submitPassword(value) {
    var password = String(value || "")
    if (!lockRequested || authenticatingPassword || password.length === 0) return

    runWake()
    pendingPassword = password
    failureMessage = ""
    authenticatingPassword = true

    if (!passwordPam.start()) {
      handlePasswordFailure()
      return
    }

    Qt.callLater(respondToPasswordPrompt)
  }

  function respondToPasswordPrompt() {
    if (!authenticatingPassword || !passwordPam.active || !passwordPam.responseRequired) return
    passwordPam.respond(pendingPassword)
  }

  function handlePasswordFailure() {
    if (!lockRequested) return

    authenticatingPassword = false
    enteredPassword = ""
    pendingPassword = ""
    failedAttempts += 1
    failureMessage = "Authentication failed (" + failedAttempts + ")"
    runWake()
  }

  function startFingerprint() {
    if (!lockRequested || !sessionLock.secure || !fingerprintConfigured) return
    if (fingerprintPam.active || fingerprintAuthenticating) return

    fingerprintAuthenticating = true
    if (!fingerprintPam.start()) {
      fingerprintAuthenticating = false
    }
  }

  function handleFingerprintFinished(result) {
    fingerprintAuthenticating = false

    if (!lockRequested) return
    if (result === PamResult.Success) {
      finishUnlock()
    } else if (fingerprintConfigured) {
      fingerprintRetryTimer.restart()
    }
  }

  WlSessionLock {
    id: sessionLock

    locked: false

    onSecureStateChanged: {
      root.logEvent("secure=" + secure)
      if (secure) {
        root.pendingSessionLock = false
        sessionLockStabilizeTimer.stop()
        pendingSessionLockTimer.stop()
        root.startFingerprint()
      }
    }

    onLockStateChanged: {
      root.logEvent("session-locked=" + locked)

      if (locked) {
        root.pendingSessionLock = false
        sessionLockStabilizeTimer.stop()
        pendingSessionLockTimer.stop()
      }

      if (!locked && root.lockRequested) {
        root.lockRequested = false
        root.pendingSessionLock = false
        sessionLockStabilizeTimer.stop()
        pendingSessionLockTimer.stop()
        root.resetAuthenticationState()
        root.runWake()
      }
    }

    WlSessionLockSurface {
      id: lockSurface
      color: Color.background

      UnlockLayer {
        anchors.fill: parent
        animation: root.unlockAnimation
        duration: root.unlockDuration
        active: root.unlocking
        backgroundUrl: root.locked && !root.sessionLockXray ? root.backgroundUrl : ""

        LockHost {
          id: lockView
          anchors.fill: parent
          fadeIn: true
          designId: root.showsInput(lockSurface.screen) ? root.designId : "companion"
          revision: root.designsRevision
          backgroundPath: root.backgroundPath
          backgroundVersion: root.backgroundVersion
          avatarPath: root.avatarPath
          avatarVersion: root.avatarVersion
          fingerprintConfigured: root.fingerprintConfigured
          authenticatingPassword: root.authenticatingPassword
          failureMessage: root.failureMessage
          failedAttempts: root.failedAttempts
          inputEnabled: root.lockRequested
          loadBackground: root.locked
          passwordText: root.enteredPassword
          onPasswordTextEdited: function(password) { root.enteredPassword = password }
          onSubmitPassword: function(password) { root.submitPassword(password) }
          onClearFailureRequested: root.failureMessage = ""
          onWakeRequested: root.runWake()
        }
      }
    }
  }

  PanelWindow {
    id: previewWindow
    visible: root.previewVisible
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-lock-explorer-preview"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    UnlockLayer {
      anchors.fill: parent
      animation: root.unlockAnimation
      duration: root.unlockDuration
      active: root.previewUnlocking

      LockHost {
        anchors.fill: parent
        designId: root.previewDesignId.length > 0 ? root.previewDesignId : root.designId
        revision: root.designsRevision
        backgroundPath: root.backgroundPath
        backgroundVersion: root.backgroundVersion
        avatarPath: root.avatarPath
        avatarVersion: root.avatarVersion
        fingerprintConfigured: root.fingerprintConfigured
        authenticatingPassword: false
        failureMessage: root.previewFailure
        failedAttempts: root.previewFailure.length > 0 ? 1 : 0
        inputEnabled: root.previewVisible && !root.previewUnlocking
        loadBackground: root.previewVisible
        passwordText: root.previewTyped
        onPasswordTextEdited: function(password) { root.previewTyped = password }
      }
    }

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      onClicked: { root.previewVisible = false; root.previewDesignId = "" }
    }
  }

  PamContext {
    id: passwordPam
    config: "omarchy-lock-password"
    user: root.userName

    onResponseRequiredChanged: root.respondToPasswordPrompt()
    onPamMessage: root.respondToPasswordPrompt()

    onCompleted: function(result) {
      root.authenticatingPassword = false
      root.pendingPassword = ""

      if (!root.lockRequested) return
      if (result === PamResult.Success) root.finishUnlock()
      else root.handlePasswordFailure()
    }

    onError: function(error) {
      root.handlePasswordFailure()
    }
  }

  PamContext {
    id: fingerprintPam
    config: "omarchy-lock-fingerprint"
    user: root.userName

    onCompleted: function(result) {
      root.handleFingerprintFinished(result)
    }

    onError: function(error) {
      root.fingerprintAuthenticating = false
      if (root.lockRequested && root.fingerprintConfigured) fingerprintRetryTimer.restart()
    }
  }

  Timer {
    id: unlockTimer
    interval: Math.max(1, root.unlockDuration + 80)
    repeat: false
    onTriggered: root.releaseLock()
  }

  Timer {
    id: fingerprintRetryTimer
    interval: 250
    repeat: false
    onTriggered: root.startFingerprint()
  }

  Process {
    id: userDesignsProc
    command: ["bash", "-c", "ls -1 \"$0\"/*.qml 2>/dev/null", root.userDesignsDir]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var lines = String(text || "").split("\n").filter(function(l) { return l.trim().length > 0 })
        var list = lines.map(function(p) { return Designs.fromUserFile(p.trim()) })
        var before = JSON.stringify(Designs.USER)
        Designs.setUser(list)
        if (JSON.stringify(list) !== before) root.designsRevision += 1
      }
    }
  }

  Process {
    id: readlinkProc
    command: ["readlink", "-f", root.currentBackgroundLink]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var next = String(text || "").trim()
        if (next !== root.backgroundPath) {
          root.backgroundPath = next
          root.backgroundVersion += 1
        }
      }
    }
  }

  Process {
    id: fingerprintCheckProc
    command: ["bash", "-c", "if [[ -f /etc/pam.d/omarchy-lock-fingerprint ]] && command -v fprintd-list >/dev/null 2>&1 && fprintd-list \"$USER\" 2>/dev/null | grep -qi finger; then echo yes; else echo no; fi"]
    stdout: StdioCollector { id: fingerprintCheckStdout; waitForEnd: true }
    onExited: {
      root.fingerprintConfigured = String(fingerprintCheckStdout.text || "").trim() === "yes"
      if (root.lockRequested && root.fingerprintConfigured) root.startFingerprint()
      else if (!root.fingerprintConfigured && fingerprintPam.active) fingerprintPam.abort()
    }
  }

  Process {
    id: sessionLockXrayProc
    command: ["hyprctl", "getoption", "misc:session_lock_xray", "-j"]
    stdout: StdioCollector {
      id: sessionLockXrayOut
      waitForEnd: true
      onStreamFinished: {
        try {
          root.sessionLockXray = JSON.parse(String(sessionLockXrayOut.text || "{}")).bool === true
        } catch (e) {
          root.sessionLockXray = false
        }
      }
    }
  }

  Process {
    id: strandedLockCheckProc
    command: ["bash", "-c", "omarchy-hyprland-session-locked"]
    onExited: function(exitCode) {
      // No output to read the lock off yet.
      if (exitCode === 2) return

      root.strandedLockResolved = true

      // A lock taken while this was in flight is this shell's own.
      root.strandedLock = exitCode === 0 && !root.locked && !root.lockRequested
      root.recoverStrandedLock()
    }
  }

  Process {
    id: wakeProcess
    command: ["bash", "-c", "omarchy-system-wake"]
  }

  Process {
    id: blankProcess
    command: ["bash", "-c", "omarchy-brightness-keyboard off; omarchy-brightness-display off"]
  }

  Timer {
    id: idleBlankTimer
    interval: 5000
    repeat: false
    property double armedAt: 0
    onTriggered: {
      // A countdown frozen by suspend fires right after resume, which would
      // blank the freshly woken unlock screen under the user. Wall-clock time
      // exposes the gap: take a fresh run-up instead of blanking.
      if (Date.now() - armedAt > interval + 2000) {
        root.armBlankTimer()
        return
      }
      // Only a password check in flight should hold the display up. The
      // fingerprint PAM stays armed for the whole lock, so gating on
      // `authenticating` here would keep the panel lit until unlock.
      if (root.lockRequested && !root.authenticatingPassword) root.runBlank()
    }
  }

  Timer {
    id: sessionLockStabilizeTimer
    interval: 500
    repeat: false
    onTriggered: root.requestSessionLock()
  }

  Timer {
    id: pendingSessionLockTimer
    interval: 100
    repeat: true
    onTriggered: root.requestSessionLock()
  }

  Timer {
    id: strandedLockRetryTimer
    interval: 500
    repeat: true
    // Covers the compositor settling; screens coming back re-arm it.
    readonly property int budget: 20
    property int remaining: 20
    running: !root.strandedLockResolved && remaining > 0

    function rearm() {
      if (!root.strandedLockResolved) remaining = budget
    }

    onTriggered: {
      remaining -= 1
      root.checkStrandedLock()
    }
  }

  Connections {
    target: Quickshell
    function onScreensChanged() {
      root.requestSessionLock()

      // A monitor still coming up has no workspace, so cannot answer yet.
      strandedLockRetryTimer.rearm()
      root.checkStrandedLock()
    }
  }

  onAuthenticatingPasswordChanged: {
    if (!lockRequested) return
    if (authenticatingPassword) idleBlankTimer.stop()
    else armBlankTimer()
  }

  FileView {
    path: "/etc/pam.d/omarchy-lock-password"
    watchChanges: true
    printErrors: false
    onLoaded: root.passwordPamConfigured = true
    onLoadFailed: root.passwordPamConfigured = false
    onFileChanged: reload()
  }

  // No lock before PAM is known good. An answer from before then may be stale --
  // the failsafe can be cleared from a TTY -- so re-ask rather than act on it.
  onPasswordPamConfiguredChanged: {
    if (!passwordPamConfigured) return

    strandedLock = false
    strandedLockResolved = false
    strandedLockRetryTimer.rearm()
    checkStrandedLock()
  }

  Component.onCompleted: {
    refreshBackground()
    refreshFingerprintStatus()
    refreshSessionLockXray()
    rescanUserDesigns()
    detectAvatar()
    checkStrandedLock()
  }

  IpcHandler {
    target: "lock"

    function lock(): string {
      if (!root.passwordPamConfigured) return "missing-pam"
      if (!root.locked && !root.beginLock()) return "failed"
      return "ok"
    }

    function isLocked(): string {
      return root.locked ? "true" : "false"
    }

    function status(): string {
      return JSON.stringify({
        locked: root.locked,
        requested: root.lockRequested,
        pending: root.pendingSessionLock,
        sessionLocked: sessionLock.locked,
        secure: sessionLock.secure,
        realScreens: root.realScreenCount(),
        passwordPam: root.passwordPamConfigured,
        fingerprint: root.fingerprintConfigured,
        authenticating: root.authenticating,
        lastEvent: root.lastEvent,
        lastEventAt: root.lastEventAt,
        design: root.designId,
        unlock: root.unlockAnimation,
        unlockMs: root.unlockDuration,
        unlockAnimated: root.unlockAnimated,
        unlocking: root.unlocking,
        previewTyped: root.previewTyped.length
      })
    }

    function preview(): string {
      root.previewUnlocking = false
      root.refreshBackground()
      root.refreshFingerprintStatus()
      root.previewVisible = true
      return "ok"
    }

    function hidePreview(): string {
      previewUnlockTimer.stop()
      root.previewUnlocking = false
      root.previewVisible = false
      root.previewDesignId = ""
      root.previewTyped = ""
      return "ok"
    }

    function design(): string {
      return root.designId
    }

    function designs(): string {
      return JSON.stringify(Designs.all().map(function(d) {
        return { id: d.id, name: d.name, description: d.description, active: d.id === root.designId }
      }))
    }

    function setDesign(id: string): string {
      return root.setDesign(id) ? "ok" : "unknown-design"
    }

    function previewDesign(id: string): string {
      root.rescanUserDesigns()
      if (!Designs.byId(String(id || ""))) return "unknown-design"
      root.previewDesignId = String(id)
      root.previewUnlocking = false
      root.refreshBackground()
      root.refreshFingerprintStatus()
      root.previewVisible = true
      return "ok"
    }

    function monitors(): string {
      var screens = Quickshell.screens || []
      return JSON.stringify(screens.map(function(s) { return { name: s.name, width: s.width, height: s.height, input: root.showsInput(s) } }))
    }

    function inputMonitor(): string {
      return root.inputMonitor
    }

    function setInputMonitor(name: string): string {
      return root.setInputMonitor(name) ? "ok" : "failed"
    }

    function unlockAnimation(): string {
      return root.unlockAnimated ? root.unlockAnimation + " " + root.unlockDuration + "ms" : "none"
    }

    function setUnlockAnimation(name: string): string {
      return root.setUnlockAnimation(name) ? "ok" : "unknown-animation"
    }

    function setUnlockDuration(ms: string): string {
      return root.setUnlockDuration(ms) ? "ok" : "out-of-range"
    }

    function previewUnlock(): string {
      if (!root.previewVisible) return "no-preview"
      if (!root.unlockAnimated) {
        root.previewVisible = false
        root.previewDesignId = ""
        root.previewTyped = ""
        return "ok"
      }
      root.previewUnlocking = true
      previewUnlockTimer.restart()
      return "ok"
    }

    function previewFail(): string {
      root.previewFailure = ""
      root.previewFailure = "Authentication failed (1)"
      previewFailureTimer.restart()
      return "ok"
    }

    function customize(id: string): string {
      return root.customizeDesign(id) ? "ok" : "unknown-design"
    }

    function editDesign(id: string): string {
      var d = Designs.byId(String(id || ""))
      if (!d || !d.path) return "not-a-custom-design"
      Quickshell.execDetached(["omarchy-launch-editor", decodeURIComponent(d.path.replace(/^file:\/\//, ""))])
      return "ok"
    }

    function reloadDesigns(): string {
      root.reloadDesigns()
      return "ok"
    }

    function rescanDesigns(): string {
      root.rescanUserDesigns()
      return "ok"
    }

    function avatar(): string {
      return root.avatarPath
    }

    function setAvatar(path: string): string {
      return root.setAvatar(path) ? "ok" : "failed"
    }

    function clearAvatar(): string {
      return root.clearAvatar() ? "ok" : "failed"
    }

    function resetAvatar(): string {
      return root.resetAvatar() ? "ok" : "failed"
    }

    function pickAvatar(): string {
      return root.pickAvatar(false) ? "ok" : "busy"
    }

    function explore(): string {
      root.rescanUserDesigns()
      if (root.shell && typeof root.shell.summon === "function")
        return root.shell.summon(root.pluginId, "{}") ? "ok" : "failed"
      return "no-shell"
    }
  }
}
