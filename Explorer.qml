import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "designs"
import "Designs.js" as Designs

Item {
  id: root

  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null
  property var service: null

  property bool opened: false
  // A resync that arrived while this window was never yet shown cannot grab a
  // frame (no scene graph); it parks here and runs on the next open.
  property var pendingResnapshot: null

  // Stock Omarchy ships Qt without a WebP decoder (issue #6): designs then
  // render the theme color instead of the wallpaper. Probe the current
  // wallpaper so the header can say so instead of leaving users guessing.
  readonly property string wallpaperProbePath: root.service ? String(root.service.backgroundPath || "") : ""
  readonly property bool wallpaperIsWebp: wallpaperProbePath.toLowerCase().indexOf(".webp") !== -1
  readonly property bool wallpaperBroken: wallpaperProbe.status === Image.Error
  Image {
    id: wallpaperProbe
    visible: false
    width: 1; height: 1
    sourceSize.width: 8; sourceSize.height: 8
    asynchronous: true
    source: root.opened && root.wallpaperProbePath.length > 0
      ? "file://" + root.wallpaperProbePath.split("/").map(encodeURIComponent).join("/") : ""
  }
  // The shell's app library shows a "Launching …" OSD until a new toplevel
  // window appears. This overlay is layer-shell, so no toplevel ever comes —
  // dismiss the OSD ourselves the moment the explorer is up (15s timeout
  // otherwise).
  onOpenedChanged: {
    if (!opened) return
    Quickshell.execDetached(["omarchy-shell", "osd", "close"])
    if (pendingResnapshot) {
      var p = pendingResnapshot
      pendingResnapshot = null
      Qt.callLater(function() { root.snapshotAndApply(p.id, p.persist) })
    }
  }
  property int selectedIndex: 0
  property bool fullPreview: false
  property bool editing: false
  property var editingDesign: null
  property string category: "all"

  readonly property var categories: Designs.categories()
  readonly property var designs: {
    var r = service ? service.designsRevision : 0
    if (mainTab === "animation") return Designs.animations()
    return Designs.stylings()
  }
  readonly property string pluginId: manifest && manifest.id ? String(manifest.id) : "io.github.sirjul1337.lock-explorer"
  readonly property string activeDesignId: service ? service.designId : Designs.DEFAULT_ID
  readonly property var selectedDesign: designs.length > 0 ? designs[Math.max(0, Math.min(selectedIndex, designs.length - 1))] : null
  readonly property string avatarUrl: service ? service.avatarUrl : ""

  // Quick setting for the unlock animation, the same one `omarchy-shell lock
  // setUnlockAnimation` writes. Off by default.
  readonly property var unlockOptions: [
    { id: "none", name: "Off", hint: "The lock screen disappears at once" },
    { id: "fade", name: "Fade", hint: "It fades into the wallpaper" },
    { id: "zoom", name: "Zoom", hint: "It fades and pushes in a little" },
    { id: "rise", name: "Rise", hint: "It fades upwards off the screen" }
  ]
  readonly property var unlockDurations: [200, 300, 400, 600, 800]
  readonly property string unlockAnimation: service ? service.unlockAnimation : "none"
  readonly property int unlockDuration: service ? service.unlockDuration : 400
  readonly property bool keepDisplayOn: service ? service.keepDisplayOn : false
  readonly property int blankDelay: service ? service.blankDelay : 5000
  readonly property var blankPresets: [5000, 15000, 30000, 60000, 300000]
  property bool customDelayEditing: false
  property string customDelayText: ""
  readonly property bool blankDelayIsCustom: !root.keepDisplayOn && root.blankPresets.indexOf(root.blankDelay) === -1
  readonly property string unlockLabel: {
    for (var i = 0; i < unlockOptions.length; i++)
      if (unlockOptions[i].id === unlockAnimation) return unlockOptions[i].name
    return "Off"
  }
  // Top level view: the design grid, or one of the settings pages.
  property string mainTab: "styling"
  onMainTabChanged: {
    if ((mainTab === "boot" || mainTab === "editor") && service && typeof service.refreshBootPreviews === "function") service.refreshBootPreviews()
    if (mainTab !== "editor") bootEditing = ""
    refocus()
  }

  function toggleSettings(tab) {
    mainTab = mainTab === tab ? "styling" : tab
  }

  function handleEscape() {
    if (confirmingDelete.length > 0) { confirmingDelete = ""; return }
    if (editing) { closeEditor(); return }
    if (bootEditing.length > 0) { closeBootEditor(); return }
    if (fullPreview) { fullPreview = false; return }
    if (mainTab !== "styling") { mainTab = "styling"; refocus(); return }
    dismiss()
  }

  // Deleting a user design is a two-step: first X arms the button, second
  // confirms. Esc or moving the selection disarms.
  property string confirmingDelete: ""
  onSelectedIndexChanged: confirmingDelete = ""
  onDesignsChanged: if (selectedIndex >= designs.length) selectedIndex = Math.max(0, designs.length - 1)

  function deleteSelected() {
    var d = root.selectedDesign
    if (!d || !d.path || !root.service) return
    if (root.confirmingDelete !== d.id) { root.confirmingDelete = d.id; return }
    root.confirmingDelete = ""
    root.service.deleteDesign(d.id)
  }

  // Boot cards use the same two-step confirm; only your own videos and
  // layouts get the button.
  function deleteBootCard(id) {
    if (root.confirmingDelete !== id) { root.confirmingDelete = id; return }
    root.confirmingDelete = ""
    if (root.service && typeof root.service.deleteBootItem === "function") root.service.deleteBootItem(id)
  }

  function refocus() { Qt.callLater(function() { keyCatcher.forceActiveFocus() }) }

  // Quick setting for the boot (LUKS decrypt) screen, applied through
  // `omarchy-shell lock setBoot`. Only designs with a Plymouth twin under
  // plymouth/ can style it; "follow" tracks the lock design when it has one.
  readonly property string followHint: {
    var d = Designs.byId(activeDesignId)
    var name = d ? d.name : "your lock screen"
    if (d && d.boot === true) return "Boot matches " + name + " with its animated twin"
    return "Boot matches " + name + " as a still — same styling for both"
  }
  function bootKindLabel(d) {
    if (!d || !d.bootKind) return "theme styling"
    if (d.bootKind === "clip") return "clip \u00b7 plays on unlock"
    if (d.bootKind === "reactive") return "reacts to typing"
    if (d.bootKind === "animated") return "animated"
    return "theme styling"
  }
  readonly property var bootTwins: {
    var twins = Designs.bootCapable()
    var rows = []
    for (var i = 0; i < twins.length; i++)
      rows.push({ id: twins[i].id, name: twins[i].name, hint: twins[i].description, kind: bootKindLabel(twins[i]) })
    return rows
  }
  readonly property string bootApplied: service ? service.bootApplied : ""
  readonly property string bootAppliedTheme: service ? service.bootAppliedTheme : ""
  readonly property string bootNowName: {
    if (bootApplied.length === 0) return "Stock Omarchy"
    if (bootApplied === "theme") return "Theme colors"
    if (bootApplied.indexOf("snapshot:") === 0) {
      var sd = Designs.byId(bootApplied.substring(9))
      return (sd ? sd.name : bootApplied.substring(9)) + " (snapshot)"
    }
    if (bootApplied.indexOf("custom:") === 0) return bootApplied.substring(7)
    if (bootApplied.indexOf("video:") === 0) return bootApplied.substring(6).replace(/\.[^.]+$/, "")
    var d = Designs.byId(bootApplied)
    return d ? d.name : bootApplied
  }
  readonly property var bootVideos: service && service.bootVideos !== undefined ? service.bootVideos : []
  readonly property var bootCustomDesigns: service && service.bootCustomDesigns !== undefined ? service.bootCustomDesigns : []
  readonly property int bootClipSeconds: service && service.bootClipSeconds !== undefined ? service.bootClipSeconds : 0
  readonly property var bootCards: {
    var cards = [
      { id: "stock", name: "Untouched", kind: "stock Omarchy splash" },
      { id: "theme", name: "Theme colors", kind: "stock layout, your theme" }
    ]
    var claimed = {}
    var twins = Designs.bootCapable()
    for (var i = 0; i < twins.length; i++) {
      cards.push({ id: twins[i].id, name: twins[i].name, kind: bootKindLabel(twins[i]) + (twins[i].credit ? " \u00b7 by " + twins[i].credit : "") })
      if (twins[i].clipFile) claimed[twins[i].clipFile] = true
    }
    for (var v = 0; v < bootVideos.length; v++) {
      if (claimed[bootVideos[v]]) continue
      cards.push({ id: "video:" + bootVideos[v], name: bootVideos[v].replace(/\.[^.]+$/, ""), kind: "your clip \u00b7 plays on unlock" })
    }
    for (var c = 0; c < bootCustomDesigns.length; c++)
      cards.push({ id: "custom:" + bootCustomDesigns[c], name: bootCustomDesigns[c], kind: "your layout" })
    return cards
  }
  readonly property string bootFollowTarget: {
    if (bootSetting !== "follow") return ""
    var d = Designs.byId(activeDesignId)
    return d && d.boot === true ? d.id : ""
  }
  readonly property int bootPreviewsVersion: service && service.bootPreviewsVersion !== undefined ? service.bootPreviewsVersion : 0
  readonly property string bootCurrentTheme: service && service.bootCurrentTheme !== undefined ? service.bootCurrentTheme : ""

  function bootCardPreview(id) {
    var fileId = String(id).split(":").join("-")
    return "file://" + Quickshell.env("HOME") + "/.local/state/omarchy/lock-explorer-boot-previews/" + fileId + "-" + bootCurrentTheme + ".png?v=" + bootPreviewsVersion
  }

  property string bootEditing: ""
  property string bootEditorText: ""

  function openBootEditor(name) {
    root.mainTab = "editor"
    if (root.service && typeof root.service.loadBootDesign === "function") root.service.loadBootDesign(name)
  }

  // The unified layout editor works on a parsed key=value map; the form
  // controls edit known keys and serialize the whole map back, so keys the
  // form does not surface survive.
  property var bootFormMap: ({})
  property int bootFormRev: 0

  function bootFormGet(k, def) {
    var v = bootFormMap[k]
    return v === undefined ? def : v
  }
  // True from an edit until the previews caught up; drives the re-render
  // badge on the editor previews.
  property bool bootEditBusy: false

  function bootFormSet(k, v) {
    // A fresh object, or the var property emits no change signal and every
    // control bound through bootFormGet stays visually frozen.
    var m = Object.assign({}, bootFormMap)
    m[k] = String(v)
    bootFormMap = m
    bootFormRev++
    bootEditBusy = true
    bootFormSaveTimer.restart()
  }
  function bootFormParse(content) {
    var m = {}
    var lines = String(content).split("\n")
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i]
      if (/^\s*#/.test(line)) continue
      var eq = line.indexOf("=")
      if (eq === -1) continue
      var key = line.substring(0, eq).trim()
      if (key.length === 0) continue
      m[key] = line.substring(eq + 1).trim()
    }
    bootFormMap = m
    bootFormRev++
  }
  function bootFormSerialize() {
    var order = ["background", "scanlines", "logo", "logo_y", "logo_height",
                 "title", "title_y", "title_size", "title_color",
                 "subtitle", "subtitle_y", "subtitle_size", "subtitle_color",
                 "clock", "entry", "entry_y", "entry_width", "hint"]
    var out = "# Layout for a matching lock screen and boot screen.\n"
    var seen = {}
    for (var i = 0; i < order.length; i++) {
      var k = order[i]
      if (bootFormMap[k] !== undefined) { out += k + " = " + bootFormMap[k] + "\n"; seen[k] = true }
    }
    for (var k2 in bootFormMap)
      if (!seen[k2]) out += k2 + " = " + bootFormMap[k2] + "\n"
    return out
  }
  function saveBootForm() {
    if (bootEditing.length === 0) return
    if (service && typeof service.saveBootDesign === "function")
      service.saveBootDesign(bootEditing, bootFormSerialize())
  }

  Timer {
    id: bootFormSaveTimer
    interval: 400
    onTriggered: root.saveBootForm()
  }

  function closeBootEditor() {
    root.bootEditing = ""
    refocus()
  }

  // Escape is handled by the keyCatcher (the Omarchy layer-shell idiom); the
  // editor's text fields forward it via BootField.escaped().

  function saveBootDesignEdits() {
    if (root.bootEditing.length === 0) return
    if (root.service && typeof root.service.saveBootDesign === "function")
      root.service.saveBootDesign(root.bootEditing, bootEditorArea.text)
  }

  function newBootDesign() {
    root.mainTab = "editor"
    if (root.service && typeof root.service.createBootDesign === "function") root.service.createBootDesign()
  }

  readonly property var bootRotation: service && service.bootRotation !== undefined ? service.bootRotation : []
  readonly property bool bootRotating: bootSetting === "rotate"

  function toggleRotationMode() {
    if (root.bootApplying) return
    if (root.bootRotating) { root.setBoot(root.bootApplied.length > 0 ? root.bootApplied : "stock"); return }
    if (root.service && typeof root.service.enableBootRotation === "function") root.service.enableBootRotation()
  }

  function toggleInRotation(id) {
    if (root.service && typeof root.service.toggleBootRotation === "function") root.service.toggleBootRotation(id)
  }

  function inRotation(id) {
    return root.bootRotation.indexOf(id) !== -1
  }

  // Grab a full-resolution render of the active lock design and apply it as
  // a static boot background. The hidden host below does the rendering.
  // Whether the snapshot, once taken, is saved as the boot setting (a pinned
  // snapshot) or just applied as the artifact under a "follow" setting.
  property bool snapshotPersist: true

  function snapshotActiveDesign() { snapshotAndApply(root.activeDesignId, true) }

  // True while an off-screen snapshot is in flight; keeps the snapshot host's
  // wallpaper loaded even when the explorer is closed (theme-change resyncs
  // arrive with the panel down).
  property bool snapshotBusy: false
  property string snapshotRect: ""

  function snapshotAndApply(id, persist) {
    if (root.bootApplying) return
    root.snapshotBusy = true
    snapshotHost.designId = id
    // Flip snapshot mode before the render delay so any layout it causes has
    // settled long before the geometry is measured and the frame grabbed.
    if (snapshotHost.item && snapshotHost.item.snapshotMode !== undefined)
      snapshotHost.item.snapshotMode = true
    root.snapshotPersist = persist === undefined ? true : persist
    snapshotMkdirProc.running = true
  }

  Process {
    id: snapshotMkdirProc
    command: ["mkdir", "-p", Quickshell.env("HOME") + "/.local/state/omarchy/lock-explorer-snapshots"]
    onExited: function(code) {
      snapshotRenderTimer.restart()
    }
  }

  // Give the design a beat to load its wallpaper and lay out before grabbing.
  Timer {
    id: snapshotRenderTimer
    interval: 1100
    onTriggered: {
      var id = snapshotHost.designId
      var path = Quickshell.env("HOME") + "/.local/state/omarchy/lock-explorer-snapshots/" + id + ".png"
      // The design keeps its input box but empties it (see snapshotMode); the
      // boot theme puts its bullets inside that box, so the boot screen uses
      // the design's own field instead of a generic pill.
      var it = snapshotHost.item
      if (it && it.snapshotMode !== undefined) it.snapshotMode = true
      var rect = ""
      var n = it && it.inputItem ? it.inputItem : null
      while (n && n !== it && n.placeholder === undefined) n = n.parent
      if (n && n !== it && n.placeholder !== undefined && n.visible) {
        // Measure the input text area (inputItem sits between the lock glyph
        // and the eye), and carry the field's alignment so the bullets start
        // where the lock screen's dots would.
        var ia = it.inputItem
        var p = ia.mapToItem(snapshotSource, 0, 0)
        var align = n.textAlignment === TextInput.AlignLeft ? "left"
                  : n.textAlignment === TextInput.AlignRight ? "right" : "center"
        rect = (100 * (p.x + ia.width / 2) / 1920).toFixed(2) + "," + (100 * (p.y + ia.height / 2) / 1080).toFixed(2)
             + "," + (100 * ia.width / 1920).toFixed(2) + "," + (100 * ia.height / 1080).toFixed(2)
             + "," + align
      }
      var grabOk = snapshotSource.grabToImage(function(result) {
        var saved = result && result.saveToFile(path)
        if (root.service) root.service.logEvent("snapshot-grab " + id + (saved ? " ok rect=" + rect : " save-failed"))
        if (!saved) { root.snapshotBusy = false; return }
        root.snapshotRect = rect
        // Second, box-free grab: apply.sh picks it up as the background for
        // reboot/shutdown and promptless stretches of boot, so the splash
        // never shows a dead entry box (see snapshotBare in DesignBase).
        if (it && it.snapshotBare !== undefined) {
          it.snapshotBare = true
          snapshotBareTimer.restart()
        } else {
          root.snapshotFinish()
        }
      }, Qt.size(1920, 1080))
      if (!grabOk) {
        root.snapshotBusy = false
        if (root.service) root.service.logEvent("snapshot-grab-deferred " + id)
        // Never-shown window: park the request for the next open and say so.
        if (!root.pendingResnapshot) {
          root.pendingResnapshot = { id: id, persist: root.snapshotPersist }
          Quickshell.execDetached(["notify-send", "-a", "Lock Screen Explorer",
            "Boot screen is out of date",
            "The background changed. Open the lock screen explorer once and it refreshes itself."])
        }
      }
    }
  }

  // Wraps up a snapshot flow: resets the bare flag and hands the grabbed
  // frame(s) to the service. Split out because the box-free second grab
  // arrives asynchronously.
  function snapshotFinish() {
    root.snapshotBusy = false
    var it = snapshotHost.item
    if (it && it.snapshotBare !== undefined) it.snapshotBare = false
    if (root.service && typeof root.service.applyBootSnapshot === "function")
      root.service.applyBootSnapshot(snapshotHost.designId, root.snapshotPersist, root.snapshotRect)
  }

  // One frame is not reliably enough for the opacity change to land in the
  // next grab; a short settle keeps the box-free capture honest. If this grab
  // fails, snapshotFinish still applies: apply.sh only trusts a plain capture
  // newer than the snapshot, so a stale or missing file falls back cleanly.
  Timer {
    id: snapshotBareTimer
    interval: 150
    onTriggered: {
      var id = snapshotHost.designId
      var ppath = Quickshell.env("HOME") + "/.local/state/omarchy/lock-explorer-snapshots/" + id + "-plain.png"
      var ok = snapshotSource.grabToImage(function(result) {
        var saved = result && result.saveToFile(ppath)
        if (root.service) root.service.logEvent("snapshot-grab-plain " + id + (saved ? " ok" : " save-failed"))
        root.snapshotFinish()
      }, Qt.size(1920, 1080))
      if (!ok) root.snapshotFinish()
    }
  }

  // Apply a lock styling as the boot screen: its hand-written Plymouth twin if
  // it has one, otherwise a full-screen snapshot. This is what makes every
  // styling available for the boot screen too. persist=false keeps the boot
  // setting on "follow".
  function bootUseStyling(id, persist) {
    if (root.bootApplying) return
    var d = Designs.byId(id)
    if (d && d.boot === true) root.setBoot(id)
    else root.snapshotAndApply(id, persist === undefined ? true : persist)
  }

  function toggleFollow() {
    if (root.bootApplying) return
    // Just sets the desired choice; Apply builds it.
    if (root.bootSetting === "follow") root.setBoot("stock")
    else root.setBoot("follow")
  }

  // While following, re-match the boot screen when the lock styling changes.
  // Changing the lock styling under follow marks the boot screen dirty (via
  // bootWouldApply); it rebuilds only when Apply is pressed.

  readonly property string bootSetting: service ? service.bootSetting : "stock"
  readonly property bool bootApplying: service ? service.bootApplying : false
  readonly property string bootLabel: {
    if (bootApplying) return "applying..."
    if (bootSetting === "stock") return "Untouched"
    if (bootSetting === "theme") return "Theme colors"
    if (bootSetting === "follow") {
      var d = Designs.byId(activeDesignId)
      return d && d.boot === true ? "Match lock (" + d.name + ")" : "Match lock (no twin)"
    }
    var picked = Designs.byId(bootSetting)
    return picked ? picked.name : bootSetting
  }
  readonly property bool bootResync: service && service.bootResync !== undefined ? service.bootResync : true

  function setBoot(id) {
    if (root.bootApplying) return
    if (root.service && typeof root.service.setBoot === "function") root.service.setBoot(id)
  }

  function toggleBootResync() {
    if (root.service && typeof root.service.setBootResync === "function") root.service.setBootResync(!root.bootResync)
  }

  readonly property bool clipWallpaper: service && service.clipWallpaper !== undefined ? service.clipWallpaper : false

  function toggleClipWallpaper() {
    if (root.service && typeof root.service.setClipWallpaper === "function") root.service.setClipWallpaper(!root.clipWallpaper)
  }

  readonly property real clipSpeed: service && service.clipSpeed !== undefined ? service.clipSpeed : 1
  readonly property var clipSpeeds: [0.5, 0.75, 1, 1.25, 1.5, 2]

  function setClipSpeed(v) {
    if (root.service && typeof root.service.setClipSpeed === "function") root.service.setClipSpeed(v)
  }

  readonly property bool hasAvatar: avatarUrl.length > 0
  readonly property string userInitial: {
    var name = Quickshell.env("USER") || Quickshell.env("LOGNAME") || "user"
    return name.length > 0 ? name.charAt(0).toUpperCase() : "?"
  }

  readonly property color background: Color.menu.background
  readonly property color foreground: Color.menu.text
  readonly property color muted: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.6)
  readonly property color accent: Color.accent
  readonly property color scrim: Color.menu.scrim
  readonly property var borderSpec: Border.surfaceSpec("menu", "border", Color.menu.border, Math.max(1, Style.space(2)))
  // Redesign visual language: sharp corners, everforest-style typography.
  // Colors still follow the Omarchy theme.
  readonly property int cornerRadius: 0
  readonly property string fontFamily: Style.font.menuFamily
  readonly property int sidebarW: Style.space(172)
  readonly property int rightPanelW: Style.space(348)
  readonly property string bootAppliedId: bootApplied.length > 0 ? bootApplied : "stock"

  // What the current boot choice WOULD install, and whether that differs from
  // what is on disk — the Apply button and banner key off this. Nothing is
  // rebuilt until Apply is pressed.
  readonly property string bootWouldApply: {
    if (bootSetting === "stock") return "stock"
    if (bootSetting === "theme") return "theme"
    if (bootSetting.indexOf("snapshot:") === 0) return bootSetting
    if (bootSetting.indexOf("custom:") === 0 || bootSetting.indexOf("video:") === 0) return bootSetting
    if (bootSetting === "follow") {
      var d = Designs.byId(activeDesignId)
      return d && d.boot === true ? d.id : "snapshot:" + activeDesignId
    }
    return bootSetting
  }
  readonly property bool bootDirty: !bootApplying && bootWouldApply !== bootAppliedId
  readonly property string bootDesiredName: {
    var w = bootWouldApply
    if (w === "stock") return "Untouched"
    if (w === "theme") return "Theme colors"
    if (w.indexOf("snapshot:") === 0) {
      var sd = Designs.byId(w.substring(9))
      return (sd ? sd.name : w.substring(9)) + " (snapshot)"
    }
    if (w.indexOf("custom:") === 0) return w.substring(7)
    if (w.indexOf("video:") === 0) return w.substring(6).replace(/\.[^.]+$/, "")
    var d = Designs.byId(w)
    return d ? d.name : w
  }

  function applyPendingBoot() {
    if (root.bootApplying) return
    var w = root.bootWouldApply
    if (w.indexOf("snapshot:") === 0) {
      // follow-without-twin keeps the "follow" setting; a pinned snapshot persists.
      root.snapshotAndApply(w.substring(9), root.bootSetting !== "follow")
      return
    }
    if (root.service && typeof root.service.applyBoot === "function") root.service.applyBoot(true, w)
  }
  readonly property string currentThemeName: service && service.bootCurrentTheme !== undefined && service.bootCurrentTheme.length > 0 ? service.bootCurrentTheme : "your theme"

  readonly property int columns: 3
  readonly property int contentMargin: Style.spacing.panelPadding + Style.space(8)
  readonly property int gap: Style.space(20)
  readonly property int captionHeight: Style.space(58)
  readonly property int headerHeight: Style.space(96)
  readonly property int footerHeight: Style.space(40)
  readonly property int borderWidth: Math.max(1, Style.space(2))
  readonly property int cardWidth: Math.min(Style.space(1560), panel.width - Style.gapsOut * 4)
  readonly property int cardHeight: panel.height - Style.gapsOut * 2
  readonly property int cellWidth: Math.floor(grid.width / columns)
  readonly property int thumbWidth: cellWidth - gap
  readonly property int thumbHeight: Math.round(thumbWidth * 9 / 16)

  // Tab asked for via `omarchy-shell lock exploreTab <tab>`; open() resets to
  // styling otherwise, so the request has to survive the summon.
  property string requestedTab: ""

  function open(payloadJson) {
    root.opened = true
    root.fullPreview = false
    root.mainTab = root.requestedTab.length > 0 ? root.requestedTab : "styling"
    root.requestedTab = ""
    root.category = "all"
    var idx = Designs.indexOf(root.activeDesignId)
    root.selectedIndex = idx >= 0 ? idx : 0
    if (root.service) {
      if (typeof root.service.rescanUserDesigns === "function") root.service.rescanUserDesigns()
      if (typeof root.service.refreshBackground === "function") root.service.refreshBackground()
      if (typeof root.service.refreshFingerprintStatus === "function") root.service.refreshFingerprintStatus()
    }
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
    revealTimer.restart()
  }

  Timer {
    id: revealTimer
    interval: 80
    onTriggered: {
      root.reveal(GridView.Center)
      keyCatcher.forceActiveFocus()
    }
  }

  function close() { root.opened = false }

  function dismiss() {
    root.opened = false
    root.fullPreview = false
    root.mainTab = "styling"
    root.editing = false
    root.editingDesign = null
    if (root.shell && typeof root.shell.hide === "function") root.shell.hide(root.pluginId)
  }

  function toggle() {
    if (root.opened) root.dismiss()
    else root.open("{}")
  }

  function positionAtSelected(mode) {
    grid.positionViewAtIndex(root.selectedIndex, mode)
    var minY = grid.originY - grid.topMargin
    var maxY = Math.max(minY, grid.originY + grid.contentHeight - grid.height + grid.bottomMargin)
    if (grid.contentY < minY) grid.contentY = minY
    else if (grid.contentY > maxY) grid.contentY = maxY
  }

  function reveal(mode) {
    positionAtSelected(mode)
    Qt.callLater(function() { positionAtSelected(mode) })
  }

  function setCategory(id) {
    if (id === root.category) return
    var current = root.selectedDesign ? root.selectedDesign.id : ""
    root.category = id
    var list = Designs.inCategory(id)
    var keep = -1
    for (var i = 0; i < list.length; i++) if (list[i].id === current) keep = i
    root.selectedIndex = keep >= 0 ? keep : 0
    reveal(GridView.Contain)
  }

  function cycleCategory(delta) {
    var n = categories.length
    var cur = 0
    for (var i = 0; i < n; i++) if (categories[i].id === root.category) cur = i
    setCategory(categories[(cur + delta + n) % n].id)
  }

  function move(delta) {
    var n = designs.length
    if (n === 0) return
    selectedIndex = (selectedIndex + delta + n) % n
    reveal(GridView.Contain)
  }

  function moveRow(delta) {
    var next = selectedIndex + delta * columns
    if (next < 0 || next >= designs.length) return
    selectedIndex = next
    reveal(GridView.Contain)
  }

  function selectById(id) {
    var list = root.designs
    for (var i = 0; i < list.length; i++) if (list[i].id === id) { root.selectedIndex = i; reveal(GridView.Contain); return true }
    return false
  }

  // The overlay owns the keyboard, so the file dialog needs it out of the way.
  // The service brings the explorer back when the dialog is answered.
  function pickAvatar() {
    if (!root.service) return
    root.dismiss()
    root.service.pickAvatar(true)
  }

  function clearAvatar() {
    if (root.service) root.service.clearAvatar()
  }

  // Same story as the avatar: the dialog needs the keyboard, so step aside.
  function pickVideo(target) {
    if (!root.service) return
    root.dismiss()
    root.service.pickVideo(true, target || "video")
  }

  // Your own video as an unlock clip: pick a file, the service writes the
  // one-line ClipDesign and it appears under Animation.
  function newClipDesign() {
    root.pickVideo("clip")
  }

  function clearVideo() {
    if (root.service) root.service.clearVideo()
  }

  function clearSting() {
    if (root.service) root.service.clearSting()
  }

  function previewSting() {
    if (!root.service || !root.service.stingPath) return
    root.dismiss()
    root.service.playSting()
  }

  function setUnlock(id) {
    if (root.service) root.service.setUnlockAnimation(id)
  }

  function setUnlockDuration(ms) {
    if (root.service) root.service.setUnlockDuration(ms)
  }

  function setBlankAfter(ms) {
    if (!root.service) return
    root.customDelayEditing = false
    if (ms === 0) {
      root.service.setKeepDisplayOn(true)
      return
    }
    root.service.setKeepDisplayOn(false)
    root.service.setBlankDelay(ms)
  }

  function beginCustomDelay() {
    root.customDelayText = root.keepDisplayOn ? "" : String(Math.max(1, Math.round(root.blankDelay / 60000)))
    root.customDelayEditing = true
  }

  function commitCustomDelay() {
    var minutes = Math.round(Number(root.customDelayText))
    if (!isFinite(minutes) || minutes < 1 || minutes > 60) return
    if (!root.service) return
    root.service.setKeepDisplayOn(false)
    root.service.setBlankDelay(minutes * 60000)
    root.customDelayEditing = false
  }

  function customizeSelected() {
    if (!root.selectedDesign || !root.service) return
    if (root.selectedDesign.path) { openEditor(root.selectedDesign); return }
    root.service.customizeDesign(root.selectedDesign.id)
  }

  function newDesign() {
    if (root.service) root.service.customizeDesign("new")
  }

  function openEditor(design) {
    if (!design || !design.path) return
    root.editingDesign = design
    root.editing = true
    root.fullPreview = false
    Qt.callLater(function() { editorView.focusCode() })
  }

  function closeEditor() {
    root.editing = false
    root.editingDesign = null
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function openExternal(path) {
    Quickshell.execDetached(["omarchy-launch-editor", path])
    root.dismiss()
  }

  Connections {
    target: root.service
    ignoreUnknownSignals: true
    function onBootDesignLoaded(name, content) {
      root.bootFormParse(content)
      root.bootEditing = name
      root.mainTab = "editor"
    }
    function onDesignCustomized(id, path) {
      if (!root.opened) return
      root.setCategory("custom")
      Qt.callLater(function() {
        root.selectById(id)
        var d = Designs.byId(id)
        if (d) root.openEditor(d)
      })
    }
    function onClipDesignAdded(id) {
      root.mainTab = "animation"
      Qt.callLater(function() { root.selectById(id) })
    }
    function onBootPreviewsVersionChanged() {
      if (root.service && !root.service.bootPreviewsRunning && !root.service.bootPreviewsPending)
        root.bootEditBusy = false
    }
    function onExploreTabRequested(tab) {
      if (tab !== "styling" && tab !== "animation" && tab !== "boot" && tab !== "settings") return
      // summon() re-runs open() even when already open, and open() resets the
      // tab — stash the request so it survives either path.
      root.requestedTab = tab
      if (root.opened) root.mainTab = tab
    }
    // Theme changed under an applied snapshot: retake it under the new theme.
    function onBootResnapshotRequested(designId, persist) {
      if (root.service) root.service.logEvent("resnapshot-request " + designId)
      root.snapshotAndApply(designId, persist)
    }
  }

  function apply() {
    if (!selectedDesign) return
    if (root.service && typeof root.service.setDesign === "function") root.service.setDesign(selectedDesign.id)
    root.dismiss()
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-lock-explorer"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    // Off-screen full-resolution render used to snapshot a lock design into a
    // boot background. Parked far outside the panel so it never shows.
    Item {
      id: snapshotSource
      x: -4000; y: -4000
      width: 1920; height: 1080
      LockHost {
        id: snapshotHost
        anchors.fill: parent
        designId: root.activeDesignId
        revision: root.service ? root.service.designsRevision : 0
        backgroundPath: root.service ? root.service.backgroundPath : ""
        backgroundVersion: root.service ? root.service.backgroundVersion : 0
        avatarPath: root.service ? root.service.avatarPath : ""
        avatarVersion: root.service ? root.service.avatarVersion : 0
        inputEnabled: false
        loadBackground: root.opened || root.snapshotBusy
        passwordText: ""
        videoPath: root.service ? root.service.videoPath : ""
        videoPlaying: false
      }
    }

    Rectangle { anchors.fill: parent; color: root.scrim }
    MouseArea { anchors.fill: parent; onClicked: root.dismiss() }

    Item {
      id: keyCatcher
      anchors.fill: parent
      focus: true
      Keys.priority: Keys.BeforeItem
      // Embedded lock previews can pull keyboard focus; reclaim it whenever
      // it drifts, except while a real editor field wants it.
      onActiveFocusChanged: {
        if (!activeFocus && root.opened && root.bootEditing.length === 0 && !root.editing)
          Qt.callLater(function() { keyCatcher.forceActiveFocus() })
      }
      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) { root.handleEscape(); event.accepted = true; return }
        if (root.editing) return
        if (root.bootEditing.length > 0) return
        if (root.mainTab !== "styling" && root.mainTab !== "animation") {
          if (event.key === Qt.Key_U) { root.toggleSettings("settings"); event.accepted = true }
          else if (event.key === Qt.Key_B) { root.toggleSettings("boot"); event.accepted = true }
          return
        }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
          root.apply(); event.accepted = true
        } else if (event.key === Qt.Key_Space || event.key === Qt.Key_P) {
          root.fullPreview = !root.fullPreview; event.accepted = true
        } else if (event.key === Qt.Key_C) {
          root.customizeSelected(); event.accepted = true
        } else if (event.key === Qt.Key_E) {
          if (root.selectedDesign && root.selectedDesign.path) root.openEditor(root.selectedDesign)
          else root.customizeSelected()
          event.accepted = true
        } else if (event.key === Qt.Key_N) {
          root.newDesign(); event.accepted = true
        } else if (event.key === Qt.Key_X || event.key === Qt.Key_Delete) {
          root.deleteSelected(); event.accepted = true
        } else if (event.key === Qt.Key_A) {
          if (event.modifiers & Qt.ShiftModifier) root.clearAvatar()
          else root.pickAvatar()
          event.accepted = true
        } else if (event.key === Qt.Key_V) {
          if (event.modifiers & Qt.ShiftModifier) root.clearVideo()
          else root.pickVideo("video")
          event.accepted = true
        } else if (event.key === Qt.Key_S) {
          if (event.modifiers & Qt.ShiftModifier) root.clearSting()
          else root.pickVideo("sting")
          event.accepted = true
        } else if (event.key === Qt.Key_U) {
          root.toggleSettings("settings")
          event.accepted = true
        } else if (event.key === Qt.Key_B) {
          root.toggleSettings("boot")
          event.accepted = true
        } else if (event.key === Qt.Key_Tab) {
          root.cycleCategory(1); event.accepted = true
        } else if (event.key === Qt.Key_Backtab) {
          root.cycleCategory(-1); event.accepted = true
        } else if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
          root.move(-1); event.accepted = true
        } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
          root.move(1); event.accepted = true
        } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
          if (root.fullPreview) root.move(-1); else root.moveRow(-1)
          event.accepted = true
        } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
          if (root.fullPreview) root.move(1); else root.moveRow(1)
          event.accepted = true
        } else if (event.key === Qt.Key_Home) {
          root.selectedIndex = 0; root.reveal(GridView.Beginning); event.accepted = true
        } else if (event.key === Qt.Key_End) {
          root.selectedIndex = Math.max(0, root.designs.length - 1); root.reveal(GridView.End); event.accepted = true
        } else if (event.key === Qt.Key_PageDown) {
          grid.contentY = Math.min(grid.contentHeight - grid.height, grid.contentY + grid.height); event.accepted = true
        } else if (event.key === Qt.Key_PageUp) {
          grid.contentY = Math.max(0, grid.contentY - grid.height); event.accepted = true
        }
      }
    }

    BorderSurface {
      id: card
      visible: !root.fullPreview && !root.editing
      width: root.cardWidth
      height: root.cardHeight
      radius: root.cornerRadius
      anchors.centerIn: parent
      color: root.background
      borderSpec: root.borderSpec
      padding: root.contentMargin

      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        id: header
        z: 10
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: card.contentTopInset
        anchors.leftMargin: card.contentLeftInset
        anchors.rightMargin: card.contentRightInset
        height: root.headerHeight

        Column {
          anchors.left: parent.left
          anchors.top: parent.top
          spacing: 3
          Row {
            spacing: Style.space(8)
            Text {
              text: "::"
              color: root.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
              font.weight: Font.Bold
            }
            Text {
              text: "LOCK SCREEN EXPLORER"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
              font.weight: Font.Bold
              font.letterSpacing: 2
            }
          }
          Text {
            text: {
              if (root.wallpaperBroken) return "Wallpaper failed to load" + (root.wallpaperIsWebp ? " — WebP needs:  sudo pacman -S qt6-imageformats  (then omarchy restart shell)" : "")
              if (root.mainTab === "settings") return "Unlock transition, avatar and sign-in monitor"
              if (root.mainTab === "boot") return "The disk-passphrase screen at first boot · experimental — a broken theme falls back to a plain text prompt"
              if (root.mainTab === "animation") return Designs.animations().length + " animated lock screens"
              if (root.mainTab === "editor") return root.bootEditing.length > 0 ? "Editing " + root.bootEditing : "Make a matching lock screen and boot screen"
              return (root.mainTab === "styling" ? Designs.stylings().length + " lock screen stylings · " : "") + root.currentThemeName + " · follows your theme"
            }
            color: root.wallpaperBroken ? "#c96a6a" : root.muted
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
        }

        Row {
          id: headerButtons
          anchors.right: parent.right
          anchors.top: parent.top
          spacing: Style.space(8)

          // Avatar button: click to pick a picture with the normal file
          // dialog, the x clears it back to the user's initial.
          Rectangle {
            id: avatarButton
            height: Style.space(28)
            width: avatarRow.implicitWidth + Style.space(16)
            radius: root.cornerRadius
            color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, avatarArea.containsMouse ? 0.14 : 0.07)
            border.width: 1
            border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.15)
            Behavior on color { ColorAnimation { duration: 100 } }

            Row {
              id: avatarRow
              anchors.centerIn: parent
              spacing: Style.space(8)

              Avatar {
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(20)
                source: root.avatarUrl
                initial: root.userInitial
                fontSize: Style.font.caption
                fillColor: root.accent
                textColor: Color.background
                shadow: false
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.hasAvatar ? "Avatar" : "Add avatar"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.hasAvatar
                text: "✕"
                color: clearArea.containsMouse ? root.foreground : root.muted
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                MouseArea {
                  id: clearArea
                  anchors.fill: parent
                  anchors.margins: -Style.space(4)
                  hoverEnabled: true
                  onClicked: root.clearAvatar()
                }
              }
            }

            MouseArea {
              id: avatarArea
              anchors.fill: parent
              hoverEnabled: true
              z: -1
              onClicked: root.pickAvatar()
            }
          }

          Rectangle {
            anchors.verticalCenter: avatarButton.verticalCenter
            width: activeLabel.implicitWidth + Style.space(20); height: Style.space(28); radius: root.cornerRadius
            color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.18)
            border.width: 1; border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.5)
            Text {
              id: activeLabel
              anchors.centerIn: parent
              text: "Active: " + (Designs.byId(root.activeDesignId) ? Designs.byId(root.activeDesignId).name : root.activeDesignId)
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
          }
        }

        // (tabs moved to the left sidebar)

        // Category chips removed in the redesign (the sidebar splits stylings
        // from animations instead).
        Row {
          visible: false
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          anchors.bottomMargin: Style.space(10)
          spacing: Style.space(8)
          Repeater {
            model: root.categories
            Rectangle {
              id: chip
              required property var modelData
              readonly property bool current: modelData.id === root.category
              width: chipLabel.implicitWidth + Style.space(24)
              height: Style.space(30)
              radius: root.cornerRadius
              color: current ? root.accent : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, chipArea.containsMouse ? 0.12 : 0.06)
              border.width: 1
              border.color: current ? root.accent : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.15)
              Behavior on color { ColorAnimation { duration: 100 } }
              Text {
                id: chipLabel
                anchors.centerIn: parent
                text: chip.modelData.name
                color: chip.current ? Color.background : root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                font.weight: chip.current ? Font.DemiBold : Font.Normal
              }
              MouseArea {
                id: chipArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.setCategory(chip.modelData.id)
              }
            }
          }
        }

        // The two settings pages live where the grid otherwise is.
        Item {
          id: settingsPane
          visible: root.mainTab !== "styling" && root.mainTab !== "animation"
          anchors.top: parent.bottom
          anchors.topMargin: Style.space(6)
          anchors.left: parent.left
          anchors.leftMargin: root.sidebarW + Style.space(20)
          anchors.right: parent.right
          anchors.rightMargin: root.mainTab === "editor" ? Style.space(40) : root.rightPanelW + Style.space(40)
          // Sized against the card (footer is not a sibling, so no anchor),
          // clipped and scrollable so tall content never draws over the nav.
          height: card.height - root.headerHeight - root.footerHeight - Style.space(44)

          Flickable {
            anchors.fill: parent
            clip: true
            contentWidth: width
            contentHeight: settingsColumn.implicitHeight + Style.space(20)
            boundsBehavior: Flickable.StopAtBounds
            flickDeceleration: 4000

          Column {
            id: settingsColumn
            width: settingsPane.width
            spacing: Style.space(14)

            Column {
              width: parent.width
              visible: root.mainTab === "settings"
              spacing: Style.space(10)

              Column {
                spacing: Style.space(2)
                Repeater {
                  model: root.unlockOptions
                  Rectangle {
                    id: unlockOptionRow
                    required property var modelData
                    readonly property bool current: modelData.id === root.unlockAnimation
                    width: Style.space(400)
                    height: Style.space(42)
                    radius: root.cornerRadius
                    color: current ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.14)
                                   : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, unlockOptionArea.containsMouse ? 0.07 : 0.0)
                    Behavior on color { ColorAnimation { duration: 100 } }

                    Rectangle {
                      id: unlockOptionRadio
                      anchors.verticalCenter: parent.verticalCenter
                      anchors.left: parent.left
                      anchors.leftMargin: Style.space(10)
                      width: Style.space(16)
                      height: Style.space(16)
                      radius: width / 2
                      color: "transparent"
                      border.width: Math.max(1, Style.space(2))
                      border.color: unlockOptionRow.current ? root.accent : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.4)

                      Rectangle {
                        anchors.centerIn: parent
                        width: Style.space(8)
                        height: Style.space(8)
                        radius: width / 2
                        color: root.accent
                        visible: unlockOptionRow.current
                      }
                    }

                    Column {
                      anchors.verticalCenter: parent.verticalCenter
                      anchors.left: unlockOptionRadio.right
                      anchors.leftMargin: Style.space(10)
                      spacing: 1

                      Text {
                        text: unlockOptionRow.modelData.name
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.bodySmall
                        font.weight: unlockOptionRow.current ? Font.DemiBold : Font.Normal
                      }

                      Text {
                        text: unlockOptionRow.modelData.hint
                        color: root.muted
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                      }
                    }

                    MouseArea {
                      id: unlockOptionArea
                      anchors.fill: parent
                      hoverEnabled: true
                      onClicked: root.setUnlock(unlockOptionRow.modelData.id)
                    }
                  }
                }
              }

              Row {
                visible: root.unlockAnimation !== "none"
                spacing: Style.space(6)

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: "Length"
                  color: root.muted
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }

                Repeater {
                  model: root.unlockDurations
                  Rectangle {
                    id: speed
                    required property int modelData
                    readonly property bool current: modelData === root.unlockDuration
                    width: speedLabel.implicitWidth + Style.space(18)
                    height: Style.space(26)
                    radius: root.cornerRadius
                    color: current ? root.accent : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, speedArea.containsMouse ? 0.12 : 0.06)
                    Behavior on color { ColorAnimation { duration: 100 } }

                    Text {
                      id: speedLabel
                      anchors.centerIn: parent
                      text: (speed.modelData / 1000).toFixed(1) + "s"
                      color: speed.current ? Color.background : root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      font.weight: speed.current ? Font.DemiBold : Font.Normal
                    }

                    MouseArea {
                      id: speedArea
                      anchors.fill: parent
                      hoverEnabled: true
                      onClicked: root.setUnlockDuration(speed.modelData)
                    }
                  }
                }
              }

              Text {
                text: "The lock screen stays up while it plays."
                color: root.muted
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }

              // Clip designs land on their own last frame as the wallpaper.
              Rectangle {
                width: clipWallRow.implicitWidth + Style.space(8)
                height: Style.space(30)
                color: "transparent"

                Row {
                  id: clipWallRow
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(8)

                  Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Style.space(18)
                    height: Style.space(18)
                    radius: root.cornerRadius
                    color: root.clipWallpaper ? root.accent : "transparent"
                    border.width: Math.max(1, Style.space(2))
                    border.color: root.clipWallpaper ? root.accent : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.4)

                    Text {
                      anchors.centerIn: parent
                      visible: root.clipWallpaper
                      text: "✓"
                      color: Color.background
                      font.pixelSize: Style.font.caption
                      font.weight: Font.Bold
                    }
                  }

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Unlock video ends as your wallpaper"
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }
                }

                MouseArea {
                  anchors.fill: parent
                  anchors.margins: -Style.space(4)
                  onClicked: root.toggleClipWallpaper()
                }
              }

              Text {
                text: "The desktop opens on the frame the clip stopped on, set with omarchy-theme-bg-set."
                color: root.muted
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }

              // How long the lock screen stays lit before the display blanks.
              // Never keeps it powered for the whole lock: video designs keep
              // playing and slow monitors are never re-blanked mid-wake.
              Row {
                visible: true
                spacing: Style.space(6)

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: "Blank the display after"
                  color: root.muted
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }

                Repeater {
                  model: [
                    { ms: 5000, name: "5s" },
                    { ms: 15000, name: "15s" },
                    { ms: 30000, name: "30s" },
                    { ms: 60000, name: "1m" },
                    { ms: 300000, name: "5m" },
                    { ms: -1, name: "Custom" },
                    { ms: 0, name: "Never" }
                  ]
                  Rectangle {
                    id: blankChip
                    required property var modelData
                    readonly property bool current: modelData.ms === 0 ? root.keepDisplayOn
                                                                       : modelData.ms === -1 ? root.blankDelayIsCustom
                                                                       : (!root.keepDisplayOn && root.blankDelay === modelData.ms)
                    width: blankChipLabel.implicitWidth + Style.space(18)
                    height: Style.space(26)
                    radius: root.cornerRadius
                    color: current ? root.accent : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, blankChipArea.containsMouse ? 0.12 : 0.06)
                    Behavior on color { ColorAnimation { duration: 100 } }

                    Text {
                      id: blankChipLabel
                      anchors.centerIn: parent
                      text: blankChip.modelData.name
                      color: blankChip.current ? Color.background : root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      font.weight: blankChip.current ? Font.DemiBold : Font.Normal
                    }

                    MouseArea {
                      id: blankChipArea
                      anchors.fill: parent
                      hoverEnabled: true
                      onClicked: {
                        if (blankChip.modelData.ms === -1) root.beginCustomDelay()
                        else root.setBlankAfter(blankChip.modelData.ms)
                      }
                    }
                  }
                }

                Rectangle {
                  visible: root.customDelayEditing
                  width: Style.space(110)
                  height: Style.space(26)
                  radius: root.cornerRadius
                  color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.06)
                  border.width: Math.max(1, Style.space(2))
                  border.color: root.accent

                  // The unit hint lives inside the box, right-aligned, and the
                  // input reserves its width so typed digits never run under it.
                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: Style.space(8)
                    text: "m, Enter"
                    color: root.muted
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }

                  TextInput {
                    id: customDelayInput
                    anchors.fill: parent
                    anchors.leftMargin: Style.space(8)
                    anchors.rightMargin: Style.space(52)
                    verticalAlignment: TextInput.AlignVCenter
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    text: root.customDelayText
                    onTextEdited: root.customDelayText = text
                    focus: root.customDelayEditing
                    validator: IntValidator { bottom: 1; top: 60 }

                    Keys.onEscapePressed: root.customDelayEditing = false
                    Keys.onReturnPressed: root.commitCustomDelay()
                  }
                }
              }

              Text {
                text: root.keepDisplayOn
                      ? "The lock screen stays lit for the whole lock: video designs keep playing."
                      : "The lock screen stays lit, then the display powers down."
                color: root.muted
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }

              // Playback rate for the clip designs and the separate unlock clip.
              Row {
                spacing: Style.space(6)

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: "Clip speed"
                  color: root.muted
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }

                Repeater {
                  model: root.clipSpeeds
                  Rectangle {
                    id: clipSpeedChip
                    required property real modelData
                    readonly property bool current: Math.abs(modelData - root.clipSpeed) < 0.01
                    width: clipSpeedLabel.implicitWidth + Style.space(18)
                    height: Style.space(26)
                    radius: root.cornerRadius
                    color: current ? root.accent : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, clipSpeedArea.containsMouse ? 0.12 : 0.06)
                    Behavior on color { ColorAnimation { duration: 100 } }

                    Text {
                      id: clipSpeedLabel
                      anchors.centerIn: parent
                      text: clipSpeedChip.modelData + "x"
                      color: clipSpeedChip.current ? Color.background : root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      font.weight: clipSpeedChip.current ? Font.DemiBold : Font.Normal
                    }

                    MouseArea {
                      id: clipSpeedArea
                      anchors.fill: parent
                      hoverEnabled: true
                      onClicked: root.setClipSpeed(clipSpeedChip.modelData)
                    }
                  }
                }
              }
            }

            Column {
              // Sized to the pane, not to the widest child: children bind to
              // parent.width, so an unset width here balloons to the longest
              // unwrapped text and pushes the Apply button under the preview.
              width: parent.width
              visible: root.mainTab === "boot" || root.mainTab === "editor"
              spacing: Style.space(14)

              Text {
                visible: root.mainTab === "boot"
                width: parent.width
                wrapMode: Text.WordWrap
                text: "Now: " + root.bootNowName + (root.bootAppliedTheme.length > 0 ? " \u00b7 baked from " + root.bootAppliedTheme : "")
                color: root.muted
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
              }

              // Apply banner: nothing is built until you press Apply.
              Rectangle {
                visible: root.mainTab === "boot" && (root.bootDirty || root.bootApplying)
                width: parent.width
                height: applyBannerRow.implicitHeight + Style.space(20)
                color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.10)
                border.width: 1
                border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.4)

                Row {
                  id: applyBannerRow
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.leftMargin: Style.space(14)
                  anchors.rightMargin: Style.space(14)
                  spacing: Style.space(14)

                  Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Style.space(8); height: Style.space(8); radius: width / 2
                    color: root.accent
                  }

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - applyBtn.width - Style.space(50)
                    wrapMode: Text.WordWrap
                    text: root.bootApplying
                      ? "Applying the boot theme\u2026"
                      : "Set to " + root.bootDesiredName + ". Applying writes the boot theme to the EFI partition and asks for your password."
                    color: Color.menu.text
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }

                  Rectangle {
                    id: applyBtn
                    anchors.verticalCenter: parent.verticalCenter
                    width: applyBtnLabel.implicitWidth + Style.space(24)
                    height: Style.space(30)
                    radius: root.cornerRadius
                    opacity: root.bootApplying ? 0.5 : 1
                    color: root.accent
                    Text {
                      id: applyBtnLabel
                      anchors.centerIn: parent
                      text: root.bootApplying ? "Building\u2026" : "Apply"
                      color: Color.background
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.bodySmall
                      font.weight: Font.DemiBold
                    }
                    MouseArea {
                      anchors.fill: parent
                      enabled: !root.bootApplying
                      onClicked: root.applyPendingBoot()
                    }
                  }
                }
              }

              Row {
                visible: root.mainTab === "boot"
                spacing: Style.space(20)

                Rectangle {
                  width: followRow.implicitWidth + Style.space(8)
                  height: Style.space(30)
                  color: "transparent"

                  Row {
                    id: followRow
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(8)

                    Rectangle {
                      anchors.verticalCenter: parent.verticalCenter
                      width: Style.space(18)
                      height: Style.space(18)
                      radius: root.cornerRadius
                      color: root.bootSetting === "follow" ? root.accent : "transparent"
                      border.width: Math.max(1, Style.space(2))
                      border.color: root.bootSetting === "follow" ? root.accent : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.4)

                      Text {
                        anchors.centerIn: parent
                        visible: root.bootSetting === "follow"
                        text: "\u2713"
                        color: Color.background
                        font.pixelSize: Style.font.caption
                        font.weight: Font.Bold
                      }
                    }

                    Column {
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: 0

                      Text {
                        text: "Follow my lock screen"
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                      }

                      Text {
                        text: root.followHint
                        color: root.muted
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                      }
                    }
                  }

                  MouseArea {
                    anchors.fill: parent
                    anchors.margins: -Style.space(4)
                    onClicked: root.toggleFollow()
                  }
                }

                Rectangle {
                  width: resyncRow.implicitWidth + Style.space(8)
                  height: Style.space(30)
                  color: "transparent"

                  Row {
                    id: resyncRow
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(8)

                    Rectangle {
                      anchors.verticalCenter: parent.verticalCenter
                      width: Style.space(18)
                      height: Style.space(18)
                      radius: root.cornerRadius
                      color: root.bootResync ? root.accent : "transparent"
                      border.width: Math.max(1, Style.space(2))
                      border.color: root.bootResync ? root.accent : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.4)

                      Text {
                        anchors.centerIn: parent
                        visible: root.bootResync
                        text: "\u2713"
                        color: Color.background
                        font.pixelSize: Style.font.caption
                        font.weight: Font.Bold
                      }
                    }

                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      text: "Re-apply when the Omarchy theme changes"
                      color: root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                    }
                  }

                  MouseArea {
                    anchors.fill: parent
                    anchors.margins: -Style.space(4)
                    onClicked: root.toggleBootResync()
                  }
                }

                Rectangle {
                  // Rotation ships hidden in 1.5.0: enabling it installs a
                  // passwordless-root helper (rotate-setup.sh) that has not
                  // been tested end to end. Flip visible when that lands.
                  visible: false
                  width: rotateRow.implicitWidth + Style.space(8)
                  height: Style.space(30)
                  color: "transparent"

                  Row {
                    id: rotateRow
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(8)

                    Rectangle {
                      anchors.verticalCenter: parent.verticalCenter
                      width: Style.space(18)
                      height: Style.space(18)
                      radius: root.cornerRadius
                      color: root.bootRotating ? root.accent : "transparent"
                      border.width: Math.max(1, Style.space(2))
                      border.color: root.bootRotating ? root.accent : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.4)

                      Text {
                        anchors.centerIn: parent
                        visible: root.bootRotating
                        text: "\u2713"
                        color: Color.background
                        font.pixelSize: Style.font.caption
                        font.weight: Font.Bold
                      }
                    }

                    Column {
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: 0

                      Text {
                        text: "Rotate boot screens"
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                      }

                      Text {
                        // The toggles row can meet the preview panel; give in
                        // gracefully instead of drawing under it.
                        width: Math.min(implicitWidth, Style.space(230))
                        elide: Text.ElideRight
                        text: root.bootRotating
                          ? "Tick the cards below \u00b7 advances one per boot (" + root.bootRotation.length + " picked)"
                          : "A different one each boot, set up once"
                        color: root.muted
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                      }
                    }
                  }

                  MouseArea {
                    anchors.fill: parent
                    anchors.margins: -Style.space(4)
                    onClicked: root.toggleRotationMode()
                  }
                }
              }

              Row {
                visible: root.mainTab === "boot"
                spacing: Style.space(6)

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Clip length"
                    color: root.muted
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }

                  Repeater {
                    model: [0, 2, 4, 6]
                    Rectangle {
                      id: clipLen
                      required property int modelData
                      readonly property bool current: modelData === root.bootClipSeconds
                      width: clipLenLabel.implicitWidth + Style.space(16)
                      height: Style.space(24)
                      radius: root.cornerRadius
                      color: current ? root.accent : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, clipLenArea.containsMouse ? 0.12 : 0.06)
                      Behavior on color { ColorAnimation { duration: 100 } }

                      Text {
                        id: clipLenLabel
                        anchors.centerIn: parent
                        text: clipLen.modelData === 0 ? "Full" : clipLen.modelData + "s"
                        color: clipLen.current ? Color.background : root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        font.weight: clipLen.current ? Font.DemiBold : Font.Normal
                      }

                      MouseArea {
                        id: clipLenArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.setBootClipSeconds(clipLen.modelData)
                      }
                    }
                  }
                }

              Flow {
                visible: root.mainTab === "boot"
                width: card.width - root.sidebarW - root.rightPanelW - Style.space(120)
                spacing: Style.space(14)

                Repeater {
                  model: root.bootCards
                  Column {
                    id: bootCard
                    required property var modelData
                    readonly property bool picked: root.bootSetting === modelData.id || root.bootFollowTarget === modelData.id
                    readonly property bool onDisk: root.bootApplied === modelData.id || (modelData.id === "stock" && root.bootApplied.length === 0)
                    readonly property bool editable: modelData.id.indexOf("custom:") === 0
                    spacing: Style.space(6)
                    opacity: root.bootApplying ? 0.55 : 1

                    Rectangle {
                      width: Style.space(252)
                      height: Style.space(142)
                      radius: root.cornerRadius
                      color: Qt.rgba(0, 0, 0, 0.3)
                      border.width: bootCard.picked ? Math.max(2, Style.space(3)) : 1
                      border.color: bootCard.picked ? root.accent
                                  : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, bootCardArea.containsMouse ? 0.4 : 0.15)
                      clip: true
                      Behavior on border.color { ColorAnimation { duration: 100 } }

                      Text {
                        anchors.centerIn: parent
                        text: "rendering preview..."
                        color: root.muted
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                      }

                      Image {
                        anchors.fill: parent
                        anchors.margins: 1
                        source: root.bootCardPreview(bootCard.modelData.id)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                      }

                      Rectangle {
                        visible: bootCard.onDisk && !root.bootRotating
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: Style.space(8)
                        width: onDiskLabel.implicitWidth + Style.space(14)
                        height: Style.space(24)
                        radius: root.cornerRadius
                        color: root.accent

                        Text {
                          id: onDiskLabel
                          anchors.centerIn: parent
                          text: "\u2713 Applied"
                          color: Color.background
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption
                          font.weight: Font.DemiBold
                        }
                      }

                      MouseArea {
                        id: bootCardArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.bootRotating
                          ? (bootCard.modelData.id !== "stock" ? root.toggleInRotation(bootCard.modelData.id) : undefined)
                          : root.setBoot(bootCard.modelData.id)
                      }

                      // Rotation membership tick, shown while rotating.
                      Rectangle {
                        visible: root.bootRotating && bootCard.modelData.id !== "stock"
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.margins: Style.space(8)
                        width: Style.space(26)
                        height: Style.space(26)
                        radius: root.cornerRadius
                        color: root.inRotation(bootCard.modelData.id) ? root.accent : Qt.rgba(0, 0, 0, 0.55)
                        border.width: 1
                        border.color: root.inRotation(bootCard.modelData.id) ? root.accent : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.4)

                        Text {
                          anchors.centerIn: parent
                          text: root.inRotation(bootCard.modelData.id) ? "\u2713" : "+"
                          color: root.inRotation(bootCard.modelData.id) ? Color.background : root.foreground
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.bodySmall
                          font.weight: Font.Bold
                        }
                      }

                      Rectangle {
                        visible: bootCard.editable
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                        anchors.margins: Style.space(8)
                        width: bootEditLabel.implicitWidth + Style.space(14)
                        height: Style.space(24)
                        radius: root.cornerRadius
                        color: Qt.rgba(0, 0, 0, bootEditArea.containsMouse ? 0.8 : 0.55)
                        border.width: 1
                        border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.3)

                        Text {
                          id: bootEditLabel
                          anchors.centerIn: parent
                          text: "Edit"
                          color: root.foreground
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption
                        }

                        MouseArea {
                          id: bootEditArea
                          anchors.fill: parent
                          hoverEnabled: true
                          onClicked: root.openBootEditor(bootCard.modelData.id.substring(7))
                        }
                      }

                      // Your own videos and layouts can be deleted; press twice.
                      Rectangle {
                        visible: (bootCard.modelData.id.indexOf("video:") === 0 || bootCard.editable) && !root.bootRotating
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.margins: Style.space(8)
                        width: bootDelLabel.implicitWidth + Style.space(14)
                        height: Style.space(24)
                        radius: root.cornerRadius
                        color: root.confirmingDelete === bootCard.modelData.id ? "#a54242" : Qt.rgba(0, 0, 0, bootDelArea.containsMouse ? 0.8 : 0.55)
                        border.width: 1
                        border.color: root.confirmingDelete === bootCard.modelData.id ? "#c96a6a" : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.3)

                        Text {
                          id: bootDelLabel
                          anchors.centerIn: parent
                          text: root.confirmingDelete === bootCard.modelData.id ? "Sure?" : "Delete"
                          color: root.confirmingDelete === bootCard.modelData.id ? "#ffffff" : root.foreground
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption
                        }

                        MouseArea {
                          id: bootDelArea
                          anchors.fill: parent
                          hoverEnabled: true
                          onClicked: root.deleteBootCard(bootCard.modelData.id)
                        }
                      }
                    }

                    Row {
                      spacing: Style.space(8)

                      Text {
                        text: bootCard.modelData.name
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.bodySmall
                        font.weight: bootCard.picked ? Font.DemiBold : Font.Normal
                      }

                      Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: bootCard.modelData.kind
                        color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.9)
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                      }
                    }
                  }
                }

                // Snapshot the current lock screen as a static boot background.
                Column {
                  spacing: Style.space(6)

                  Rectangle {
                    width: Style.space(252)
                    height: Style.space(142)
                    radius: root.cornerRadius
                    color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, snapshotCardArea.containsMouse ? 0.16 : 0.08)
                    border.width: 1
                    border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.5)
                    Behavior on color { ColorAnimation { duration: 100 } }

                    Column {
                      anchors.centerIn: parent
                      spacing: Style.space(4)
                      width: parent.width - Style.space(24)

                      Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "+"
                        color: root.accent
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.heading
                      }
                      Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        text: "Snapshot this lock screen"
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                      }
                    }

                    MouseArea {
                      id: snapshotCardArea
                      anchors.fill: parent
                      hoverEnabled: true
                      onClicked: root.snapshotActiveDesign()
                    }
                  }

                  Text {
                    text: (Designs.byId(root.activeDesignId) ? Designs.byId(root.activeDesignId).name : "current") + " as a still"
                    color: root.muted
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }
                }

              }

              // Editor tab, gallery view: existing custom layouts to edit,
              // plus a card to start a new one.
              Flow {
                visible: root.mainTab === "editor" && root.bootEditing.length === 0
                width: card.width - root.sidebarW - root.rightPanelW - Style.space(120)
                spacing: Style.space(14)

                Repeater {
                  model: root.bootCustomDesigns
                  Column {
                    id: editorCard
                    required property var modelData
                    spacing: Style.space(6)

                    Rectangle {
                      width: Style.space(252)
                      height: Style.space(142)
                      radius: root.cornerRadius
                      color: Qt.rgba(0, 0, 0, 0.3)
                      border.width: 1
                      border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, editorCardArea.containsMouse ? 0.4 : 0.15)
                      clip: true
                      Behavior on border.color { ColorAnimation { duration: 100 } }

                      Image {
                        anchors.fill: parent
                        anchors.margins: 1
                        source: root.bootCardPreview("custom:" + editorCard.modelData)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                      }

                      MouseArea {
                        id: editorCardArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.openBootEditor(editorCard.modelData)
                      }
                    }

                    Text {
                      text: editorCard.modelData
                      color: root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.bodySmall
                    }
                  }
                }

                Column {
                  spacing: Style.space(6)

                  Rectangle {
                    width: Style.space(252)
                    height: Style.space(142)
                    radius: root.cornerRadius
                    color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, newBootArea.containsMouse ? 0.10 : 0.04)
                    border.width: 1
                    border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.25)
                    Behavior on color { ColorAnimation { duration: 100 } }

                    Column {
                      anchors.centerIn: parent
                      spacing: Style.space(4)

                      Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "+"
                        color: root.muted
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.display
                      }

                      Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "New layout"
                        color: root.muted
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                      }
                    }

                    MouseArea {
                      id: newBootArea
                      anchors.fill: parent
                      hoverEnabled: true
                      onClicked: root.newBootDesign()
                    }
                  }

                  Text {
                    text: "One layout, both screens"
                    color: root.muted
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }
                }
              }

              // Unified layout editor: fields on the left, the matching lock
              // and boot previews on the right. Changes save and re-render.
              Row {
                visible: root.mainTab === "editor" && root.bootEditing.length > 0
                spacing: Style.space(24)

                Column {
                  width: Style.space(360)
                  spacing: Style.space(12)

                  Text {
                    text: root.bootEditing
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    font.weight: Font.DemiBold
                  }

                  BootField {
                    label: "Background"
                    control: "dropdown"
                    rev: root.bootFormRev
                    onEscaped: { keyCatcher.forceActiveFocus(); root.handleEscape() }
                    value: root.bootFormGet("background", "theme")
                    options: ["theme", "wallpaper"]
                    onSelected: function(o) { root.bootFormSet("background", o) }
                  }
                  BootField {
                    label: "Logo"
                    control: "dropdown"
                    rev: root.bootFormRev
                    onEscaped: { keyCatcher.forceActiveFocus(); root.handleEscape() }
                    value: root.bootFormGet("logo", "theme")
                    options: ["theme", "none"]
                    onSelected: function(o) { root.bootFormSet("logo", o) }
                  }
                  BootField {
                    label: "Title"
                    control: "text"
                    rev: root.bootFormRev
                    onEscaped: { keyCatcher.forceActiveFocus(); root.handleEscape() }
                    value: root.bootFormGet("title", "")
                    onEdited: function(t) { root.bootFormSet("title", t) }
                  }
                  BootField {
                    label: "Subtitle"
                    control: "text"
                    rev: root.bootFormRev
                    onEscaped: { keyCatcher.forceActiveFocus(); root.handleEscape() }
                    value: root.bootFormGet("subtitle", "")
                    onEdited: function(t) { root.bootFormSet("subtitle", t) }
                  }
                  BootField {
                    label: "Clock (lock screen)"
                    control: "toggle"
                    rev: root.bootFormRev
                    onEscaped: { keyCatcher.forceActiveFocus(); root.handleEscape() }
                    on: root.bootFormGet("clock", "on") === "on"
                    onToggled: root.bootFormSet("clock", root.bootFormGet("clock", "on") === "on" ? "off" : "on")
                  }
                  BootField {
                    label: "Passphrase field"
                    control: "dropdown"
                    rev: root.bootFormRev
                    onEscaped: { keyCatcher.forceActiveFocus(); root.handleEscape() }
                    value: root.bootFormGet("entry", "pill")
                    options: ["pill", "line", "none"]
                    onSelected: function(o) { root.bootFormSet("entry", o) }
                  }
                  BootField {
                    label: "Scanlines"
                    control: "toggle"
                    rev: root.bootFormRev
                    onEscaped: { keyCatcher.forceActiveFocus(); root.handleEscape() }
                    on: root.bootFormGet("scanlines", "off") === "on"
                    onToggled: root.bootFormSet("scanlines", root.bootFormGet("scanlines", "off") === "on" ? "off" : "on")
                  }
                  BootField {
                    label: "Title position"
                    control: "stepper"
                    rev: root.bootFormRev
                    onEscaped: { keyCatcher.forceActiveFocus(); root.handleEscape() }
                    value: root.bootFormGet("title_y", "18")
                    onStep: function(d) { root.bootFormSet("title_y", Math.max(0, Math.min(100, (parseInt(root.bootFormGet("title_y", "18")) || 18) + d * 4))) }
                  }
                  BootField {
                    label: "Title size"
                    control: "stepper"
                    suffix: ""
                    rev: root.bootFormRev
                    onEscaped: root.handleEscape()
                    value: root.bootFormGet("title_size", "26")
                    onStep: function(d) { root.bootFormSet("title_size", Math.max(10, Math.min(64, (parseInt(root.bootFormGet("title_size", "26")) || 26) + d * 2))) }
                  }
                  BootField {
                    label: "Subtitle position"
                    control: "stepper"
                    rev: root.bootFormRev
                    onEscaped: { keyCatcher.forceActiveFocus(); root.handleEscape() }
                    value: root.bootFormGet("subtitle_y", "26")
                    onStep: function(d) { root.bootFormSet("subtitle_y", Math.max(0, Math.min(100, (parseInt(root.bootFormGet("subtitle_y", "26")) || 26) + d * 4))) }
                  }
                  BootField {
                    label: "Subtitle size"
                    control: "stepper"
                    suffix: ""
                    rev: root.bootFormRev
                    onEscaped: { keyCatcher.forceActiveFocus(); root.handleEscape() }
                    value: root.bootFormGet("subtitle_size", "15")
                    onStep: function(d) { root.bootFormSet("subtitle_size", Math.max(8, Math.min(40, (parseInt(root.bootFormGet("subtitle_size", "15")) || 15) + d * 1))) }
                  }
                  BootField {
                    label: "Field position"
                    control: "stepper"
                    rev: root.bootFormRev
                    onEscaped: { keyCatcher.forceActiveFocus(); root.handleEscape() }
                    value: root.bootFormGet("entry_y", "72")
                    onStep: function(d) { root.bootFormSet("entry_y", Math.max(0, Math.min(100, (parseInt(root.bootFormGet("entry_y", "72")) || 72) + d * 4))) }
                  }
                }

                Column {
                  spacing: Style.space(14)

                  // Both previews on one row so neither hides below the fold.
                  Row {
                    spacing: Style.space(14)

                    Column {
                      spacing: Style.space(6)
                      Text {
                        text: "Lock screen"
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.bodySmall
                        font.weight: Font.DemiBold
                      }
                      Rectangle {
                        id: edLockRect
                        width: Math.floor((settingsColumn.width - Style.space(360) - Style.space(24) - Style.space(14)) / 2)
                        height: Math.round(width * 9 / 16)
                        radius: root.cornerRadius
                        color: Qt.rgba(0, 0, 0, 0.3)
                        border.width: 1
                        border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.2)
                        clip: true
                        Text {
                          anchors.centerIn: parent
                          visible: editorLockPreview.status !== Image.Ready
                          text: "rendering preview..."
                          color: root.muted
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption
                        }
                        Rectangle {
                          visible: root.bootEditBusy
                          z: 2
                          anchors.right: parent.right
                          anchors.bottom: parent.bottom
                          anchors.margins: Style.space(8)
                          width: busyLabel1.implicitWidth + Style.space(14)
                          height: Style.space(22)
                          radius: root.cornerRadius
                          color: Qt.rgba(0, 0, 0, 0.6)
                          Text {
                            id: busyLabel1
                            anchors.centerIn: parent
                            text: "re-rendering…"
                            color: root.foreground
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.caption
                            SequentialAnimation on opacity {
                              running: root.bootEditBusy
                              loops: Animation.Infinite
                              NumberAnimation { from: 1; to: 0.35; duration: 600 }
                              NumberAnimation { from: 0.35; to: 1; duration: 600 }
                            }
                          }
                        }
                        Image {
                          id: editorLockPreview
                          anchors.fill: parent; anchors.margins: 1
                          source: "file://" + Quickshell.env("HOME") + "/.local/state/omarchy/lock-explorer-boot-previews/custom-" + root.bootEditing + "-lock-" + root.bootCurrentTheme + ".png?v=" + root.bootPreviewsVersion
                          fillMode: Image.PreserveAspectCrop
                          asynchronous: true
                          cache: false
                        }
                      }
                    }

                    Column {
                      spacing: Style.space(6)
                      Text {
                        text: "Boot screen"
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.bodySmall
                        font.weight: Font.DemiBold
                      }
                      Rectangle {
                        width: edLockRect.width
                        height: edLockRect.height
                        radius: root.cornerRadius
                        color: Qt.rgba(0, 0, 0, 0.3)
                        border.width: 1
                        border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.2)
                        clip: true
                        Text {
                          anchors.centerIn: parent
                          visible: editorBootPreview.status !== Image.Ready
                          text: "rendering preview..."
                          color: root.muted
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption
                        }
                        Rectangle {
                          visible: root.bootEditBusy
                          z: 2
                          anchors.right: parent.right
                          anchors.bottom: parent.bottom
                          anchors.margins: Style.space(8)
                          width: busyLabel2.implicitWidth + Style.space(14)
                          height: Style.space(22)
                          radius: root.cornerRadius
                          color: Qt.rgba(0, 0, 0, 0.6)
                          Text {
                            id: busyLabel2
                            anchors.centerIn: parent
                            text: "re-rendering…"
                            color: root.foreground
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.caption
                            SequentialAnimation on opacity {
                              running: root.bootEditBusy
                              loops: Animation.Infinite
                              NumberAnimation { from: 1; to: 0.35; duration: 600 }
                              NumberAnimation { from: 0.35; to: 1; duration: 600 }
                            }
                          }
                        }
                        Image {
                          id: editorBootPreview
                          anchors.fill: parent; anchors.margins: 1
                          source: root.bootCardPreview("custom:" + root.bootEditing)
                          fillMode: Image.PreserveAspectCrop
                          asynchronous: true
                          cache: false
                        }
                      }
                    }
                  }

                  Text {
                    width: edLockRect.width * 2 + Style.space(14)
                    wrapMode: Text.WordWrap
                    text: "Changes save and re-render automatically \u00b7 Esc goes back \u00b7 apply the boot screen from its card, pick the lock screen on the Lock screens tab. $USER and $HOST expand."
                    color: root.muted
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }
                }
              }
            }
          }
          }
        }
      }

      // Left nav sidebar (redesign): sections as a vertical list with a
      // border-left accent, counts on the right.
      Column {
        id: sidebar
        anchors.top: header.bottom
        anchors.bottom: footer.top
        anchors.left: parent.left
        anchors.leftMargin: card.contentLeftInset
        anchors.topMargin: Style.space(4)
        anchors.bottomMargin: Style.space(8)
        width: root.sidebarW
        spacing: Style.space(2)

        Repeater {
          model: {
            var r = root.service ? root.service.designsRevision : 0
            return [
              { id: "styling", name: "Styling", count: Designs.stylings().length },
              { id: "animation", name: "Animation", count: Designs.animations().length },
              { id: "boot", name: "Boot screen", count: 0 },
              { id: "settings", name: "Settings", count: 0 }
            ]
          }
          Rectangle {
            id: navItem
            required property var modelData
            readonly property bool current: modelData.id === root.mainTab
            width: root.sidebarW
            height: Style.space(36)
            color: navItem.current ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)
                   : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, navItemArea.containsMouse ? 0.05 : 0.0)
            Behavior on color { ColorAnimation { duration: 100 } }

            Rectangle {
              anchors.left: parent.left
              anchors.top: parent.top
              anchors.bottom: parent.bottom
              width: Math.max(2, Style.space(2))
              color: navItem.current ? root.accent : "transparent"
            }

            Text {
              anchors.left: parent.left
              anchors.leftMargin: Style.space(12)
              anchors.verticalCenter: parent.verticalCenter
              text: (navItem.modelData.name + (navItem.modelData.id === "boot" && root.bootApplying ? " ·" : "")).toUpperCase()
              color: navItem.current ? Color.menu.text : root.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              font.weight: navItem.current ? Font.Bold : Font.Normal
              font.letterSpacing: 1
            }

            Text {
              anchors.right: parent.right
              anchors.rightMargin: Style.space(12)
              anchors.verticalCenter: parent.verticalCenter
              visible: navItem.modelData.count > 0
              text: navItem.modelData.count
              color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.45)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }

            // The boot screen ships as experimental; say so where it is picked.
            Text {
              anchors.right: parent.right
              anchors.rightMargin: Style.space(12)
              anchors.verticalCenter: parent.verticalCenter
              visible: navItem.modelData.id === "boot" && !root.bootApplying
              text: "EXP"
              color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.75)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.letterSpacing: 1
            }

            // Pending dot when the boot screen has an unapplied change.
            Rectangle {
              anchors.right: parent.right
              anchors.rightMargin: Style.space(12)
              anchors.verticalCenter: parent.verticalCenter
              visible: navItem.modelData.id === "boot" && root.bootApplying
              width: Style.space(7); height: Style.space(7); radius: width / 2
              color: root.accent
            }

            MouseArea {
              id: navItemArea
              anchors.fill: parent
              hoverEnabled: true
              onClicked: root.mainTab = navItem.modelData.id
            }
          }
        }
      }

      // "+ New clip" above it: your own video as an unlock clip design.
      Rectangle {
        id: newClipBtn
        anchors.left: parent.left
        anchors.leftMargin: card.contentLeftInset
        anchors.bottom: newStylingBtn.top
        anchors.bottomMargin: Style.space(8)
        width: root.sidebarW
        height: Style.space(34)
        color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, newClipArea.containsMouse ? 0.08 : 0.0)
        border.width: 1
        border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.3)
        Behavior on color { ColorAnimation { duration: 100 } }

        Text {
          anchors.centerIn: parent
          text: "+ New clip"
          color: newClipArea.containsMouse ? Color.menu.text : root.muted
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
        }

        MouseArea {
          id: newClipArea
          anchors.fill: parent
          hoverEnabled: true
          onClicked: root.newClipDesign()
        }
      }

      // "+ New styling" pinned to the bottom of the sidebar.
      Rectangle {
        id: newStylingBtn
        anchors.left: parent.left
        anchors.leftMargin: card.contentLeftInset
        anchors.bottom: footer.top
        anchors.bottomMargin: Style.space(14)
        width: root.sidebarW
        height: Style.space(34)
        color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, newStylingArea.containsMouse ? 0.08 : 0.0)
        border.width: 1
        border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.3)
        Behavior on color { ColorAnimation { duration: 100 } }

        Text {
          anchors.centerIn: parent
          text: "+ New styling"
          color: newStylingArea.containsMouse ? Color.menu.text : root.muted
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
        }

        MouseArea {
          id: newStylingArea
          anchors.fill: parent
          hoverEnabled: true
          onClicked: root.newBootDesign()
        }
      }

      // Right live-preview panel (redesign): the current lock screen rendered
      // live, plus the boot-screen preview.
      Column {
        id: previewPanel
        // The editor brings its own pair of previews; give it the width.
        visible: root.mainTab !== "editor"
        anchors.top: header.bottom
        anchors.bottom: footer.top
        anchors.right: parent.right
        anchors.rightMargin: card.contentRightInset + Style.space(8)
        anchors.topMargin: Style.space(6)
        anchors.bottomMargin: Style.space(10)
        width: root.rightPanelW - Style.space(8)
        spacing: Style.space(12)

        Row {
          width: parent.width
          Text {
            text: "LOCK SCREEN"
            color: root.muted
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.letterSpacing: 2
          }
          Item { width: parent.width - lockLbl.width - liveLbl.width; height: 1 }
          Text {
            id: lockLbl; visible: false; text: "LOCK SCREEN"
            font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.letterSpacing: 2
          }
          Text {
            id: liveLbl
            text: "● live"
            color: root.accent
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }

        // Live render of the selected design, scaled from full screen.
        Rectangle {
          width: parent.width
          height: Math.round(parent.width * 9 / 16)
          radius: root.cornerRadius
          color: Color.background
          border.width: 1
          border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.2)
          clip: true

          Item {
            width: panel.width
            height: panel.height
            scale: (parent.width - 2) / panel.width
            transformOrigin: Item.TopLeft
            enabled: false   // never let the preview's input steal keyboard focus
            LockHost {
              anchors.fill: parent
              designId: root.selectedDesign ? root.selectedDesign.id : root.activeDesignId
              revision: root.service ? root.service.designsRevision : 0
              backgroundPath: root.service ? root.service.backgroundPath : ""
              backgroundVersion: root.service ? root.service.backgroundVersion : 0
              avatarPath: root.service ? root.service.avatarPath : ""
              avatarVersion: root.service ? root.service.avatarVersion : 0
              inputEnabled: false
              loadBackground: root.opened
              passwordText: "omarchy"
              videoPath: root.service ? root.service.videoPath : ""
              videoPlaying: root.opened
            }
          }
        }

        Rectangle {
          width: parent.width
          height: Style.space(30)
          radius: root.cornerRadius
          color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, fullBtnArea.containsMouse ? 0.12 : 0.05)
          border.width: 1
          border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.2)
          Text {
            anchors.centerIn: parent
            text: "Preview full screen · Space"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
          MouseArea {
            id: fullBtnArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: root.fullPreview = true
          }
        }

        Item { width: 1; height: Style.space(4) }

        Row {
          width: parent.width
          Text {
            text: "BOOT SCREEN"
            color: root.muted
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.letterSpacing: 2
          }
        }

        Row {
          width: parent.width
          spacing: Style.space(12)

          Rectangle {
            width: Style.space(150)
            height: Math.round(Style.space(150) * 9 / 16)
            radius: root.cornerRadius
            color: Color.background
            border.width: 1
            border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.2)
            clip: true
            Image {
              id: appliedBootThumb
              anchors.fill: parent; anchors.margins: 1
              // Every apply writes its own preview image, so this always shows
              // exactly what is on the boot image — snapshots included, which
              // the per-card cache never carries.
              source: root.bootApplied.length > 0
                ? "file://" + Quickshell.env("HOME") + "/.local/state/omarchy/lock-explorer-boot-preview.png?v="
                  + (root.service ? root.service.bootAppliedVersion : 0)
                : root.bootCardPreview("stock")
              fillMode: Image.PreserveAspectCrop
              asynchronous: true
              cache: false
            }
            Text {
              anchors.centerIn: parent
              visible: root.bootApplied.length === 0 && appliedBootThumb.status !== Image.Ready
              text: "stock"
              color: root.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }

          Column {
            width: parent.width - Style.space(162)
            spacing: Style.space(3)
            Text {
              width: parent.width
              elide: Text.ElideRight
              text: root.bootNowName
              color: Color.menu.text
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
            Text {
              width: parent.width
              wrapMode: Text.WordWrap
              text: root.bootApplying ? "Rebuilding…" : (root.bootAppliedTheme.length > 0 ? "baked from " + root.bootAppliedTheme : "the disk passphrase screen")
              color: root.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
            Text {
              text: "Boot screen settings ›"
              color: root.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              MouseArea { anchors.fill: parent; anchors.margins: -Style.space(4); onClicked: root.mainTab = "boot" }
            }
          }
        }
      }

      GridView {
        id: grid
        visible: root.mainTab === "styling" || root.mainTab === "animation"
        anchors.top: header.bottom
        anchors.bottom: footer.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: card.contentLeftInset + root.sidebarW + Style.space(20)
        anchors.rightMargin: card.contentRightInset + root.rightPanelW + Style.space(20)
        anchors.bottomMargin: Style.space(8)
        clip: true
        model: root.designs
        cellWidth: root.cellWidth
        cellHeight: root.thumbHeight + root.captionHeight + root.gap
        topMargin: Style.space(4)
        cacheBuffer: cellHeight * 2
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 4000
        maximumFlickVelocity: 3000

        delegate: Item {
          id: cell
          required property var modelData
          required property int index
          readonly property bool selected: index === root.selectedIndex
          readonly property bool active: modelData.id === root.activeDesignId
          // A preview is a whole lock screen, so only the ones on screen are
          // worth drawing. The rest stay built but out of the scene graph.
          readonly property bool inView: (y + height > grid.contentY - grid.cellHeight / 2)
            && (y < grid.contentY + grid.height + grid.cellHeight / 2)
          width: grid.cellWidth
          height: grid.cellHeight

          Rectangle {
            id: frame
            width: root.thumbWidth
            height: root.thumbHeight
            radius: root.cornerRadius
            color: Color.background
            border.width: cell.selected ? 3 : 1
            border.color: cell.selected ? root.accent : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.18)
            clip: true
            Behavior on border.color { ColorAnimation { duration: 120 } }

            Item {
              anchors.fill: parent
              anchors.margins: frame.border.width
              clip: true
              Item {
                width: panel.width
                height: panel.height
                scale: (frame.width - frame.border.width * 2) / panel.width
                transformOrigin: Item.TopLeft
                visible: cell.inView
                Loader {
                  anchors.fill: parent
                  asynchronous: true
                  sourceComponent: LockHost {
                    designId: cell.modelData.id
                    revision: root.service ? root.service.designsRevision : 0
                    backgroundPath: root.service ? root.service.backgroundPath : ""
                    backgroundVersion: root.service ? root.service.backgroundVersion : 0
                    avatarPath: root.service ? root.service.avatarPath : ""
                    avatarVersion: root.service ? root.service.avatarVersion : 0
                    fingerprintConfigured: root.service ? root.service.fingerprintConfigured : false
                    inputEnabled: false
                    loadBackground: root.opened
                    passwordText: "omarchy"
                    videoPath: root.service ? root.service.videoPath : ""
                    // Only the cell on screen decodes, the rest hold still.
                    videoPlaying: cell.inView
                  }
                }
              }
            }

            Rectangle {
              anchors.left: parent.left; anchors.top: parent.top; anchors.margins: Style.space(10)
              width: Style.space(24); height: Style.space(24); radius: 5
              color: Qt.rgba(0, 0, 0, 0.55)
              Text {
                anchors.centerIn: parent
                text: (cell.index + 1)
                color: "#ffffff"
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }
            }

            Rectangle {
              visible: cell.active
              anchors.right: parent.right; anchors.top: parent.top; anchors.margins: Style.space(10)
              width: activeText.implicitWidth + Style.space(14); height: Style.space(24); radius: root.cornerRadius
              color: root.accent
              Text {
                id: activeText
                anchors.centerIn: parent
                text: "󰄬 Active"
                color: Color.background
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }
            }

            MouseArea {
              anchors.fill: parent
              onClicked: root.selectedIndex = cell.index
              onDoubleClicked: { root.selectedIndex = cell.index; root.apply() }
            }

            Row {
              visible: cell.selected
              anchors.right: parent.right
              anchors.bottom: parent.bottom
              anchors.margins: Style.space(10)
              spacing: Style.space(6)
              Rectangle {
                width: useLabel.implicitWidth + Style.space(16); height: Style.space(26); radius: 6
                color: root.accent
                Text {
                  id: useLabel
                  anchors.centerIn: parent
                  text: "Use  ⏎"
                  color: Color.background
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }
                MouseArea { anchors.fill: parent; onClicked: { root.selectedIndex = cell.index; root.apply() } }
              }
              Rectangle {
                width: custLabel.implicitWidth + Style.space(16); height: Style.space(26); radius: 6
                color: Qt.rgba(0, 0, 0, 0.6)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.25)
                Text {
                  id: custLabel
                  anchors.centerIn: parent
                  text: cell.modelData.path ? "Edit  E" : "Customize  C"
                  color: "#ffffff"
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }
                MouseArea { anchors.fill: parent; onClicked: { root.selectedIndex = cell.index; root.customizeSelected() } }
              }
              // Only your own designs can be deleted; two clicks to confirm.
              Rectangle {
                visible: cell.modelData.path ? true : false
                width: delLabel.implicitWidth + Style.space(16); height: Style.space(26); radius: 6
                color: root.confirmingDelete === cell.modelData.id ? "#a54242" : Qt.rgba(0, 0, 0, 0.6)
                border.width: 1
                border.color: root.confirmingDelete === cell.modelData.id ? "#c96a6a" : Qt.rgba(1, 1, 1, 0.25)
                Text {
                  id: delLabel
                  anchors.centerIn: parent
                  text: root.confirmingDelete === cell.modelData.id ? "Sure?  X" : "Delete  X"
                  color: "#ffffff"
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }
                MouseArea { anchors.fill: parent; onClicked: { root.selectedIndex = cell.index; root.deleteSelected() } }
              }
            }
          }

          Column {
            anchors.top: frame.bottom
            anchors.topMargin: Style.space(8)
            width: root.thumbWidth
            spacing: 2
            Row {
              spacing: Style.space(8)
              Text {
                text: cell.modelData.name
                color: cell.selected ? root.foreground : root.muted
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
                font.weight: cell.selected ? Font.DemiBold : Font.Normal
              }
              Row {
                spacing: Style.space(4)
                anchors.verticalCenter: parent.verticalCenter
                Repeater {
                  model: cell.modelData.tags || []
                  Rectangle {
                    required property string modelData
                    width: tagLabel.implicitWidth + Style.space(10)
                    height: Style.space(18)
                    radius: 4
                    color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)
                    Text {
                      id: tagLabel
                      anchors.centerIn: parent
                      text: {
                        var cats = Designs.categories()
                        for (var i = 0; i < cats.length; i++) if (cats[i].id === parent.modelData) return cats[i].name
                        return parent.modelData
                      }
                      color: root.muted
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                    }
                  }
                }
              }
            }
            Text {
              width: parent.width
              text: cell.modelData.description + (cell.modelData.credit ? "  ·  clip by " + cell.modelData.credit : "")
              color: root.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
              maximumLineCount: 1
            }
          }
        }
      }

      // Above the grid: every design has a MouseArea of its own and so does the
      // cell, and those eat wheel events before the grid ever sees them. No
      // buttons, so clicks and drags still reach the cells underneath.
      MouseArea {
        anchors.fill: grid
        acceptedButtons: Qt.NoButton
        onWheel: function(wheel) {
          // Touchpads send pixel deltas with a coarse angle alongside them.
          // Reading the angle for both turned every small two finger move into
          // a whole notch, so use the pixels when they are there.
          var dy = wheel.pixelDelta.y !== 0 ? wheel.pixelDelta.y : wheel.angleDelta.y * 1.2
          var next = grid.contentY - dy
          grid.contentY = Math.max(0, Math.min(Math.max(0, grid.contentHeight - grid.height), next))
        }
      }

      Rectangle {
        anchors.top: grid.top
        anchors.bottom: grid.bottom
        anchors.right: parent.right
        anchors.rightMargin: card.contentRightInset - Style.space(4)
        width: 4
        radius: 2
        visible: grid.visible && grid.contentHeight > grid.height
        color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)
        Rectangle {
          width: parent.width
          radius: 2
          color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.35)
          height: Math.max(24, parent.height * grid.height / Math.max(1, grid.contentHeight))
          y: (parent.height - height) * (grid.contentY / Math.max(1, grid.contentHeight - grid.height))
        }
      }

      Item {
        id: footer
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset
        anchors.rightMargin: card.contentRightInset
        height: root.footerHeight
        Text {
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          text: {
            if (root.mainTab === "editor") return "Changes save automatically   ·   Esc: back"
            if (root.mainTab === "boot") return "Click a card to pick it   ·   Apply writes it to the boot image   ·   B / Esc: back"
            if (root.mainTab === "settings") return "U / Esc: back"
            return "Arrows: browse   Tab: category   Space: preview   Enter: select   C: customize   E: edit   N: new   X: delete   A: avatar   V: video   S: unlock clip   U: unlock effect   B: boot screen   Esc: close"
          }
          color: root.muted
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
        }
      }
    }

    BorderSurface {
      id: editorCard
      visible: root.editing
      width: root.cardWidth
      height: root.cardHeight
      radius: root.cornerRadius
      anchors.centerIn: parent
      color: root.background
      borderSpec: root.borderSpec

      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        anchors.fill: parent
        anchors.topMargin: editorCard.contentTopInset + root.contentMargin
        anchors.bottomMargin: editorCard.contentBottomInset + root.contentMargin
        anchors.leftMargin: editorCard.contentLeftInset + root.contentMargin
        anchors.rightMargin: editorCard.contentRightInset + root.contentMargin

        Item {
          id: editorHeader
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          height: Style.space(48)
          Column {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Text {
              text: root.editingDesign ? root.editingDesign.name : ""
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
              font.weight: Font.DemiBold
            }
            Text {
              text: "Custom design"
              color: root.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
          }
          Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(8)
            Rectangle {
              width: saveLabel.implicitWidth + Style.space(20); height: Style.space(30); radius: 6
              color: editorView.dirty ? root.accent : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)
              Text {
                id: saveLabel
                anchors.centerIn: parent
                text: "Save  Ctrl+S"
                color: editorView.dirty ? Color.background : root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                font.bold: editorView.dirty
              }
              MouseArea { anchors.fill: parent; onClicked: editorView.save() }
            }
            Rectangle {
              width: useLabel2.implicitWidth + Style.space(20); height: Style.space(30); radius: 6
              color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)
              Text {
                id: useLabel2
                anchors.centerIn: parent
                text: "Use this design"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
              }
              MouseArea {
                anchors.fill: parent
                onClicked: {
                  if (root.service && root.editingDesign) root.service.setDesign(root.editingDesign.id)
                }
              }
            }
            Rectangle {
              width: backLabel.implicitWidth + Style.space(20); height: Style.space(30); radius: 6
              color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)
              Text {
                id: backLabel
                anchors.centerIn: parent
                text: "Back  Esc"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
              }
              MouseArea { anchors.fill: parent; onClicked: editorView.requestClose() }
            }
          }
        }

        Editor {
          id: editorView
          anchors.top: editorHeader.bottom
          anchors.topMargin: Style.space(12)
          anchors.bottom: parent.bottom
          anchors.left: parent.left
          anchors.right: parent.right
          service: root.service
          design: root.editing ? root.editingDesign : null
          background: root.background
          foreground: root.foreground
          accent: root.accent
          fontFamily: root.fontFamily
          screenWidth: panel.width
          screenHeight: panel.height
          onCloseRequested: root.closeEditor()
          onOpenExternalRequested: function(path) { root.openExternal(path) }
        }
      }
    }

    Item {
      anchors.fill: parent
      visible: root.fullPreview

      LockHost {
        anchors.fill: parent
        designId: root.selectedDesign ? root.selectedDesign.id : Designs.DEFAULT_ID
        revision: root.service ? root.service.designsRevision : 0
        backgroundPath: root.service ? root.service.backgroundPath : ""
        backgroundVersion: root.service ? root.service.backgroundVersion : 0
        fingerprintConfigured: root.service ? root.service.fingerprintConfigured : false
        inputEnabled: false
        loadBackground: root.opened && root.fullPreview
        passwordText: ""
        videoPath: root.service ? root.service.videoPath : ""
        videoPlaying: root.fullPreview
      }

      MouseArea { anchors.fill: parent; onClicked: root.fullPreview = false }

      Rectangle {
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: Style.space(20)
        width: hud.implicitWidth + Style.space(32)
        height: hud.implicitHeight + Style.space(20)
        radius: root.cornerRadius
        color: Qt.rgba(root.background.r, root.background.g, root.background.b, 0.85)
        border.width: 1
        border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.2)
        Row {
          id: hud
          anchors.centerIn: parent
          spacing: Style.space(18)
          Text {
            text: (root.selectedIndex + 1) + "/" + root.designs.length + "   " + (root.selectedDesign ? root.selectedDesign.name : "")
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
            font.weight: Font.DemiBold
          }
          Text {
            text: "Arrows: next   Enter: select   Esc: back"
            color: root.muted
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            anchors.verticalCenter: parent.verticalCenter
          }
        }
      }
    }
  }
}
