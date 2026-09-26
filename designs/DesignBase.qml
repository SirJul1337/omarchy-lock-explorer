import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "Strings.js" as Strings

Item {
  id: base

  property string backgroundPath: ""
  property int backgroundVersion: 0
  property string avatarPath: ""
  property int avatarVersion: 0
  property bool fingerprintConfigured: false
  property bool faceConfigured: false
  property bool fido2Configured: false
  property bool fido2Active: false
  // True only while pam_u2f has an assertion open. The field is inert then,
  // and only then is typed text a PIN.
  property bool fido2Authenticating: false
  property bool fido2NeedsPin: false
  property string fido2Status: ""
  // What the fingerprint reader is saying, in pam_fprintd's own words, and
  // whether it is a failure ("Failed to match fingerprint"). Empty while no
  // scan is running.
  property string fingerprintStatus: ""
  property bool fingerprintStatusIsError: false

  // For a design's fingerprint hint: its own wording, unless the reader has
  // something new to say. The plain "place your finger" prompt repeats after
  // every attempt and says nothing a design's hint does not; a failed match
  // does, so that is what replaces it.
  function fingerprintHint(fallback) {
    return fingerprintStatusIsError && fingerprintStatus.length > 0 ? fingerprintStatus : fallback
  }
  property bool authenticatingPassword: false
  property string failureMessage: ""
  property int failedAttempts: 0
  property bool inputEnabled: true
  // True from the display blanking until it is lit again: keys only wake.
  property bool inputBlocked: false
  // The layout being typed on as a short code ("DK"), empty when it could not
  // be read. PasswordField shows it when it is not a US keyboard, because a
  // password typed on the wrong layout is invisible otherwise.
  property string keyboardLayout: ""
  // Caps lock as Hyprland reports it, seeded at lock and re-read while
  // someone types. PasswordField says so in the box.
  property bool capsLock: false
  signal capsProbeRequested()
  readonly property bool foreignLayout: keyboardLayout.length > 0 && keyboardLayout !== "US"
  // More than one layout configured: the badge is shown for US too, and a
  // click on it asks for the next layout.
  property int keyboardLayoutCount: 1
  readonly property bool layoutSwitchable: keyboardLayout.length > 0 && keyboardLayoutCount > 1
  signal layoutSwitchRequested()
  // Set by the service while on battery at 15% or less. The warning in the
  // top right corner is the base's, so every design has it.
  property bool batteryLow: false
  property int batteryPercent: -1

  // Sleep, restart and shut down, off unless the owner turned them on. Every
  // design gets them from here, in the corner, and each asks a second time
  // before it happens.
  property bool powerActions: false
  signal powerActionRequested(string action)
  property bool loadBackground: true
  property string passwordText: ""

  // Set with `omarchy-shell lock setVideo`. Designs show it with VideoWallpaper,
  // which keeps the still wallpaper underneath when there is none. videoPlaying
  // goes false while the screen is blanked so nothing decodes into a dark panel.
  property string videoPath: ""
  property bool videoPlaying: true

  // False while the display is blanked. Anything that animates should stop
  // then rather than paint into a dark panel -- effects, canvases, loops.
  // The field keeps its focus through it, so a key still wakes the screen.
  property bool screenAwake: true
  readonly property bool animating: screenAwake && visible

  // Raised by the service instead of dropping the lock when the design is
  // built around a clip (see UnlockClip): the clip plays through and
  // unlockFinished() hands the screen back.
  property bool unlockPlayback: false
  // Playback rate for unlock clips, see `omarchy-shell lock setClipSpeed`.
  property real clipSpeed: 1
  signal unlockFinished()

  signal submitPassword(string password)
  // Something drawn over time has come to rest (a ttfx effect, say): under
  // reduce motion LockHost takes its still frame again.
  signal stillRequested()
  signal passwordTextEdited(string password)
  signal clearFailureRequested()
  signal wakeRequested()
  signal faceRequested()
  signal fido2Requested()
  signal passwordRequested()
  signal submitFido2Pin(string pin)

  readonly property bool errorState: failureMessage.length > 0
  readonly property string userName: Quickshell.env("USER") || Quickshell.env("LOGNAME") || "user"
  readonly property string userInitial: displayName.length > 0 ? displayName.charAt(0).toUpperCase() : "?"
  // The account's full name (the GECOS field), set by the service when there
  // is one. displayName is what a design greets: its first word, or else the
  // login name with a capital, so "niklas" reads "Niklas". userName stays the
  // login itself, for designs that show it as one ("niklas@host", "login:").
  property string fullName: ""
  // The full name is free text from the passwd entry, and many designs show
  // the name in a Text left to guess its format: without < and > it can
  // never be taken for rich text.
  readonly property string displayName: {
    var first = String(fullName || "").replace(/[<>]/g, "").trim().split(/\s+/)[0] || ""
    if (first.length > 0) return first
    var u = String(userName || "")
    return u.length > 0 ? u.charAt(0).toUpperCase() + u.slice(1) : u
  }

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
  // Reveal belongs to the password. A key PIN goes into the same field, so
  // the toggle refuses in key mode and a reveal left on from before is
  // dropped the moment key mode takes over.
  function togglePasswordVisible() { if (!fido2Active) passwordVisible = !passwordVisible }
  onFido2ActiveChanged: if (fido2Active) passwordVisible = false
  onPasswordTextChanged: if (passwordText.length === 0) passwordVisible = false

  // The power row sits above the design but below the fail flash, and is gone
  // from boot snapshots with the rest of the chrome.
  Row {
    id: powerRow
    z: 900
    visible: base.powerActions && !base.snapshotMode
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.rightMargin: 28
    anchors.bottomMargin: 24
    spacing: 6

    property string confirming: ""

    Timer {
      id: powerConfirmTimeout
      interval: 4000
      onTriggered: powerRow.confirming = ""
    }

    component PowerButton: Rectangle {
      id: powerButton
      required property string action
      required property string glyph
      required property string label
      readonly property bool asking: powerRow.confirming === action
      width: asking ? askLabel.implicitWidth + 24 : 34
      height: 34
      radius: 17
      color: asking ? base.withAlpha(Color.lock.textError, 0.9)
        : base.withAlpha(Color.lock.text, powerArea.containsMouse ? 0.18 : 0.08)
      Behavior on color { ColorAnimation { duration: 120 } }
      Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

      Text {
        anchors.centerIn: parent
        visible: !powerButton.asking
        text: powerButton.glyph
        color: base.withAlpha(Color.lock.text, 0.75)
        font.family: Style.font.family
        font.pixelSize: 17
      }

      Text {
        id: askLabel
        anchors.centerIn: parent
        visible: powerButton.asking
        text: powerButton.label + "?"
        textFormat: Text.PlainText
        color: Color.background
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        font.weight: Font.DemiBold
      }

      MouseArea {
        id: powerArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          base.wakeRequested()
          if (powerButton.asking) {
            powerRow.confirming = ""
            powerConfirmTimeout.stop()
            base.powerActionRequested(powerButton.action)
            return
          }
          powerRow.confirming = powerButton.action
          powerConfirmTimeout.restart()
        }
      }
    }

    PowerButton { action: "suspend"; glyph: "󰤄"; label: base.tr("Sleep") }
    PowerButton { action: "reboot"; glyph: "󰜉"; label: base.tr("Restart") }
    PowerButton { action: "shutdown"; glyph: "󰐥"; label: base.tr("Shut down") }
  }

  Rectangle {
    id: batteryWarning
    z: 900
    visible: base.batteryLow && !base.snapshotMode
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.rightMargin: 28
    anchors.topMargin: 24
    width: batteryRow.implicitWidth + 24
    height: 30
    radius: 15
    color: withAlpha(Color.background, 0.72)
    border.width: 1
    border.color: withAlpha(Color.lock.textError, 0.7)

    Row {
      id: batteryRow
      anchors.centerIn: parent
      spacing: 8
      Text {
        text: "󰂃"
        color: Color.lock.textError
        font.family: Style.font.family
        font.pixelSize: 15
        anchors.verticalCenter: parent.verticalCenter
      }
      Text {
        text: base.tr("Battery low (%1%)").arg(base.batteryPercent)
        textFormat: Text.PlainText
        color: Color.lock.text
        font.family: Style.font.family
        font.pixelSize: 13
        anchors.verticalCenter: parent.verticalCenter
      }
    }
  }

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
  // Set from the wallpaper setting, read by Wallpaper: -1 keeps the blur a
  // design asks for, and the dim shift is added to the design's own.
  property real wallpaperBlur: -1
  property real wallpaperDim: 0
  // The lock screen's language (see Strings.js), set by the service from the
  // system locale or the Language setting. tr() gives a design's own text in
  // it, date() and clock() write month and day names in it.
  property string language: "en"
  // Set from Settings > Password field; PasswordField reads them. A design
  // that draws its own field can read them too.
  property bool showLayoutBadge: true
  property bool showCapsBadge: true
  property bool allowPasswordToggle: true
  property bool showAuthIcons: true
  readonly property var dateLocale: Qt.locale(Strings.localeName(language))
  function tr(text) { return Strings.tr(language, text) }
  function date(spec, when) { return (when || now).toLocaleString(dateLocale, String(spec)) }

  // Designs pass their ordinary 24-hour Qt format string here. With the
  // 12-hour setting off it is used as written, so a design that never calls
  // this still behaves exactly as before.
  function clock(spec) {
    var s = String(spec)
    if (!twelveHour || s.indexOf("H") === -1) return now.toLocaleString(dateLocale, s)
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
    return now.toLocaleString(dateLocale, out)
  }

  // For designs that lay the meridiem out themselves next to a bare hour.
  readonly property string meridiem: twelveHour ? now.toLocaleString(dateLocale, "AP") : ""

  function greeting() {
    var h = now.getHours()
    if (h < 5) return tr("Good night")
    if (h < 12) return tr("Good morning")
    if (h < 18) return tr("Good afternoon")
    return tr("Good evening")
  }

  function fileUrl(path) {
    if (!path) return ""
    var encoded = String(path).split("/").map(encodeURIComponent).join("/")
    return "file://" + encoded + "?v=" + backgroundVersion
  }

  function withAlpha(c, a) {
    return Qt.rgba(c.r, c.g, c.b, a)
  }

  // A deeper shade of a theme color for a backdrop. Dark themes take the full
  // factor; a light theme only dips a little, or it turns to muddy grey.
  function deepen(c, factor) {
    var light = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b > 0.5
    return Qt.darker(c, light ? 1 + (factor - 1) * 0.08 : factor)
  }

  function forcePasswordFocus() {
    if (inputEnabled && inputItem) inputItem.forceActiveFocus()
  }

  function clearPassword() {
    passwordTextEdited("")
  }

  onInputEnabledChanged: if (inputEnabled) Qt.callLater(forcePasswordFocus)
  Component.onCompleted: if (inputEnabled) Qt.callLater(forcePasswordFocus)

  // The field is read-only until pam_u2f asks for the PIN; take focus back
  // the moment it does so the first digit lands.
  onFido2NeedsPinChanged: if (fido2NeedsPin && inputEnabled) Qt.callLater(forcePasswordFocus)

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
