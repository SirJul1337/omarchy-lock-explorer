import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
  id: base

  property string backgroundPath: ""
  property int backgroundVersion: 0
  property string avatarPath: ""
  property int avatarVersion: 0
  property bool fingerprintConfigured: false
  property bool faceConfigured: false
  property bool authenticatingPassword: false
  property string failureMessage: ""
  property int failedAttempts: 0
  property bool inputEnabled: true
  property bool loadBackground: true
  property string passwordText: ""

  // Set with `omarchy-shell lock setVideo`. Designs show it with VideoWallpaper,
  // which keeps the still wallpaper underneath when there is none. videoPlaying
  // goes false while the screen is blanked so nothing decodes into a dark panel.
  property string videoPath: ""
  property bool videoPlaying: true

  // Raised by the service instead of dropping the lock when the design is
  // built around a clip (see UnlockClip): the clip plays through and
  // unlockFinished() hands the screen back.
  property bool unlockPlayback: false
  // Playback rate for unlock clips, see `omarchy-shell lock setClipSpeed`.
  property real clipSpeed: 1
  signal unlockFinished()

  signal submitPassword(string password)
  signal passwordTextEdited(string password)
  signal clearFailureRequested()
  signal wakeRequested()
  signal faceRequested()

  readonly property bool errorState: failureMessage.length > 0
  readonly property string userName: Quickshell.env("USER") || Quickshell.env("LOGNAME") || "user"
  readonly property string userInitial: userName.length > 0 ? userName.charAt(0).toUpperCase() : "?"

  // Set with `omarchy-shell lock pickAvatar` or the A key in the explorer.
  // Designs show it with Avatar, which falls back to userInitial when unset.
  readonly property bool hasAvatar: avatarPath.length > 0
  readonly property string avatarUrl: {
    if (avatarPath.length === 0) return ""
    var encoded = String(avatarPath).split("/").map(encodeURIComponent).join("/")
    return "file://" + encoded + "?v=" + avatarVersion
  }

  readonly property bool hasVideo: videoPath.length > 0
  readonly property string videoUrl: {
    if (videoPath.length === 0) return ""
    var encoded = String(videoPath).split("/").map(encodeURIComponent).join("/")
    return "file://" + encoded
  }
  property string hostName: Quickshell.env("HOSTNAME") || Quickshell.env("HOST") || "omarchy"
  // Other accounts on this machine, for designs that offer a switch. Read
  // straight out of /etc/passwd, so it costs nothing on a single-user box:
  // the list comes back empty and a design that renders it collapses to the
  // layout it already had.
  //
  // Selecting someone here only moves the highlight. Authenticating AS them
  // needs Service.qml to point its PamContext at the chosen name, which is a
  // separate change with its own security review -- see extras/multi-user-designs.md.
  property var otherUsers: []
  readonly property bool hasOtherUsers: otherUsers.length > 0
  // -1 is this session's owner, the account the lock screen belongs to.
  property int selectedUser: -1
  readonly property string selectedName: {
    if (selectedUser < 0 || selectedUser >= otherUsers.length) return userName
    return otherUsers[selectedUser].name
  }
  readonly property bool switchingAway: selectedUser >= 0

  // AccountsService is the only per-user picture that is readable from here;
  // a missing file just leaves Avatar on its initial, so no probing is needed.
  function avatarUrlFor(name) {
    return "file:///var/lib/AccountsService/icons/" + encodeURIComponent(name)
  }

  FileView {
    path: "/etc/passwd"
    printErrors: false
    onLoaded: {
      var found = []
      var lines = String(text() || "").split("\n")
      for (var i = 0; i < lines.length; i++) {
        var f = lines[i].split(":")
        if (f.length < 7) continue
        var uid = parseInt(f[2], 10)
        // regular login accounts only: system users sit below 1000 and nobody is 65534
        if (!isFinite(uid) || uid < 1000 || uid >= 65534) continue
        if (/(nologin|\/false|sync)$/.test(f[6])) continue
        if (f[0] === base.userName) continue
        var gecos = String(f[4] || "").split(",")[0].trim()
        found.push({
          name: f[0],
          realName: gecos.length > 0 ? gecos : f[0],
          initial: f[0].length > 0 ? f[0].charAt(0).toUpperCase() : "?"
        })
      }
      base.otherUsers = found
    }
  }

  FileView {
    path: "/etc/hostname"
    printErrors: false
    onLoaded: {
      var h = String(text() || "").trim()
      if (h.length > 0) base.hostName = h
    }
  }

  // True while the design is rendered as a boot-screen background: the boot
  // theme draws its own passphrase entry, so input chrome hides itself.
  property bool snapshotMode: false
  // Second stage of that grab: with snapshotBare also set, the input box
  // disappears entirely. That capture becomes the splash for reboot/shutdown
  // and for stretches of boot with no prompt up, where a box is dead chrome.
  property bool snapshotBare: false
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

  // Clocks read 24-hour unless this is on, see `omarchy-shell lock setClockFormat`
  // and the Clock row in the explorer's Settings tab. The service pushes it
  // down through LockHost; designs never read the setting themselves, they
  // render their clock through clock() below.
  property bool twelveHour: false

  // Designs pass their ordinary 24-hour Qt format string here. With the
  // 12-hour setting off it is used as written, so a design that never calls
  // this still behaves exactly as before.
  function clock(spec) {
    var s = String(spec)
    if (!twelveHour || s.indexOf("H") === -1) return Qt.formatDateTime(now, s)
    // An hour standing on its own -- a flip tile, a poster numeral -- has
    // nowhere to put AM/PM, so it just counts 1 to 12. Qt only reads h/hh as
    // 12-hour when the format carries AP, which is why this one is counted by
    // hand rather than handed to Qt.
    if (!/[ms]/.test(s)) {
      var h = now.getHours() % 12 || 12
      return s.replace("HH", h < 10 ? "0" + h : String(h)).replace("H", String(h))
    }
    var out = s.replace(/H{1,2}/, "h")
    if (!/AP|ap/.test(out)) out = out.replace(/h{1,2}(:mm)?(:ss)?/, "$& AP")
    return Qt.formatDateTime(now, out)
  }

  // For designs that lay the meridiem out themselves next to a bare hour.
  readonly property string meridiem: twelveHour ? Qt.formatDateTime(now, "AP") : ""

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

  // A suspend/resume cycle leaves the password field without item focus, and
  // nothing here used to claim it back: inputEnabled stays true for the whole
  // lock, so onInputEnabledChanged never fires, and Component.onCompleted ran
  // long before. The lock screen then ignores the keyboard until the user
  // clicks, or moves the pointer onto another output whose surface kept its
  // focus.
  //
  // The surface keeps compositor keyboard focus across the cycle — only the
  // item focus is lost — so the field itself is what has to be watched.
  Connections {
    target: base.inputItem
    ignoreUnknownSignals: true
    function onActiveFocusChanged() {
      if (base.inputEnabled && base.inputItem && !base.inputItem.activeFocus)
        Qt.callLater(base.forcePasswordFocus)
    }
  }
}
