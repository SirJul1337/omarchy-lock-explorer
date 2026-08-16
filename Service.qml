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
  property string previewDesignId: ""
  property string previewTyped: ""
  property string previewFailure: ""
  Timer { id: previewFailureTimer; interval: 2500; onTriggered: root.previewFailure = "" }

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

    resetAuthenticationState()
    lockRequested = true
    armBlankTimer()
    logEvent("lock-requested")
    queueSessionLock()

    Qt.callLater(function() {
      root.refreshBackground()
      root.refreshFingerprintStatus()
      root.rescanUserDesigns()
    })

    return true
  }

  function finishUnlock() {
    if (!root.locked && !lockRequested) return

    lockRequested = false
    pendingSessionLock = false
    sessionLockStabilizeTimer.stop()
    pendingSessionLockTimer.stop()
    resetAuthenticationState()
    idleBlankTimer.stop()
    sessionLock.locked = false
    logEvent("unlocked")
    runWake()
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

      LockHost {
        id: lockView
        anchors.fill: parent
        fadeIn: true
        designId: root.showsInput(lockSurface.screen) ? root.designId : "companion"
        revision: root.designsRevision
        backgroundPath: root.backgroundPath
        backgroundVersion: root.backgroundVersion
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

  PanelWindow {
    id: previewWindow
    visible: root.previewVisible
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-lock-explorer-preview"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    LockHost {
      anchors.fill: parent
      designId: root.previewDesignId.length > 0 ? root.previewDesignId : root.designId
      revision: root.designsRevision
      backgroundPath: root.backgroundPath
      backgroundVersion: root.backgroundVersion
      fingerprintConfigured: root.fingerprintConfigured
      authenticatingPassword: false
      failureMessage: root.previewFailure
      failedAttempts: root.previewFailure.length > 0 ? 1 : 0
      inputEnabled: root.previewVisible
      loadBackground: root.previewVisible
      passwordText: root.previewTyped
      onPasswordTextEdited: function(password) { root.previewTyped = password }
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
    rescanUserDesigns()
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
        previewTyped: root.previewTyped.length
      })
    }

    function preview(): string {
      root.refreshBackground()
      root.refreshFingerprintStatus()
      root.previewVisible = true
      return "ok"
    }

    function hidePreview(): string {
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

    function explore(): string {
      root.rescanUserDesigns()
      if (root.shell && typeof root.shell.summon === "function")
        return root.shell.summon(root.pluginId, "{}") ? "ok" : "failed"
      return "no-shell"
    }
  }
}
