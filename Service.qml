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
  readonly property bool designHasClip: {
    var r = designsRevision
    var d = Designs.byId(designId)
    return !!(d && d.clip)
  }
  // The video file behind the current clip design; user ClipDesigns get their
  // clipFile filled in by the lock-designs scan.
  readonly property string designClipPath: {
    var r = designsRevision
    var d = Designs.byId(designId)
    if (!d || !d.clip || !d.clipFile) return ""
    return home + "/.config/omarchy/lock-videos/" + d.clipFile
  }

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

  // How long the unlock screen stays lit before the display is blanked. The
  // session is locked before every suspend, so on a machine that sleeps this
  // delay is what the user sees on resume: too short and the screen goes dark
  // before there is time to type. Saved on the plugin entry as `blankMs`.
  readonly property int defaultBlankDelay: 5000
  property int blankDelayOverride: -1
  readonly property int configuredBlankDelay: {
    var cfg = shell ? shell.shellConfig : null
    var list = cfg && Array.isArray(cfg.plugins) ? cfg.plugins : []
    for (var i = 0; i < list.length; i++) {
      var entry = list[i]
      if (entry && String(entry.id || "") === pluginId && entry.blankMs !== undefined)
        return Math.max(1000, Math.min(3600000, Number(entry.blankMs) || defaultBlankDelay))
    }
    return defaultBlankDelay
  }
  readonly property int blankDelay: blankDelayOverride >= 0 ? blankDelayOverride : configuredBlankDelay

  // When true the display stays powered while locked: the DPMS-off is skipped
  // entirely, so video designs keep playing and slow monitors are never
  // re-blanked. Takes precedence over blankDelay. Lives on the plugin entry
  // in shell.json.
  property int keepDisplayOnOverride: -1
  readonly property bool configuredKeepDisplayOn: {
    var cfg = shell ? shell.shellConfig : null
    var list = cfg && Array.isArray(cfg.plugins) ? cfg.plugins : []
    for (var i = 0; i < list.length; i++) {
      var entry = list[i]
      if (entry && String(entry.id || "") === pluginId) return entry.keepDisplayOn === true
    }
    return false
  }
  readonly property bool keepDisplayOn: keepDisplayOnOverride >= 0 ? keepDisplayOnOverride === 1 : configuredKeepDisplayOn

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

  // A looping video for the designs that show one (Motion), and a clip that
  // plays over the desktop right after the password checks out. Both live on
  // the plugin entry in shell.json, as `video` and `sting`; "none" there means
  // it was cleared on purpose.
  property string videoOverride: ""
  readonly property string configuredVideo: {
    var cfg = shell ? shell.shellConfig : null
    var list = cfg && Array.isArray(cfg.plugins) ? cfg.plugins : []
    for (var i = 0; i < list.length; i++) {
      var entry = list[i]
      if (entry && String(entry.id || "") === pluginId && entry.video) return String(entry.video)
    }
    return ""
  }
  readonly property string videoSetting: videoOverride.length > 0 ? videoOverride : configuredVideo
  readonly property string videoPath: videoSetting === "none" ? "" : videoSetting

  property string stingOverride: ""
  readonly property string configuredSting: {
    var cfg = shell ? shell.shellConfig : null
    var list = cfg && Array.isArray(cfg.plugins) ? cfg.plugins : []
    for (var i = 0; i < list.length; i++) {
      var entry = list[i]
      if (entry && String(entry.id || "") === pluginId && entry.sting) return String(entry.sting)
    }
    return ""
  }
  readonly property string stingSetting: stingOverride.length > 0 ? stingOverride : configuredSting
  readonly property string stingPath: stingSetting === "none" ? "" : stingSetting
  readonly property string stingUrl: {
    if (stingPath.length === 0) return ""
    var encoded = String(stingPath).split("/").map(encodeURIComponent).join("/")
    return "file://" + encoded
  }

  property int stingVolumeOverride: -1
  readonly property int configuredStingVolume: {
    var cfg = shell ? shell.shellConfig : null
    var list = cfg && Array.isArray(cfg.plugins) ? cfg.plugins : []
    for (var i = 0; i < list.length; i++) {
      var entry = list[i]
      if (entry && String(entry.id || "") === pluginId && entry.stingVolume !== undefined)
        return Math.max(0, Math.min(100, Number(entry.stingVolume) || 0))
    }
    return 0
  }
  readonly property int stingVolume: stingVolumeOverride >= 0 ? stingVolumeOverride : configuredStingVolume

  // How fast unlock clips play, 1.0 is natural speed. Applies to the clip
  // designs and the separate unlock clip. Saved on the plugin entry as
  // `clipSpeed` when it is not 1.
  property real clipSpeedOverride: -1
  readonly property real configuredClipSpeed: {
    var cfg = shell ? shell.shellConfig : null
    var list = cfg && Array.isArray(cfg.plugins) ? cfg.plugins : []
    for (var i = 0; i < list.length; i++) {
      var entry = list[i]
      if (entry && String(entry.id || "") === pluginId && entry.clipSpeed !== undefined) {
        var v = Number(entry.clipSpeed)
        if (isFinite(v) && v > 0) return Math.max(0.25, Math.min(4, v))
      }
    }
    return 1
  }
  readonly property real clipSpeed: clipSpeedOverride > 0 ? clipSpeedOverride : configuredClipSpeed

  function setClipSpeed(v) {
    var speed = Number(v)
    if (!isFinite(speed) || speed <= 0) return false
    speed = Math.max(0.25, Math.min(4, speed))
    clipSpeedOverride = speed
    if (shell && typeof shell.updateEntryInline === "function") {
      var current = pluginEntry()
      if (speed === 1) delete current.clipSpeed
      else current.clipSpeed = speed
      shell.updateEntryInline(pluginId, current)
    }
    logEvent("clip-speed=" + speed)
    return true
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

  function setKeepDisplayOn(on) {
    var value = on === true || on === 1 || on === "true"
    keepDisplayOnOverride = value ? 1 : 0
    if (shell && typeof shell.updateEntryInline === "function") {
      var current = pluginEntry()
      if (!value) delete current.keepDisplayOn
      else current.keepDisplayOn = true
      shell.updateEntryInline(pluginId, current)
    }
    logEvent("keep-display-on=" + value)
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

  // The clip designs' videos ship in <plugin>/videos; link any that are
  // missing into ~/.config/omarchy/lock-videos, where ClipDesign and the
  // boot twins resolve them. Idempotent, never overwrites a user's file.
  Process {
    id: shippedClipsProc
    running: true
    command: ["bash", "-c",
      "dst=\"$HOME/.config/omarchy/lock-videos\"; mkdir -p \"$dst\"; for f in \"$0\"/videos/*.mp4; do [ -e \"$f\" ] || continue; b=$(basename \"$f\"); [ -e \"$dst/$b\" ] || ln -s \"$f\" \"$dst/$b\"; done",
      root.pluginDir]
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

  // ------------------------------------------------------------------- video

  function setVideo(path) {
    var value = String(path || "").trim()
    if (value.indexOf("file://") === 0) value = decodeURIComponent(value.replace(/^file:\/\//, ""))
    var setting = value.length > 0 ? value : "none"
    videoOverride = setting
    if (shell && typeof shell.updateEntryInline === "function") {
      var current = pluginEntry()
      if (setting === "none") delete current.video
      else current.video = setting
      shell.updateEntryInline(pluginId, current)
    }
    logEvent("video=" + setting)
    return true
  }

  function clearVideo() { return setVideo("") }

  function setSting(path) {
    var value = String(path || "").trim()
    if (value.indexOf("file://") === 0) value = decodeURIComponent(value.replace(/^file:\/\//, ""))
    var setting = value.length > 0 ? value : "none"
    stingOverride = setting
    if (shell && typeof shell.updateEntryInline === "function") {
      var current = pluginEntry()
      if (setting === "none") delete current.sting
      else current.sting = setting
      shell.updateEntryInline(pluginId, current)
    }
    logEvent("sting=" + setting)
    return true
  }

  function clearSting() { return setSting("") }

  function setStingVolume(value) {
    var text = String(value === undefined ? "" : value).trim()
    var v = Math.round(Number(text))
    if (text.length === 0 || !isFinite(v) || v < 0 || v > 100) return false
    stingVolumeOverride = v
    if (shell && typeof shell.updateEntryInline === "function") {
      var current = pluginEntry()
      if (v === 0) delete current.stingVolume
      else current.stingVolume = v
      shell.updateEntryInline(pluginId, current)
    }
    logEvent("sting-volume=" + v)
    return true
  }

  // Same dance as the avatar picker: the explorer steps aside for the dialog.
  property bool videoPickReopens: false
  property string videoPickTarget: "video"
  function pickVideo(reopenExplorer, target) {
    if (videoPickProc.running) return false
    videoPickTarget = String(target || "video")
    videoPickReopens = reopenExplorer === true
    videoPickProc.command = ["omarchy-file-select",
      "--title", videoPickTarget === "sting" ? "Pick an unlock clip"
        : videoPickTarget === "clip" ? "Pick a video for a new clip design"
        : "Pick a lock screen video",
      "--extensions", "mp4 mkv webm mov m4v"]
    videoPickProc.running = true
    return true
  }

  Process {
    id: videoPickProc
    stdout: StdioCollector {
      id: videoPickOut
      waitForEnd: true
      onStreamFinished: {
        var picked = String(videoPickOut.text || "").trim().split("\n")[0] || ""
        if (picked.length > 0) {
          if (root.videoPickTarget === "sting") root.setSting(picked)
          else if (root.videoPickTarget === "clip") root.createClipDesign(picked)
          else root.setVideo(picked)
        }
        if (root.videoPickReopens && root.shell && typeof root.shell.summon === "function")
          root.shell.summon(root.pluginId, "{}")
        root.videoPickReopens = false
      }
    }
  }

  // A picked video becomes a one-line ClipDesign in ~/.config/omarchy/lock-designs,
  // with the file itself copied to ~/.config/omarchy/lock-videos where ClipDesign
  // resolves clips from. Same freeze-then-play-on-unlock behavior as Storm.
  signal clipDesignAdded(string id)

  function createClipDesign(path) {
    var src = String(path || "").trim()
    if (src.indexOf("file://") === 0) src = decodeURIComponent(src.replace(/^file:\/\//, ""))
    if (src.length === 0 || clipDesignProc.running) return false
    var importLine = 'import "../plugins/' + pluginId + '/designs"'
    clipDesignProc.command = ["bash", "-c", clipDesignScript, "clipdesign",
      src, home + "/.config/omarchy/lock-videos", userDesignsDir, importLine]
    clipDesignProc.running = true
    return true
  }

  readonly property string clipDesignScript: '
set -e
src="$1"; videos="$2"; dir="$3"; imp="$4"
mkdir -p "$videos" "$dir"
base=$(basename "$src")
if [[ -e "$videos/$base" ]] && ! cmp -s "$src" "$videos/$base"; then
  stem="${base%.*}"; ext="${base##*.}"; n=2
  while [[ -e "$videos/$stem-$n.$ext" ]]; do n=$((n+1)); done
  base="$stem-$n.$ext"
fi
[[ -e "$videos/$base" ]] || cp "$src" "$videos/$base"
stem="${base%.*}"
name=$(printf %s "$stem" | tr -cd "[:alnum:]_-")
[[ -n "$name" ]] || name=Clip
target="$dir/$name.qml"; n=2
while [[ -e "$target" ]]; do target="$dir/$name$n.qml"; n=$((n+1)); done
q=\'"\'
{
  echo "// Clip design: $base holds its first frame while locked and plays"
  echo "// through as the unlock. The video lives in ~/.config/omarchy/lock-videos."
  echo "$imp"
  echo ""
  echo "ClipDesign { clipName: $q$base$q }"
} > "$target"
printf "%s\\t%s\\n" "$target" "$base"
'

  Process {
    id: clipDesignProc
    stdout: StdioCollector {
      id: clipDesignOut
      waitForEnd: true
      onStreamFinished: {
        var last = String(clipDesignOut.text || "").trim().split("\n").pop() || ""
        var parts = last.split("\t")
        var target = (parts[0] || "").trim()
        if (target.length === 0) return
        var d = Designs.fromUserFile(target)
        d.anim = true
        d.clip = true
        if (parts.length > 1 && parts[1].trim().length > 0) d.clipFile = parts[1].trim()
        Designs.setUser(Designs.USER.concat([d]))
        root.designsRevision += 1
        root.rescanUserDesigns()
        root.clipDesignAdded(d.id)
        root.logEvent("clip-design=" + target)
      }
    }
  }

  // Delete a user design from ~/.config/omarchy/lock-designs. A clip design's
  // video goes with it, unless the boot screen, the Motion video or the unlock
  // clip still point at it, or another design names it.
  function deleteDesign(id) {
    var d = Designs.byId(String(id || ""))
    if (!d || !d.path) return false
    var file = decodeURIComponent(String(d.path).replace(/^file:\/\//, ""))
    if (file.indexOf(userDesignsDir + "/") !== 0) return false
    var clip = String(d.clipFile || "")
    if (clip.length > 0) {
      var tail = "/" + clip
      var keep = bootSetting === "video:" + clip
        || (videoPath.length >= tail.length && videoPath.lastIndexOf(tail) === videoPath.length - tail.length)
        || (stingPath.length >= tail.length && stingPath.lastIndexOf(tail) === stingPath.length - tail.length)
      if (keep) clip = ""
    }
    if (designId === d.id) setDesign(Designs.DEFAULT_ID)
    deleteDesignProc.command = ["bash", "-c", deleteDesignScript, "deldesign",
      file, home + "/.config/omarchy/lock-videos", clip, userDesignsDir]
    deleteDesignProc.running = true
    logEvent("delete-design=" + d.id)
    return true
  }

  readonly property string deleteDesignScript: '
set -e
file="$1"; videos="$2"; clip="$3"; dir="$4"
rm -f -- "$file"
if [[ -n $clip ]] && ! grep -qs -- "$clip" "$dir"/*.qml 2>/dev/null; then
  rm -f -- "$videos/$clip"
fi
'

  Process {
    id: deleteDesignProc
    onExited: function(exitCode) {
      root.rescanUserDesigns()
      root.refreshBootLists()
    }
  }

  // Delete a boot card of the user's own: a video from
  // ~/.config/omarchy/lock-videos (video:<file>) or a custom boot layout
  // (custom:<name>, taking its generated lock design along). Videos still
  // used as the Motion video or the unlock clip are left alone.
  function deleteBootItem(id) {
    var v = String(id || "")
    if (v.indexOf("video:") !== 0 && v.indexOf("custom:") !== 0) return false
    if (v.indexOf("video:") === 0) {
      var tail = "/" + v.substring(6)
      if ((videoPath.length >= tail.length && videoPath.lastIndexOf(tail) === videoPath.length - tail.length)
        || (stingPath.length >= tail.length && stingPath.lastIndexOf(tail) === stingPath.length - tail.length)) return false
    }
    if (bootSetting === v) setBoot("stock")
    deleteBootItemProc.command = ["bash", "-c", deleteBootItemScript, "delboot",
      v, home + "/.config/omarchy/lock-videos", home + "/.config/omarchy/boot-designs",
      home + "/.config/omarchy/lock-designs",
      home + "/.local/state/omarchy/lock-explorer-boot-previews"]
    deleteBootItemProc.running = true
    logEvent("delete-boot=" + v)
    return true
  }

  readonly property string deleteBootItemScript: '
set -e
id="$1"; videos="$2"; bootdir="$3"; lockdir="$4"; previews="$5"
case "$id" in
  video:*)
    f="${id#video:}"
    rm -f -- "$videos/$f"
    rm -f -- "$previews/video-$f-"*.png
    ;;
  custom:*)
    n="${id#custom:}"
    rm -f -- "$bootdir/$n.conf"
    rm -f -- "$lockdir/$n.qml"
    rm -f -- "$previews/custom-$n-"*.png
    ;;
esac
'

  Process {
    id: deleteBootItemProc
    onExited: function(exitCode) {
      root.refreshBootLists()
      root.rescanUserDesigns()
      root.refreshBootPreviews()
    }
  }

  // The clip that plays once the lock surface is gone. It runs over the live
  // desktop rather than holding the session lock, so nothing it does can leave
  // the screen stuck: any key, any click, the end of the clip or the failsafe
  // timer takes it away.
  property bool stingPlaying: false

  function playSting() {
    if (stingPath.length === 0 || stingPlaying) return false
    // No player without qt6-multimedia; setting stingPlaying anyway would
    // stick, since only the window's timers ever call endSting().
    if (!multimediaAvailable) return false
    stingPlaying = true
    logEvent("sting-playing")
    return true
  }

  function endSting() {
    if (!stingPlaying) return
    stingPlaying = false
    logEvent("sting-done")
    commitClipWallpaper()
  }

  // "The last frame becomes your wallpaper": with clipWallpaper on, the frame
  // the unlock video ends on is extracted while the screen is still locked and
  // handed to omarchy-theme-bg-set the moment the clip gives the screen back,
  // so the desktop opens exactly where the video stopped. Saved on the plugin
  // entry as `clipWallpaper: true`, off by default.
  property int clipWallpaperOverride: -1
  readonly property bool configuredClipWallpaper: {
    var cfg = shell ? shell.shellConfig : null
    var list = cfg && Array.isArray(cfg.plugins) ? cfg.plugins : []
    for (var i = 0; i < list.length; i++) {
      var entry = list[i]
      if (entry && String(entry.id || "") === pluginId && entry.clipWallpaper === true) return true
    }
    return false
  }
  readonly property bool clipWallpaper: clipWallpaperOverride === -1 ? configuredClipWallpaper : clipWallpaperOverride === 1

  function setClipWallpaper(on) {
    var enabled = on === true || on === "true" || on === "on"
    clipWallpaperOverride = enabled ? 1 : 0
    if (shell && typeof shell.updateEntryInline === "function") {
      var current = pluginEntry()
      if (enabled) current.clipWallpaper = true
      else delete current.clipWallpaper
      shell.updateEntryInline(pluginId, current)
    }
    logEvent("clip-wallpaper=" + enabled)
    return true
  }

  property string preparedClipWallpaper: ""

  function prepareClipWallpaper(path) {
    if (!clipWallpaper || !path || String(path).length === 0) return
    if (clipWallPrepProc.running) return
    preparedClipWallpaper = ""
    clipWallPrepProc.command = ["bash", "-c", clipWallScript, "clipwall",
      String(path), home + "/.local/state/omarchy/lock-explorer-clip-wallpapers"]
    clipWallPrepProc.running = true
  }

  function commitClipWallpaper() {
    if (!clipWallpaper || preparedClipWallpaper.length === 0) return
    Quickshell.execDetached(["omarchy-theme-bg-set", preparedClipWallpaper])
    logEvent("clip-wallpaper-set=" + preparedClipWallpaper)
  }

  readonly property string clipWallScript: '
set -e
src="$1"; dir="$2"
mkdir -p "$dir"
stem=$(basename "$src"); stem="${stem%.*}"
out="$dir/$stem.png"
if [[ ! -s "$out" || "$src" -nt "$out" ]]; then
  ffmpeg -y -loglevel error -sseof -1 -i "$src" -update 1 "$out" || true
  [[ -s "$out" ]] || ffmpeg -y -loglevel error -i "$src" -update 1 "$out"
fi
echo "$out"
'

  Process {
    id: clipWallPrepProc
    stdout: StdioCollector {
      id: clipWallPrepOut
      waitForEnd: true
      onStreamFinished: {
        root.preparedClipWallpaper = String(clipWallPrepOut.text || "").trim().split("\n").pop() || ""
      }
    }
  }

  // The boot (LUKS decrypt) screen, styled with Plymouth. Saved on the plugin
  // entry as `boot`: "follow" keeps it matched to the lock design whenever the
  // design has a twin under plymouth/, a design id pins it to that design, and
  // absent means the stock Omarchy boot theme is left alone. Applying bakes the
  // current theme colors into a generated theme and rebuilds the initramfs
  // through a single polkit prompt (see plymouth/apply.sh).
  property string bootOverride: ""
  readonly property string configuredBoot: {
    var cfg = shell ? shell.shellConfig : null
    var list = cfg && Array.isArray(cfg.plugins) ? cfg.plugins : []
    for (var i = 0; i < list.length; i++) {
      var entry = list[i]
      if (entry && String(entry.id || "") === pluginId && entry.boot) return String(entry.boot)
    }
    return "stock"
  }
  readonly property string bootSetting: {
    var value = bootOverride.length > 0 ? bootOverride : configuredBoot
    if (value === "follow" || value === "stock" || value === "theme" || value === "rotate") return value
    if (value.indexOf("snapshot:") === 0 || value.indexOf("video:") === 0 || value.indexOf("custom:") === 0) return value
    var d = Designs.byId(value)
    return d && d.boot === true ? value : "stock"
  }
  property bool bootApplying: false
  property string bootApplyTarget: ""
  property string bootApplied: ""  // last installed twin, "" = stock/untouched
  property int bootAppliedVersion: 0
  readonly property string bootTarget: {
    if (bootSetting === "stock") return "stock"
    if (bootSetting === "theme") return "theme"
    if (bootSetting === "rotate") return ""
    if (bootSetting.indexOf("snapshot:") === 0) return bootSetting
    if (bootSetting === "follow") {
      var d = Designs.byId(designId)
      return d && d.boot === true ? d.id : ""
    }
    return bootSetting
  }

  function setBoot(value) {
    var v = String(value || "").trim().toLowerCase()
    if (v !== "follow" && v !== "stock" && v !== "theme" && v !== "rotate" && v.indexOf("video:") !== 0 && v.indexOf("custom:") !== 0 && v.indexOf("snapshot:") !== 0) {
      var d = Designs.byId(v)
      if (!d || d.boot !== true) return false
    }
    if (bootApplying) return false
    bootOverride = v
    if (shell && typeof shell.updateEntryInline === "function") {
      var current = pluginEntry()
      if (v === "stock") delete current.boot
      else current.boot = v
      shell.updateEntryInline(pluginId, current)
    }
    logEvent("boot=" + v)
    // Redesign: picking a boot option only sets the desired choice; the
    // rebuild happens when the Apply button is pressed.
    return true
  }

  // force reapplies even when the target already matches, so a changed Omarchy
  // theme gets its colors baked in again.
  function applyBoot(force, explicitTarget) {
    if (bootApplying) return
    var target = explicitTarget !== undefined && String(explicitTarget).length > 0 ? String(explicitTarget) : bootTarget
    if (target.length === 0) return  // follow, but this design has no twin
    if (target === "stock" && bootApplied.length === 0) return  // nothing to restore
    if (!force && target === bootApplied) return
    bootApplying = true
    bootApplyTarget = target
    bootApplyProc.command = ["env", "BOOT_CLIP_SECONDS=" + bootClipSeconds, "bash", pluginDir + "/plymouth/apply.sh", target]
    bootApplyProc.running = true
  }

  Process {
    id: bootApplyProc
    stdout: StdioCollector { }
    stderr: StdioCollector {
      id: bootApplyErr
      waitForEnd: true
    }
    onExited: function(exitCode) {
      root.bootApplying = false
      if (exitCode === 0) {
        root.bootApplied = root.bootApplyTarget === "stock" ? "" : root.bootApplyTarget
        root.logEvent("boot-applied=" + (root.bootApplied.length > 0 ? root.bootApplied : "stock"))
      } else {
        root.logEvent("boot-apply-failed=" + exitCode)
        console.warn("lock-explorer: plymouth apply failed:", String(bootApplyErr.text || "").trim())
      }
    }
  }

  // apply.sh records what it installed and which Omarchy theme the colors
  // came from; picking it up here keeps the state right across shell restarts
  // and command line applies.
  FileView {
    path: root.stateHome + "/omarchy/lock-explorer-boot"
    watchChanges: true
    printErrors: false
    onLoaded: {
      var parts = String(text()).trim().split(/\s+/)
      var value = parts[0] || ""
      root.bootApplied = value === "stock" ? "" : value
      root.bootAppliedTheme = parts.length > 1 ? parts[1] : ""
      // Cache-buster for the applied-boot preview image, which is rewritten
      // on every apply (same-id re-applies included).
      root.bootAppliedVersion += 1
    }
    onLoadFailed: { root.bootApplied = ""; root.bootAppliedTheme = "" }
    onFileChanged: reload()
  }

  // The boot screen colors are baked in at apply time, so a theme switch
  // would leave it in the old palette right until the retained last frame
  // hands over to the new wallpaper. Regenerate when the theme changes,
  // unless the user opted out (`bootResync: false` on the plugin entry).
  property string bootAppliedTheme: ""
  property string bootCurrentTheme: ""
  property int bootResyncOverride: -1
  readonly property bool configuredBootResync: {
    var cfg = shell ? shell.shellConfig : null
    var list = cfg && Array.isArray(cfg.plugins) ? cfg.plugins : []
    for (var i = 0; i < list.length; i++) {
      var entry = list[i]
      if (entry && String(entry.id || "") === pluginId && entry.bootResync === false) return false
    }
    return true
  }
  readonly property bool bootResync: bootResyncOverride === -1 ? configuredBootResync : bootResyncOverride === 1

  function setBootResync(on) {
    var enabled = on === true || on === "on" || on === "true"
    bootResyncOverride = enabled ? 1 : 0
    if (shell && typeof shell.updateEntryInline === "function") {
      var current = pluginEntry()
      if (enabled) delete current.bootResync
      else current.bootResync = false
      shell.updateEntryInline(pluginId, current)
    }
    logEvent("boot-resync=" + (enabled ? "on" : "off"))
    if (enabled) maybeResyncBoot()
    return true
  }

  // Snapshot boot screens can't be re-baked from the old picture: the theme
  // change moved the wallpaper and colors, so the explorer has to take a
  // fresh snapshot (which also carries the entry geometry).
  signal bootResnapshotRequested(string designId, bool persist)
  signal exploreTabRequested(string tab)

  function maybeResyncBoot() {
    if (!bootResync || bootApplying || !bootResyncArmed) return
    if (bootApplied.length === 0 || bootAppliedTheme.length === 0 || bootCurrentTheme.length === 0) return
    if (bootAppliedTheme === bootCurrentTheme) return
    logEvent("boot-resync " + bootAppliedTheme + " -> " + bootCurrentTheme)
    if (bootApplied.indexOf("snapshot:") === 0) {
      // The fresh snapshot carries the new background too.
      bootBgResyncTimer.stop()
      bootResnapshotRequested(bootApplied.substring(9), bootSetting !== "follow")
      return
    }
    // Re-bake what is actually installed: with follow and a twin-less lock
    // design the setting resolves to nothing, but the installed twin still
    // needs the new colors.
    applyBoot(true, bootApplied)
  }

  // Cycling the background inside a theme leaves an applied snapshot showing
  // the old wallpaper. Retake it once the cycling settles; same opt-out as
  // the theme resync.
  property string bootLastBackground: ""

  onBackgroundPathChanged: {
    if (backgroundPath.length === 0) return
    if (bootLastBackground.length === 0) { bootLastBackground = backgroundPath; return }
    if (bootLastBackground === backgroundPath) return
    bootLastBackground = backgroundPath
    if (!bootResync || !bootResyncArmed) return
    if (bootApplied.indexOf("snapshot:") !== 0) return
    bootBgResyncTimer.restart()
  }

  Timer {
    id: bootBgResyncTimer
    interval: 8000
    onTriggered: {
      if (!root.bootResync || root.bootApplying) return
      if (root.bootApplied.indexOf("snapshot:") !== 0) return
      root.logEvent("boot-resync background")
      root.bootResnapshotRequested(root.bootApplied.substring(9), root.bootSetting !== "follow")
    }
  }


  // Thumbnails for the explorer's boot cards, one per option and theme,
  // rendered in the background by plymouth/previews.sh.
  property int bootPreviewsVersion: 0
  property bool bootPreviewsRunning: false

  property bool bootPreviewsPending: false

  function refreshBootPreviews() {
    refreshBootLists()
    // A request landing mid-run must queue a follow-up: the running pass
    // rendered the state before this change and would leave stale previews.
    if (bootPreviewsRunning) { bootPreviewsPending = true; return }
    bootPreviewsRunning = true
    bootPreviewsProc.command = ["bash", pluginDir + "/plymouth/previews.sh"]
    bootPreviewsProc.running = true
  }

  Process {
    id: bootPreviewsProc
    stdout: StdioCollector { }
    stderr: StdioCollector { }
    onExited: function(exitCode) {
      root.bootPreviewsRunning = false
      root.bootPreviewsVersion++
      if (root.bootPreviewsPending) {
        root.bootPreviewsPending = false
        root.refreshBootPreviews()
      }
    }
  }


  // The user's own clips and boot layouts, listed as cards on the boot tab.
  property var bootVideos: []
  property var bootCustomDesigns: []

  function refreshBootLists() { bootListsProc.running = true }

  Process {
    id: bootListsProc
    command: ["bash", "-c", "ls -1 \"$HOME/.config/omarchy/lock-videos\" 2>/dev/null; echo ::; for f in \"$HOME\"/.config/omarchy/boot-designs/*.conf; do [ -f \"$f\" ] && basename \"$f\" .conf; done"]
    stdout: StdioCollector {
      id: bootListsOut
      waitForEnd: true
      onStreamFinished: {
        var parts = String(bootListsOut.text || "").split("::")
        root.bootVideos = (parts[0] || "").split("\n")
          .map(function(l) { return l.trim() })
          .filter(function(l) { return /\.(mp4|mkv|webm|mov|m4v)$/i.test(l) })
        root.bootCustomDesigns = (parts.length > 1 ? parts[1] : "").split("\n")
          .map(function(l) { return l.trim() })
          .filter(function(l) { return l.length > 0 })
      }
    }
  }

  // How much of a clip boot screen plays, in seconds; 0 plays it all. Saved
  // on the plugin entry as bootClipSeconds.
  property int bootClipSecondsOverride: -1
  readonly property int configuredBootClipSeconds: {
    var cfg = shell ? shell.shellConfig : null
    var list = cfg && Array.isArray(cfg.plugins) ? cfg.plugins : []
    for (var i = 0; i < list.length; i++) {
      var entry = list[i]
      if (entry && String(entry.id || "") === pluginId && entry.bootClipSeconds !== undefined)
        return Math.max(0, Math.min(30, Number(entry.bootClipSeconds) || 0))
    }
    return 0
  }
  readonly property int bootClipSeconds: bootClipSecondsOverride >= 0 ? bootClipSecondsOverride : configuredBootClipSeconds

  function setBootClipSeconds(n) {
    var v = Math.max(0, Math.min(30, Math.round(Number(n) || 0)))
    bootClipSecondsOverride = v
    if (shell && typeof shell.updateEntryInline === "function") {
      var current = pluginEntry()
      if (v === 0) delete current.bootClipSeconds
      else current.bootClipSeconds = v
      shell.updateEntryInline(pluginId, current)
    }
    logEvent("boot-clip=" + v)
    var appliedIsClip = bootApplied.indexOf("video:") === 0
    if (!appliedIsClip) {
      var d = Designs.byId(bootApplied)
      appliedIsClip = !!(d && d.bootKind === "clip")
    }
    if (appliedIsClip) applyBoot(true, bootApplied)
    return true
  }

  // Plumbing for the boot layout editor in the explorer.
  signal bootDesignLoaded(string name, string content)
  property string bootDesignPendingLoad: ""

  function loadBootDesign(name) {
    bootDesignPendingLoad = String(name)
    bootLoadProc.command = ["cat", home + "/.config/omarchy/boot-designs/" + bootDesignPendingLoad + ".conf"]
    bootLoadProc.running = true
  }

  Process {
    id: bootLoadProc
    stdout: StdioCollector {
      id: bootLoadOut
      waitForEnd: true
      onStreamFinished: root.bootDesignLoaded(root.bootDesignPendingLoad, String(bootLoadOut.text || ""))
    }
  }

  property string bootSaveName: ""
  function saveBootDesign(name, content) {
    bootSaveName = String(name)
    bootSaveProc.command = ["bash", "-c",
      'mkdir -p "$HOME/.config/omarchy/boot-designs" && printf %s "$1" > "$HOME/.config/omarchy/boot-designs/$2.conf"',
      "--", String(content), String(name)]
    bootSaveProc.running = true
  }

  Process {
    id: bootSaveProc
    onExited: function(exitCode) {
      // Generate the matching lock screen QML + its preview from the same
      // layout, so the pair stays in sync.
      var previews = root.stateHome + "/omarchy/lock-explorer-boot-previews"
      lockGenProc.command = ["bash", "-c",
        'mkdir -p "$3" && bash "$1" "$HOME/.config/omarchy/boot-designs/$2.conf" "$2" "$3/custom-$2-lock-$4.png"',
        "--", root.pluginDir + "/plymouth/custom/genlock.sh", root.bootSaveName, previews, root.bootCurrentTheme]
      lockGenProc.running = true
    }
  }

  Process {
    id: lockGenProc
    onExited: function(exitCode) {
      root.refreshBootPreviews()
      root.rescanUserDesigns()
      root.logEvent("boot-design-saved")
    }
  }

  function createBootDesign() {
    bootCreateProc.command = ["bash", "-c",
      'dir="$HOME/.config/omarchy/boot-designs"; mkdir -p "$dir"; n="my-boot"; i=2; while [ -f "$dir/$n.conf" ]; do n="my-boot-$i"; i=$((i+1)); done; cp "$1" "$dir/$n.conf"; echo "$n"',
      "--", pluginDir + "/plymouth/custom/template.conf"]
    bootCreateProc.running = true
  }

  Process {
    id: bootCreateProc
    stdout: StdioCollector {
      id: bootCreateOut
      waitForEnd: true
      onStreamFinished: {
        var n = String(bootCreateOut.text || "").trim()
        if (n.length > 0) {
          root.refreshBootLists()
          root.loadBootDesign(n)
        }
      }
    }
  }


  // Boot screen rotation: a set of options that advances one step after
  // every boot. The screen is baked into the boot image, so the swap happens
  // in the background right after login -- silently through the root path
  // unit rotate-setup.sh installs (one pkexec, once), with a normal polkit
  // prompt as the fallback. Saved on the plugin entry as bootRotation.
  property var bootRotationOverride: null
  readonly property var configuredBootRotation: {
    var cfg = shell ? shell.shellConfig : null
    var list = cfg && Array.isArray(cfg.plugins) ? cfg.plugins : []
    for (var i = 0; i < list.length; i++) {
      var entry = list[i]
      if (entry && String(entry.id || "") === pluginId && Array.isArray(entry.bootRotation)) return entry.bootRotation
    }
    return []
  }
  readonly property var bootRotation: bootRotationOverride !== null ? bootRotationOverride : configuredBootRotation
  property bool bootRotateSilent: false
  property string bootRotateNext: ""

  function toggleBootRotation(id) {
    var v = String(id || "")
    if (v.length === 0 || v === "stock") return false
    var list = bootRotation.slice()
    var idx = list.indexOf(v)
    if (idx === -1) list.push(v)
    else list.splice(idx, 1)
    bootRotationOverride = list
    if (shell && typeof shell.updateEntryInline === "function") {
      var current = pluginEntry()
      if (list.length === 0) delete current.bootRotation
      else current.bootRotation = list
      shell.updateEntryInline(pluginId, current)
    }
    logEvent("boot-rotation=" + list.join(","))
    return true
  }

  // persist=false applies the snapshot as the on-disk artifact but leaves the
  // saved boot setting alone (used by follow mode, which stays "follow").
  // entryRect ("cx,cy,w,h" in percent) is where the design's own input box
  // sits in the snapshot; the boot theme puts its bullets there.
  function applyBootSnapshot(id, persist, entryRect) {
    if (bootApplying) return
    if (persist === undefined) persist = true
    if (persist) {
      bootOverride = "snapshot:" + id
      if (shell && typeof shell.updateEntryInline === "function") {
        var current = pluginEntry()
        current.boot = "snapshot:" + id
        shell.updateEntryInline(pluginId, current)
      }
    }
    bootApplying = true
    bootApplyTarget = "snapshot:" + id
    bootApplyProc.command = ["env", "BOOT_CLIP_SECONDS=0",
      "SNAPSHOT_ENTRY=" + String(entryRect || ""),
      "bash", pluginDir + "/plymouth/apply.sh", "snapshot:" + id]
    bootApplyProc.running = true
    logEvent("boot-snapshot=" + id + (persist ? "" : " (follow)"))
  }

  function enableBootRotation() {
    if (bootRotateSilent) { setBoot("rotate"); return }
    bootRotateSetupProc.command = ["pkexec", "bash", pluginDir + "/plymouth/rotate-setup.sh", "install", home]
    bootRotateSetupProc.running = true
  }

  Process {
    id: bootRotateSetupProc
    stdout: StdioCollector { }
    stderr: StdioCollector { }
    onExited: function(exitCode) {
      if (exitCode === 0) {
        root.bootRotateSilent = true
        root.setBoot("rotate")
        root.logEvent("boot-rotate-setup=ok")
      } else {
        root.logEvent("boot-rotate-setup-failed=" + exitCode)
      }
    }
  }

  Process {
    id: bootRotateCheckProc
    command: ["bash", "-c", "[ -f /etc/systemd/system/omarchy-lock-explorer-boot.path ] && echo yes || echo no"]
    stdout: StdioCollector {
      id: bootRotateCheckOut
      waitForEnd: true
      onStreamFinished: {
        root.bootRotateSilent = String(bootRotateCheckOut.text || "").trim() === "yes"
        root.maybeRotateBoot()
      }
    }
  }

  // Advance at most once per boot: the stamp file keeps the boot id, so
  // shell restarts inside the same boot leave the rotation alone.
  function maybeRotateBoot() {
    if (bootSetting !== "rotate") return
    var list = bootRotation
    if (!list || list.length === 0) return
    var idx = list.indexOf(bootApplied)
    var next = list[(idx + 1) % list.length]
    if (next === bootApplied) return
    bootRotateNext = next
    bootRotateStampProc.running = true
  }

  Process {
    id: bootRotateStampProc
    command: ["bash", "-c", "bid=$(cat /proc/sys/kernel/random/boot_id); f=\"$HOME/.local/state/omarchy/lock-explorer-boot-rotated\"; [ \"$(cat \"$f\" 2>/dev/null)\" = \"$bid\" ] && echo skip || { echo \"$bid\" > \"$f\"; echo go; }"]
    stdout: StdioCollector {
      id: bootRotateStampOut
      waitForEnd: true
      onStreamFinished: {
        if (String(bootRotateStampOut.text || "").trim() !== "go") return
        if (root.bootRotateNext.length === 0 || root.bootApplying) return
        root.logEvent("boot-rotate -> " + root.bootRotateNext)
        if (root.bootRotateSilent) {
          root.bootApplying = true
          root.bootApplyTarget = root.bootRotateNext
          bootApplyProc.command = ["env", "BOOT_CLIP_SECONDS=" + root.bootClipSeconds, "bash", root.pluginDir + "/plymouth/apply.sh", root.bootRotateNext, "--spool"]
          bootApplyProc.running = true
        } else {
          root.applyBoot(true, root.bootRotateNext)
        }
      }
    }
  }

  // Armed a little after startup so a stale palette right after login gets
  // one polkit prompt once the desktop has settled, not mid-splash.
  property bool bootResyncArmed: false

  Timer {
    interval: 12000
    running: true
    onTriggered: {
      root.bootResyncArmed = true
      root.refreshBootLists()
      // The silent-rotation check chains into maybeRotateBoot; the resync
      // runs after so a rotation that just advanced satisfies it.
      bootRotateCheckProc.running = true
      root.maybeResyncBoot()
    }
  }

  FileView {
    path: root.stateHome + "/omarchy/current/theme.name"
    watchChanges: true
    printErrors: false
    onLoaded: { root.bootCurrentTheme = String(text()).trim(); root.maybeResyncBoot() }
    onLoadFailed: root.bootCurrentTheme = ""
    onFileChanged: reload()
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
    if (bootSetting === "follow") applyBoot(false)
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
  // The clip designs (Storm, Eyes, ...) hold the lock surface while their
  // video plays through as the unlock. unlockPlayback reaches the design,
  // clipUnlocking is the hold, clipFailsafe the way out if the file misbehaves.
  property bool clipUnlocking: false
  property bool unlockPlayback: false
  property bool previewClipPlaying: false
  // Nothing should decode video into a screen that is switched off.
  property bool screenBlanked: false

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
      // The frame is ready before the unlock needs it.
      if (root.designHasClip) root.prepareClipWallpaper(root.designClipPath)
      else if (root.stingPath.length > 0) root.prepareClipWallpaper(root.stingPath)
    })

    return true
  }

  function finishUnlock() {
    if (!root.locked && !lockRequested) return
    if (unlocking || clipUnlocking) return

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
    // A clip design keeps the surface and plays its video as the unlock. The
    // design says when it is done; the failsafe does not care what it thinks.
    // Without qt6-multimedia a clip design has already fallen back to
    // Classic, so unlock instantly instead of waiting on the clip failsafe.
    if (designHasClip && multimediaAvailable && (sessionLock.locked || sessionLock.secure)) {
      clipUnlocking = true
      unlockPlayback = true
      clipFailsafe.restart()
      // Second chance for designs picked while already locked.
      if (preparedClipWallpaper.length === 0) prepareClipWallpaper(designClipPath)
      logEvent("unlocking=clip")
      return
    }

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
    clipFailsafe.stop()
    var hadClip = clipUnlocking
    clipUnlocking = false
    unlockPlayback = false
    unlocking = false
    sessionLock.locked = false
    logEvent("unlocked")
    // The clip was the whole show, no second video on top of it.
    if (hadClip) commitClipWallpaper()
    else playSting()
  }

  function cancelUnlockAnimation() {
    if (!unlocking && !clipUnlocking) return
    unlockTimer.stop()
    clipFailsafe.stop()
    unlocking = false
    clipUnlocking = false
    unlockPlayback = false
    logEvent("unlock-cancelled")
  }

  function armBlankTimer() {
    idleBlankTimer.armedAt = Date.now()
    idleBlankTimer.restart()
  }

  function runWake() {
    screenBlanked = false
    if (!wakeProcess.running) wakeProcess.running = true
    if (lockRequested) armBlankTimer()
  }

  function runBlank() {
    if (keepDisplayOn) return
    screenBlanked = true
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
          videoPath: root.videoPath
          videoPlaying: root.locked && !root.screenBlanked
          unlockPlayback: root.unlockPlayback && root.showsInput(lockSurface.screen)
          clipSpeed: root.clipSpeed
          onUnlockFinished: root.releaseLock()
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
        videoPath: root.videoPath
        videoPlaying: root.previewVisible
        unlockPlayback: root.previewClipPlaying
        clipSpeed: root.clipSpeed
        // Hold the clip's last frame in the preview instead of snapping back
        // to the start; Esc (hidePreview) resets it.
        onUnlockFinished: {}
        onPasswordTextEdited: function(password) { root.previewTyped = password }
      }
    }

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      onClicked: { root.previewVisible = false; root.previewDesignId = "" }
    }
  }

  // The unlock clip window (see StingWindow.qml). It is the only part of the
  // service that touches QtMultimedia, so it loads through this Loader:
  // without qt6-multimedia the load fails, the video features switch off and
  // the rest of the service — the lock screen and the `lock` IPC target —
  // carries on. Importing QtMultimedia at the top of this file instead would
  // take the whole service down with a bare "Target not found".
  readonly property bool multimediaAvailable: stingLoader.status === Loader.Ready

  Loader {
    id: stingLoader
    source: Qt.resolvedUrl("StingWindow.qml")
    onLoaded: item.lock = root
    onStatusChanged: {
      if (status === Loader.Error) {
        console.warn("lock-explorer: qt6-multimedia is not installed; video designs and unlock clips are disabled."
          + " Install it with `sudo pacman -S qt6-multimedia`, then run `omarchy restart shell`.")
      }
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

  // However long the clip claims to be, the screen comes back.
  Timer {
    id: clipFailsafe
    interval: 15000
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
    // Files built on ClipDesign are tagged (with their clip file when it is
    // named inline) so they keep their animation flag and their video across
    // rescans.
    command: ["bash", "-c", "for f in \"$0\"/*.qml; do [ -e \"$f\" ] || continue; c=$(grep -o 'clipName: \"[^\"]*\"' \"$f\" 2>/dev/null | head -1 | cut -d'\"' -f2); if [ -n \"$c\" ]; then printf '%s\\tclip\\t%s\\n' \"$f\" \"$c\"; elif grep -q ClipDesign \"$f\" 2>/dev/null; then printf '%s\\tclip\\n' \"$f\"; else printf '%s\\n' \"$f\"; fi; done", root.userDesignsDir]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var lines = String(text || "").split("\n").filter(function(l) { return l.trim().length > 0 })
        var list = lines.map(function(l) {
          var parts = l.split("\t")
          var d = Designs.fromUserFile(parts[0].trim())
          if (parts.length > 1 && parts[1].trim() === "clip") { d.anim = true; d.clip = true }
          if (parts.length > 2 && parts[2].trim().length > 0) d.clipFile = parts[2].trim()
          return d
        })
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

  // The background is a symlink retarget with no file content to watch, so
  // poll it the way the stock background plugin does. Keeps backgroundPath
  // live for the boot-screen background resync.
  Timer {
    interval: 5000
    running: true
    repeat: true
    onTriggered: root.refreshBackground()
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
    interval: root.blankDelay
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
        multimedia: root.multimediaAvailable,
        fingerprint: root.fingerprintConfigured,
        authenticating: root.authenticating,
        lastEvent: root.lastEvent,
        lastEventAt: root.lastEventAt,
        design: root.designId,
        boot: root.bootSetting,
        bootApplied: root.bootApplied,
        bootApplying: root.bootApplying,
        unlock: root.unlockAnimation,
        unlockMs: root.unlockDuration,
        unlockAnimated: root.unlockAnimated,
        blankMs: root.blankDelay,
        unlocking: root.unlocking,
        clipDesign: root.designHasClip,
        clipUnlocking: root.clipUnlocking,
        video: root.videoPath,
        sting: root.stingPath,
        stingPlaying: root.stingPlaying,
        previewTyped: root.previewTyped.length
      })
    }

    function preview(): string {
      root.previewUnlocking = false
      root.previewClipPlaying = false
      root.refreshBackground()
      root.refreshFingerprintStatus()
      root.previewVisible = true
      return "ok"
    }

    function hidePreview(): string {
      previewUnlockTimer.stop()
      root.previewUnlocking = false
      root.previewClipPlaying = false
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

    function setKeepDisplayOn(value: string): string {
      return root.setKeepDisplayOn(value) ? "ok" : "invalid-value"
    }

    function boot(): string {
      var applied = root.bootApplied.length > 0 ? root.bootApplied : "stock"
      return root.bootSetting + " (applied: " + applied + (root.bootApplying ? ", rebuilding" : "") + ")"
    }

    function setBoot(value: string): string {
      if (root.bootApplying) return "busy"
      return root.setBoot(value) ? "ok" : "unknown-boot"
    }

    function setBootResync(value: string): string {
      return root.setBootResync(value === "on" || value === "true") ? "ok" : "failed"
    }

    function bootRotation(): string {
      return (root.bootRotation || []).join(",")
    }

    function toggleBootRotation(id: string): string {
      return root.toggleBootRotation(id) ? "ok" : "failed"
    }

    function enableBootRotation(): string {
      root.enableBootRotation()
      return "ok"
    }

    function setBootClipSeconds(value: string): string {
      return root.setBootClipSeconds(value) ? "ok" : "failed"
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
      var pd = Designs.byId(root.previewDesignId.length > 0 ? root.previewDesignId : root.designId)
      if (pd && pd.clip) {
        root.previewClipPlaying = true
        return "ok"
      }
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

    // Feeds the preview's password field, so a demo can type without hands.
    function previewType(text: string): string {
      if (!root.previewVisible) return "no-preview"
      root.previewTyped = String(text || "")
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

    function video(): string {
      return root.videoPath.length > 0 ? root.videoPath : "none"
    }

    function setVideo(path: string): string {
      return root.setVideo(path) ? "ok" : "failed"
    }

    function clearVideo(): string {
      return root.clearVideo() ? "ok" : "failed"
    }

    function pickVideo(): string {
      return root.pickVideo(false, "video") ? "ok" : "busy"
    }

    function sting(): string {
      return root.stingPath.length > 0 ? root.stingPath : "none"
    }

    function setSting(path: string): string {
      return root.setSting(path) ? "ok" : "failed"
    }

    function clearSting(): string {
      return root.clearSting() ? "ok" : "failed"
    }

    function pickSting(): string {
      return root.pickVideo(false, "sting") ? "ok" : "busy"
    }

    function newClipDesign(): string {
      return root.pickVideo(false, "clip") ? "ok" : "busy"
    }

    function clipWallpaper(): string {
      return root.clipWallpaper ? "on" : "off"
    }

    function setClipWallpaper(on: string): string {
      return root.setClipWallpaper(on) ? "ok" : "failed"
    }

    function clipSpeed(): string {
      return String(root.clipSpeed)
    }

    function setClipSpeed(v: string): string {
      return root.setClipSpeed(v) ? "ok" : "failed"
    }

    function createClipDesign(path: string): string {
      return root.createClipDesign(path) ? "ok" : "failed"
    }

    function deleteDesign(id: string): string {
      return root.deleteDesign(id) ? "ok" : "failed"
    }

    function deleteBootItem(id: string): string {
      return root.deleteBootItem(id) ? "ok" : "failed"
    }

    function stingVolume(): string {
      return String(root.stingVolume)
    }

    function setStingVolume(value: string): string {
      return root.setStingVolume(value) ? "ok" : "failed"
    }

    function previewSting(): string {
      if (root.stingPath.length === 0) return "no-clip"
      return root.playSting() ? "ok" : "busy"
    }

    function explore(): string {
      root.rescanUserDesigns()
      if (root.shell && typeof root.shell.summon === "function")
        return root.shell.summon(root.pluginId, "{}") ? "ok" : "failed"
      return "no-shell"
    }

    // Open the built-in editor on a custom boot layout.
    function editBootLayout(name: string): string {
      root.loadBootDesign(String(name || ""))
      if (root.shell && typeof root.shell.summon === "function")
        return root.shell.summon(root.pluginId, "{}") ? "ok" : "failed"
      return "no-shell"
    }

    // Open the explorer on a specific tab: styling, animation, boot or
    // settings. Also handy for scripting and screenshots.
    function exploreTab(tab: string): string {
      root.rescanUserDesigns()
      root.exploreTabRequested(String(tab || "styling"))
      if (root.shell && typeof root.shell.summon === "function")
        return root.shell.summon(root.pluginId, "{}") ? "ok" : "failed"
      return "no-shell"
    }
  }
}
