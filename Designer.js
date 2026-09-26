.pragma library

// Model, palette and code generator for the visual designer.
//
// A designer layout is a plain object:
//   { v: 1, name: "My Layout", nodes: [ node, ... ] }
// and a node is:
//   { id: "n3", kind: "clock", anchor: "center", dx: 0, dy: -160,
//     w: 0, h: 0, spec: { ... } }
//
// dx/dy are signed pixel offsets from the anchor point, positive right/down,
// in the screen's own coordinates. w/h of 0 mean "size yourself from your
// content". The layout is written into the design file as a single comment
// line (MARKER below) and the QML underneath is generated from it, so the
// designer never has to parse QML back.

var MARKER = "designer:1:"
var VERSION = 1
var DEFAULT_NAME = "My Layout"

// ------------------------------------------------------------------ anchors

var ANCHORS = [
  "topLeft", "top", "topRight",
  "left", "center", "right",
  "bottomLeft", "bottom", "bottomRight"
]

function anchorCol(anchor) {
  if (anchor === "topLeft" || anchor === "left" || anchor === "bottomLeft") return 0
  if (anchor === "topRight" || anchor === "right" || anchor === "bottomRight") return 2
  return 1
}

function anchorRow(anchor) {
  if (anchor === "topLeft" || anchor === "top" || anchor === "topRight") return 0
  if (anchor === "bottomLeft" || anchor === "bottom" || anchor === "bottomRight") return 2
  return 1
}

function anchorFor(col, row) { return ANCHORS[row * 3 + col] }

// The anchor a node dropped at this spot should keep, so it stays where it
// was put on screens of another size: near an edge it sticks to that edge,
// in the middle third it rides the center.
function anchorAt(cx, cy, screenW, screenH) {
  var col = cx < screenW / 3 ? 0 : (cx > screenW * 2 / 3 ? 2 : 1)
  var row = cy < screenH / 3 ? 0 : (cy > screenH * 2 / 3 ? 2 : 1)
  return anchorFor(col, row)
}

// x of the node's left edge, given its offset and size.
function xFor(node, w, screenW) {
  var col = anchorCol(node.anchor)
  if (col === 0) return node.dx
  if (col === 2) return screenW + node.dx - w
  return (screenW - w) / 2 + node.dx
}

function yFor(node, h, screenH) {
  var row = anchorRow(node.anchor)
  if (row === 0) return node.dy
  if (row === 2) return screenH + node.dy - h
  return (screenH - h) / 2 + node.dy
}

// The inverse: the offset that puts the node's left/top edge at x/y.
function dxFor(anchor, x, w, screenW) {
  var col = anchorCol(anchor)
  if (col === 0) return x
  if (col === 2) return x + w - screenW
  return x - (screenW - w) / 2
}

function dyFor(anchor, y, h, screenH) {
  var row = anchorRow(anchor)
  if (row === 0) return y
  if (row === 2) return y + h - screenH
  return y - (screenH - h) / 2
}

// Re-anchor without moving: keep the pixels, change the rule.
function reanchor(node, anchor, w, h, screenW, screenH) {
  var x = xFor(node, w, screenW)
  var y = yFor(node, h, screenH)
  node.anchor = anchor
  node.dx = Math.round(dxFor(anchor, x, w, screenW))
  node.dy = Math.round(dyFor(anchor, y, h, screenH))
  return node
}

// ------------------------------------------------------------------- colors

// Color choices are theme roles, so a design keeps working when the theme
// changes. A literal #rrggbb is allowed too.
var COLOR_ROLES = [
  { id: "text", name: "Text" },
  { id: "accent", name: "Accent" },
  { id: "error", name: "Error" },
  { id: "placeholder", name: "Muted" },
  { id: "surface", name: "Surface" },
  { id: "background", name: "Background" },
  { id: "black", name: "Black" },
  { id: "white", name: "White" }
]

// -------------------------------------------------------------------- kinds

var WEIGHTS = [
  { id: 300, name: "Light" },
  { id: 400, name: "Regular" },
  { id: 500, name: "Medium" },
  { id: 600, name: "DemiBold" },
  { id: 700, name: "Bold" }
]

var ALIGNMENTS = [
  { id: "left", name: "Left" },
  { id: "center", name: "Center" },
  { id: "right", name: "Right" }
]

function textFields(extra) {
  var base = [
    { key: "size", type: "number", label: "Font size", min: 6, max: 400, step: 2 },
    { key: "weight", type: "choice", label: "Weight", options: WEIGHTS },
    { key: "color", type: "color", label: "Color" },
    { key: "alpha", type: "slider", label: "Opacity", min: 0.05, max: 1, step: 0.05 },
    { key: "spacing", type: "number", label: "Letter spacing", min: -10, max: 40, step: 1 },
    { key: "align", type: "choice", label: "Align", options: ALIGNMENTS },
    { key: "caps", type: "bool", label: "Uppercase" },
    { key: "shadow", type: "bool", label: "Drop shadow" }
  ]
  return (extra || []).concat(base)
}

// Every draggable piece. `group` buckets them in the palette, `sized` says
// whether dragging a corner handle should resize it, `fill` marks the
// full-screen backgrounds.
// ttfx effects that suit a drawing: they finish on their own and read well
// on block art. The names are ttfx's own, see `ttfx --help`.
var TTFX_EFFECTS = [
  { id: "decrypt", name: "Decrypt" },
  { id: "beams", name: "Beams" },
  { id: "burn", name: "Burn" },
  { id: "laseretch", name: "Laser etch" },
  { id: "expand", name: "Expand" },
  { id: "slide", name: "Slide" },
  { id: "wipe", name: "Wipe" },
  { id: "scattered", name: "Scattered" },
  { id: "spray", name: "Spray" },
  { id: "pour", name: "Pour" },
  { id: "rain", name: "Rain" },
  { id: "print", name: "Print" },
  { id: "bouncyballs", name: "Bouncy balls" },
  { id: "bubbles", name: "Bubbles" },
  { id: "blackhole", name: "Black hole" },
  { id: "synthgrid", name: "Synth grid" },
  { id: "swarm", name: "Swarm" },
  { id: "unstable", name: "Unstable" },
  { id: "errorcorrect", name: "Error correct" },
  { id: "crumble", name: "Crumble" },
  { id: "vhstape", name: "VHS tape" },
  { id: "colorshift", name: "Color shift" }
]

var KINDS = {
  wallpaper: {
    name: "Wallpaper", group: "Background", glyph: "󰸉",
    hint: "The desktop wallpaper, blurred and dimmed",
    fill: true,
    spec: { blur: 0.85, dim: 0.08, vignette: true },
    fields: [
      { key: "blur", type: "slider", label: "Blur", min: 0, max: 1, step: 0.05 },
      { key: "dim", type: "slider", label: "Dim", min: 0, max: 0.9, step: 0.05 },
      { key: "vignette", type: "bool", label: "Vignette" }
    ]
  },
  video: {
    name: "Video", group: "Background", glyph: "󰕧",
    hint: "The looping video set with lock setVideo",
    fill: true,
    spec: { dim: 0.25, vignette: true },
    fields: [
      { key: "dim", type: "slider", label: "Dim", min: 0, max: 0.9, step: 0.05 },
      { key: "vignette", type: "bool", label: "Vignette" }
    ]
  },
  color: {
    name: "Solid color", group: "Background", glyph: "󰝤",
    hint: "A flat background, no wallpaper",
    fill: true,
    spec: { color: "background", alpha: 1 },
    fields: [
      { key: "color", type: "color", label: "Color" },
      { key: "alpha", type: "slider", label: "Opacity", min: 0.05, max: 1, step: 0.05 }
    ]
  },

  clock: {
    name: "Clock", group: "Text", glyph: "󰅐",
    hint: "The time, ticking",
    spec: { format: "HH:mm", size: 120, weight: 600, color: "text", alpha: 1, spacing: -2, align: "center", caps: false, shadow: true },
    fields: textFields([
      { key: "format", type: "choice", label: "Format", options: [
        { id: "HH:mm", name: "13:05" },
        { id: "H:mm", name: "13:05 (no pad)" },
        { id: "hh:mm AP", name: "01:05 PM" },
        { id: "h:mm ap", name: "1:05 pm" },
        { id: "HH:mm:ss", name: "13:05:42" },
        { id: "HH", name: "13 (hour only)" },
        { id: "mm", name: "05 (minute only)" }
      ] }
    ])
  },
  date: {
    name: "Date", group: "Text", glyph: "󰃭",
    hint: "Today's date",
    spec: { format: "dddd, d MMMM", size: 26, weight: 400, color: "text", alpha: 0.85, spacing: 1, align: "center", caps: false, shadow: true },
    fields: textFields([
      { key: "format", type: "choice", label: "Format", options: [
        { id: "dddd, d MMMM", name: "Monday, 5 May" },
        { id: "dddd", name: "Monday" },
        { id: "ddd d MMM", name: "Mon 5 May" },
        { id: "d MMMM yyyy", name: "5 May 2026" },
        { id: "yyyy-MM-dd", name: "2026-05-05" },
        { id: "MMMM", name: "May" }
      ] }
    ])
  },
  greeting: {
    name: "Greeting", group: "Text", glyph: "󰀄",
    hint: "Good morning / afternoon / evening",
    spec: { withName: true, size: 28, weight: 600, color: "text", alpha: 1, spacing: 0, align: "center", caps: false, shadow: false },
    fields: textFields([
      { key: "withName", type: "bool", label: "Add your name" }
    ])
  },
  label: {
    name: "Text", group: "Text", glyph: "󰊄",
    hint: "Any words you like",
    spec: { text: "Locked", size: 22, weight: 400, color: "text", alpha: 0.7, spacing: 1, align: "center", caps: false, shadow: false },
    fields: textFields([
      { key: "text", type: "text", label: "Text" }
    ])
  },
  username: {
    name: "User name", group: "Text", glyph: "󰋦",
    hint: "Who is logged in",
    spec: { size: 24, weight: 600, color: "text", alpha: 1, spacing: 0, align: "center", caps: false, shadow: false },
    fields: textFields()
  },
  hostname: {
    name: "Host name", group: "Text", glyph: "󰒋",
    hint: "The machine's name",
    spec: { size: 18, weight: 400, color: "text", alpha: 0.6, spacing: 2, align: "center", caps: true, shadow: false },
    fields: textFields()
  },
  status: {
    name: "Status line", group: "Text", glyph: "󰀦",
    hint: "Your hint, and the failure message when a password is wrong",
    spec: { text: "Enter your password to unlock", size: 16, weight: 400, color: "placeholder", alpha: 1, spacing: 0, align: "center", caps: false, shadow: false, attempts: true },
    fields: textFields([
      { key: "text", type: "text", label: "Idle text" },
      { key: "attempts", type: "bool", label: "Count failed attempts" }
    ])
  },

  password: {
    name: "Password box", group: "Input", glyph: "󰌾",
    hint: "The normal input box, with the eye and fingerprint hints",
    sized: true, input: true,
    w: 400, h: 60,
    spec: { placeholder: "Enter password", glyph: true, fontScale: 1, align: "center" },
    fields: [
      { key: "placeholder", type: "text", label: "Placeholder" },
      { key: "glyph", type: "bool", label: "Lock glyph" },
      { key: "fontScale", type: "slider", label: "Text scale", min: 0.6, max: 2, step: 0.1 },
      { key: "align", type: "choice", label: "Align", options: ALIGNMENTS }
    ]
  },
  dots: {
    name: "Dots", group: "Input", glyph: "󰇼",
    hint: "No box, just a dot per character — type anywhere",
    sized: true, input: true,
    w: 320, h: 44,
    spec: { size: 14, gap: 14, color: "text", alpha: 0.9, max: 24 },
    fields: [
      { key: "size", type: "number", label: "Dot size", min: 4, max: 48, step: 1 },
      { key: "gap", type: "number", label: "Gap", min: 2, max: 60, step: 1 },
      { key: "max", type: "number", label: "Max dots", min: 4, max: 64, step: 1 },
      { key: "color", type: "color", label: "Color" },
      { key: "alpha", type: "slider", label: "Opacity", min: 0.1, max: 1, step: 0.05 }
    ]
  },

  avatar: {
    name: "Avatar", group: "Media", glyph: "󰀉",
    hint: "Your picture, or your initial when there is none",
    sized: true, square: true,
    w: 120, h: 120,
    spec: { borderWidth: 0, borderAlpha: 0.25, shadow: true },
    fields: [
      { key: "borderWidth", type: "number", label: "Ring width", min: 0, max: 20, step: 1 },
      { key: "borderAlpha", type: "slider", label: "Ring opacity", min: 0.05, max: 1, step: 0.05 },
      { key: "shadow", type: "bool", label: "Drop shadow" }
    ]
  },
  image: {
    name: "Image", group: "Media", glyph: "󰋩",
    hint: "A picture file of your own",
    sized: true,
    w: 240, h: 160,
    spec: { path: "", radius: 8, mode: "crop", alpha: 1 },
    fields: [
      { key: "path", type: "file", label: "File" },
      { key: "radius", type: "number", label: "Corner radius", min: 0, max: 200, step: 2 },
      { key: "mode", type: "choice", label: "Fit", options: [
        { id: "crop", name: "Fill and crop" },
        { id: "fit", name: "Fit inside" },
        { id: "stretch", name: "Stretch" }
      ] },
      { key: "alpha", type: "slider", label: "Opacity", min: 0.05, max: 1, step: 0.05 }
    ]
  },

  weather: {
    name: "Weather", group: "Live", glyph: "󰖐",
    hint: "The weather now, from wttr.in for the place in Omarchy's weather settings",
    spec: { unit: "c", icon: true, condition: true, place: false, size: 22, weight: 400, color: "text", alpha: 0.9, spacing: 0, align: "center", caps: false, shadow: true },
    fields: textFields([
      { key: "unit", type: "choice", label: "Unit", options: [
        { id: "c", name: "Celsius" },
        { id: "f", name: "Fahrenheit" }
      ] },
      { key: "icon", type: "bool", label: "Icon" },
      { key: "condition", type: "bool", label: "Condition" },
      { key: "place", type: "bool", label: "Place" }
    ])
  },
  media: {
    name: "Now playing", group: "Live", glyph: "󰝚",
    hint: "The track that is playing, from any player on the desktop",
    spec: { show: "both", icon: true, idle: "Nothing playing", size: 20, weight: 400, color: "text", alpha: 0.85, spacing: 0, align: "center", caps: false, shadow: true },
    fields: textFields([
      { key: "show", type: "choice", label: "Show", options: [
        { id: "both", name: "Title and artist" },
        { id: "title", name: "Title" },
        { id: "artist", name: "Artist" }
      ] },
      { key: "icon", type: "bool", label: "Icon" },
      { key: "idle", type: "text", label: "When nothing plays" }
    ])
  },
  art: {
    name: "Album art", group: "Live", glyph: "󰀥",
    hint: "The cover of the track that is playing",
    sized: true, square: true,
    w: 200, h: 200,
    spec: { radius: 16, alpha: 1, shadow: true, hideIdle: false },
    fields: [
      { key: "radius", type: "number", label: "Corner radius", min: 0, max: 200, step: 2 },
      { key: "alpha", type: "slider", label: "Opacity", min: 0.05, max: 1, step: 0.05 },
      { key: "shadow", type: "bool", label: "Drop shadow" },
      { key: "hideIdle", type: "bool", label: "Hide when nothing plays" }
    ]
  },
  battery: {
    name: "Battery", group: "Live", glyph: "󰁹",
    hint: "How full the battery is, and whether it is charging",
    spec: { icon: true, state: true, hideWithout: false, size: 18, weight: 400, color: "text", alpha: 0.8, spacing: 0, align: "center", caps: false, shadow: false },
    fields: textFields([
      { key: "icon", type: "bool", label: "Icon" },
      { key: "state", type: "bool", label: "Say when charging" },
      { key: "hideWithout", type: "bool", label: "Hide without a battery" }
    ])
  },
  system: {
    name: "System info", group: "Live", glyph: "󰍛",
    hint: "Uptime, memory in use, load or the kernel",
    spec: { stat: "uptime", label: true, size: 16, weight: 400, color: "text", alpha: 0.7, spacing: 0, align: "center", caps: false, shadow: false },
    fields: textFields([
      { key: "stat", type: "choice", label: "Show", options: [
        { id: "uptime", name: "Uptime" },
        { id: "memory", name: "Memory" },
        { id: "load", name: "Load" },
        { id: "kernel", name: "Kernel" }
      ] },
      { key: "label", type: "bool", label: "Label" }
    ])
  },
  month: {
    name: "Month", group: "Live", glyph: "󰸗",
    hint: "This month's calendar, with today marked",
    spec: { size: 36, color: "text", alpha: 0.9, accent: "accent", title: true, weekdays: true },
    fields: [
      { key: "size", type: "number", label: "Cell size", min: 12, max: 120, step: 2 },
      { key: "color", type: "color", label: "Color" },
      { key: "alpha", type: "slider", label: "Opacity", min: 0.05, max: 1, step: 0.05 },
      { key: "accent", type: "color", label: "Today" },
      { key: "title", type: "bool", label: "Month name" },
      { key: "weekdays", type: "bool", label: "Weekdays" }
    ]
  },

  panel: {
    name: "Panel", group: "Shapes", glyph: "󰝦",
    hint: "A rounded surface to sit things on",
    sized: true,
    w: 460, h: 300,
    spec: { color: "surface", alpha: 0.55, radius: 20, borderAlpha: 0.12, borderColor: "text", shadow: true },
    fields: [
      { key: "color", type: "color", label: "Fill" },
      { key: "alpha", type: "slider", label: "Fill opacity", min: 0, max: 1, step: 0.05 },
      { key: "radius", type: "number", label: "Corner radius", min: 0, max: 200, step: 2 },
      { key: "borderColor", type: "color", label: "Border" },
      { key: "borderAlpha", type: "slider", label: "Border opacity", min: 0, max: 1, step: 0.02 },
      { key: "shadow", type: "bool", label: "Drop shadow" }
    ]
  },
  line: {
    name: "Divider", group: "Shapes", glyph: "󰧟",
    hint: "A hairline rule",
    sized: true,
    w: 320, h: 1,
    spec: { color: "text", alpha: 0.2 },
    fields: [
      { key: "color", type: "color", label: "Color" },
      { key: "alpha", type: "slider", label: "Opacity", min: 0.02, max: 1, step: 0.02 }
    ]
  },

  // Drawn in the designer's grid editor and animated by ttfx, the terminal
  // text effects Omarchy ships. The drawing is block characters, so it is
  // just text: it lives in the design file with everything else.
  ttfx: {
    name: "ttfx art", group: "Effects", glyph: "󰸴",
    hint: "A drawing animated by ttfx — draw it in the grid editor",
    spec: { art: "", effect: "decrypt", size: 14, color: "text", accent: "accent", rate: 60, margin: 1, replay: true },
    fields: [
      { key: "art", type: "art", label: "Drawing" },
      { key: "effect", type: "choice", label: "Effect", options: TTFX_EFFECTS },
      { key: "size", type: "number", label: "Cell size", min: 4, max: 80, step: 1 },
      { key: "color", type: "color", label: "Color" },
      { key: "accent", type: "color", label: "Accent" },
      { key: "rate", type: "number", label: "Frames per second", min: 10, max: 240, step: 10 },
      { key: "margin", type: "number", label: "Canvas margin", min: 0, max: 20, step: 1 },
      { key: "replay", type: "bool", label: "Play again on a wrong password" }
    ]
  },

  custom: {
    name: "Custom QML", group: "Yours", glyph: "󰘦",
    hint: "Write the QML yourself — lock.now, lock.userName and the rest are in scope",
    sized: true,
    w: 300, h: 120,
    spec: { qml: 'Text {\n  anchors.centerIn: parent\n  text: Qt.formatDate(lock.now, "dddd")\n  color: Color.lock.text\n  font.family: Style.font.family\n  font.pixelSize: 32\n}' },
    fields: [
      { key: "qml", type: "code", label: "QML" }
    ]
  }
}

var GROUPS = ["Background", "Text", "Input", "Media", "Live", "Shapes", "Effects", "Yours"]

function kind(id) { return KINDS[id] || null }

function kindName(id) { return KINDS[id] ? KINDS[id].name : id }

function paletteFor(group) {
  var out = []
  for (var id in KINDS) if (KINDS[id].group === group) out.push({ id: id, kind: KINDS[id] })
  out.sort(function(a, b) { return a.kind.name.localeCompare(b.kind.name) })
  return out
}

function isFill(node) { return !!(node && KINDS[node.kind] && KINDS[node.kind].fill) }
function isInput(node) { return !!(node && KINDS[node.kind] && KINDS[node.kind].input) }
function isSized(node) { return !!(node && KINDS[node.kind] && KINDS[node.kind].sized) }
function isSquare(node) { return !!(node && KINDS[node.kind] && KINDS[node.kind].square) }

function clone(v) { return JSON.parse(JSON.stringify(v)) }

// ---------------------------------------------------------------- documents

function newNode(kindId, id) {
  var k = KINDS[kindId]
  if (!k) return null
  return {
    id: id,
    kind: kindId,
    anchor: "center",
    dx: 0,
    dy: 0,
    w: k.w || 0,
    h: k.h || 0,
    spec: clone(k.spec || {})
  }
}

function nextId(doc) {
  var n = 1
  var used = {}
  for (var i = 0; i < doc.nodes.length; i++) used[doc.nodes[i].id] = true
  while (used["n" + n]) n++
  return "n" + n
}

function emptyDoc(name) {
  return { v: VERSION, name: name || DEFAULT_NAME, nodes: [] }
}

// What a brand new design starts as: a wallpaper, the time, the date and a
// place to type. Enough that pressing Save right away gives a lock screen
// that works.
function starterDoc(name) {
  var doc = emptyDoc(name)
  function add(kindId, anchor, dx, dy, spec) {
    var n = newNode(kindId, nextId(doc))
    n.anchor = anchor
    n.dx = dx
    n.dy = dy
    if (spec) for (var key in spec) n.spec[key] = spec[key]
    doc.nodes.push(n)
    return n
  }
  add("wallpaper", "center", 0, 0)
  add("clock", "center", 0, -170)
  add("date", "center", 0, -60)
  add("password", "center", 0, 40)
  add("status", "center", 0, 110)
  return doc
}

function validate(doc) {
  if (!doc || typeof doc !== "object") return null
  if (!(doc.nodes instanceof Array)) return null
  var out = { v: VERSION, name: String(doc.name || DEFAULT_NAME), nodes: [] }
  for (var i = 0; i < doc.nodes.length; i++) {
    var n = doc.nodes[i]
    if (!n || !KINDS[n.kind]) continue
    out.nodes.push({
      id: String(n.id || ("n" + (i + 1))),
      kind: String(n.kind),
      anchor: ANCHORS.indexOf(n.anchor) === -1 ? "center" : n.anchor,
      dx: Math.round(Number(n.dx) || 0),
      dy: Math.round(Number(n.dy) || 0),
      w: Math.max(0, Math.round(Number(n.w) || 0)),
      h: Math.max(0, Math.round(Number(n.h) || 0)),
      spec: (n.spec && typeof n.spec === "object") ? clone(n.spec) : clone(KINDS[n.kind].spec || {})
    })
  }
  return out
}

// The designer holds its nodes as LayoutNode objects so the canvas can bind
// to them; on the way to a file they become plain records again. Reads
// `nodeId` or `id`, so it takes either shape.
function plainNode(n) {
  return {
    id: String(n.nodeId !== undefined && String(n.nodeId).length > 0 ? n.nodeId : n.id),
    kind: String(n.kind),
    anchor: String(n.anchor),
    dx: Math.round(n.dx) || 0,
    dy: Math.round(n.dy) || 0,
    w: Math.round(n.w) || 0,
    h: Math.round(n.h) || 0,
    spec: JSON.parse(JSON.stringify(n.spec || {}))
  }
}

function docOf(nodes, name) {
  var out = { v: VERSION, name: String(name || DEFAULT_NAME), nodes: [] }
  for (var i = 0; i < (nodes || []).length; i++) out.nodes.push(plainNode(nodes[i]))
  return out
}

function idsOf(nodes) {
  var out = []
  for (var i = 0; i < (nodes || []).length; i++)
    out.push(String(nodes[i].nodeId !== undefined && String(nodes[i].nodeId).length > 0 ? nodes[i].nodeId : nodes[i].id))
  return out
}

// The first free nN, given the ids already taken.
function nextIdFrom(ids) {
  var n = 1
  var used = {}
  for (var i = 0; i < ids.length; i++) used[ids[i]] = true
  while (used["n" + n]) n++
  return "n" + n
}

function serialize(doc) { return JSON.stringify(doc) }

// Pull the layout back out of a design file. Returns null when the file was
// not made here.
function parse(text) {
  var lines = String(text || "").split("\n")
  for (var i = 0; i < lines.length && i < 40; i++) {
    var l = lines[i]
    var at = l.indexOf(MARKER)
    if (at === -1) continue
    try {
      return validate(JSON.parse(l.substring(at + MARKER.length)))
    } catch (e) {
      return null
    }
  }
  return null
}

function isDesignerFile(text) { return parse(text) !== null }

// ------------------------------------------------------------- code writing

function anchorLines(node, indent) {
  var out = []
  var col = anchorCol(node.anchor)
  var row = anchorRow(node.anchor)
  if (col === 0) {
    out.push(indent + "anchors.left: parent.left")
    out.push(indent + "anchors.leftMargin: " + node.dx)
  } else if (col === 2) {
    out.push(indent + "anchors.right: parent.right")
    out.push(indent + "anchors.rightMargin: " + (-node.dx))
  } else {
    out.push(indent + "anchors.horizontalCenter: parent.horizontalCenter")
    out.push(indent + "anchors.horizontalCenterOffset: " + node.dx)
  }
  if (row === 0) {
    out.push(indent + "anchors.top: parent.top")
    out.push(indent + "anchors.topMargin: " + node.dy)
  } else if (row === 2) {
    out.push(indent + "anchors.bottom: parent.bottom")
    out.push(indent + "anchors.bottomMargin: " + (-node.dy))
  } else {
    out.push(indent + "anchors.verticalCenter: parent.verticalCenter")
    out.push(indent + "anchors.verticalCenterOffset: " + node.dy)
  }
  return out
}

// The generated file is a DesignBase with one DesignerItem per node. The
// layout comment above it is what the designer reads back; the code is
// rewritten from it on every save.
function generate(doc, pluginId) {
  var out = []
  var nodes = doc.nodes || []
  var inputNode = null
  for (var i = 0; i < nodes.length; i++) if (isInput(nodes[i])) { inputNode = nodes[i]; break }

  out.push("// " + doc.name + " — made with the lock screen designer.")
  out.push("// Open it there again with E in the explorer (omarchy-shell lock explore).")
  out.push("// Everything below the layout line is generated from it: edit the code by")
  out.push("// hand and the next save from the designer replaces it.")
  out.push("// " + MARKER + serialize(doc))
  out.push("import QtQuick")
  out.push("import QtQuick.Effects")
  out.push("import qs.Commons")
  out.push('import "../plugins/' + pluginId + '/designs"')
  out.push("")
  out.push("DesignBase {")
  out.push("  id: lock")
  out.push("  inputItem: " + (inputNode ? inputNode.id + ".inputItem" : "fallbackInput"))
  out.push("")
  out.push("  MouseArea {")
  out.push("    anchors.fill: parent")
  out.push("    hoverEnabled: true")
  out.push("    onClicked: { lock.wakeRequested(); lock.forcePasswordFocus() }")
  out.push("    onPositionChanged: lock.wakeRequested()")
  out.push("  }")

  if (!inputNode) {
    out.push("")
    out.push("  // No input component in the layout — this keeps the screen unlockable.")
    out.push("  LockInput { id: fallbackInput; lock: lock; anchors.centerIn: parent; width: 1; height: 1; opacity: 0 }")
  }

  for (var j = 0; j < nodes.length; j++) {
    var n = nodes[j]
    var k = KINDS[n.kind]
    out.push("")
    out.push("  // " + k.name)
    out.push("  DesignerItem {")
    out.push("    id: " + n.id)
    out.push("    lock: lock")
    out.push('    kind: "' + n.kind + '"')
    if (k.fill) {
      out.push("    fillParent: true")
    } else {
      var lines = anchorLines(n, "    ")
      for (var a = 0; a < lines.length; a++) out.push(lines[a])
      if (n.w > 0) out.push("    fixedWidth: " + n.w)
      if (n.h > 0 && !k.square) out.push("    fixedHeight: " + n.h)
    }
    if (n.kind === "custom") {
      var body = String((n.spec && n.spec.qml) || "").split("\n")
      out.push("")
      for (var b = 0; b < body.length; b++) out.push(body[b].length > 0 ? "    " + body[b] : "")
    } else {
      out.push("    spec: (" + JSON.stringify(n.spec || {}) + ")")
    }
    out.push("  }")
  }

  out.push("}")
  return out.join("\n") + "\n"
}

// -------------------------------------------------------------- components

// A saved component is a group of nodes with their offsets kept relative to
// the group's own top-left corner, so it can be dropped anywhere:
//   { v: 1, name: "Glass card", w: 420, h: 260,
//     nodes: [ { ...node, rx: 0, ry: 0 }, ... ] }
function makeComponent(name, nodes, rects) {
  if (!nodes || nodes.length === 0) return null
  nodes = nodes.map(plainNode)
  var minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity
  for (var i = 0; i < nodes.length; i++) {
    var r = rects[i]
    minX = Math.min(minX, r.x)
    minY = Math.min(minY, r.y)
    maxX = Math.max(maxX, r.x + r.w)
    maxY = Math.max(maxY, r.y + r.h)
  }
  var out = { v: VERSION, name: String(name || "Component"), w: Math.round(maxX - minX), h: Math.round(maxY - minY), nodes: [] }
  for (var j = 0; j < nodes.length; j++) {
    var n = clone(nodes[j])
    n.rx = Math.round(rects[j].x - minX)
    n.ry = Math.round(rects[j].y - minY)
    // The size it actually rendered at, needed to re-derive offsets for the
    // pieces that size themselves from their content.
    n.rw = Math.round(rects[j].w)
    n.rh = Math.round(rects[j].h)
    out.nodes.push(n)
  }
  return out
}

function componentSlug(name) {
  var s = String(name || "component").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "")
  return s.length > 0 ? s : "component"
}

// Lay a saved component out at a screen position, as plain nodes ready to be
// added to a design. Every piece takes the anchor of the group's centre, so
// the group travels together.
function instantiate(takenIds, comp, x, y, screenW, screenH) {
  var made = []
  var ids = (takenIds || []).slice()
  var anchor = anchorAt(x + (comp.w || 0) / 2, y + (comp.h || 0) / 2, screenW, screenH)
  for (var i = 0; i < (comp.nodes || []).length; i++) {
    var src = comp.nodes[i]
    if (!KINDS[src.kind]) continue
    var n = clone(src)
    n.id = nextIdFrom(ids)
    ids.push(n.id)
    var nx = x + (Number(n.rx) || 0)
    var ny = y + (Number(n.ry) || 0)
    var w = n.w > 0 ? n.w : (Number(n.rw) || 0)
    var h = n.h > 0 ? n.h : (Number(n.rh) || 0)
    n.anchor = anchor
    n.dx = Math.round(dxFor(anchor, nx, w, screenW))
    n.dy = Math.round(dyFor(anchor, ny, h, screenH))
    delete n.rx
    delete n.ry
    delete n.rw
    delete n.rh
    made.push(n)
  }
  return made
}
