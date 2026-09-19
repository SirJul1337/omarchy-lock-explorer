.pragma library

// Helpers for TtfxText.qml: effect presets in the theme's colors, the ANSI
// frame parser, and a block font for clocks that ttfx can animate cell by cell.

// Effects that finish on their own in a few seconds on a clock-sized text.
// matrix never ends and swarm/rings/fireworks run 20-40 s, so they are left out.
var QUICK = ["expand", "highlight", "middleout", "slide", "slice", "wipe", "rain", "pour", "scattered", "randomsequence", "sweep", "smoke"]
var SHOWY = ["beams", "burn", "crumble", "unstable", "laseretch", "synthgrid", "decrypt", "bouncyballs", "spray", "print", "errorcorrect", "bubbles"]

function hex(c) { return String(c).replace("#", "").slice(-6) }

// Theme-colored options per effect. `p` carries text, accent, muted, error and
// background colors. Anything not listed gets only the final gradient.
function effectArgs(effect, p) {
  var text = hex(p.text), accent = hex(p.accent), muted = hex(p.muted), error = hex(p.error)
  var final = ["--final-gradient-stops", accent, text, "--final-gradient-direction", "vertical"]
  switch (effect) {
  case "decrypt":
    return ["--typing-speed", "8", "--ciphertext-colors", muted, accent, text].concat(final)
  case "beams":
    return ["--beam-gradient-stops", text, accent].concat(final)
  case "burn":
    return ["--starting-color", muted, "--burn-colors", text, accent, error, muted].concat(final)
  case "synthgrid":
    return ["--grid-gradient-stops", muted, accent, "--text-gradient-stops", accent, text]
  case "unstable":
    return ["--unstable-color", error].concat(final)
  case "errorcorrect":
    return ["--error-color", error, "--correct-color", accent].concat(final)
  case "laseretch":
    return ["--laser-gradient-stops", text, accent, "--spark-gradient-stops", text, accent, "--cool-gradient-stops", accent, muted].concat(final)
  case "middleout":
  case "pour":
    return ["--starting-color", muted].concat(final)
  case "smoke":
    return ["--starting-color", muted, "--smoke-gradient-stops", muted, accent].concat(final)
  case "rain":
    return ["--rain-colors", muted, accent, text].concat(final)
  case "bouncyballs":
    return ["--ball-colors", accent, text, muted].concat(final)
  case "bubbles":
    return ["--bubble-colors", accent, text, muted, "--pop-color", text, "--no-rainbow"].concat(final)
  case "highlight":
    return ["--highlight-width", "6"].concat(final)
  default:
    return final
  }
}

// ESC[<params>m -> the foreground it leaves set. ttfx only emits 24-bit
// foregrounds and resets, so 256-color and background codes are skipped.
function sgr(params, current) {
  var parts = params.split(";")
  var color = current
  for (var i = 0; i < parts.length; i++) {
    var n = parts[i] === "" ? 0 : parseInt(parts[i], 10)
    if (n === 0 || n === 39) {
      color = null
    } else if ((n === 38 || n === 48) && parts[i + 1] === "2") {
      if (n === 38) color = "#" + [parts[i + 2], parts[i + 3], parts[i + 4]].map(function(v) {
        var h = Math.max(0, Math.min(255, parseInt(v, 10) || 0)).toString(16)
        return h.length < 2 ? "0" + h : h
      }).join("")
      i += 4
    } else if ((n === 38 || n === 48) && parts[i + 1] === "5") {
      i += 2
    }
  }
  return color
}

// SGR parameters -> color. A frame repeats the same few hundred color codes
// thousands of times, so each distinct code is decoded once.
var sgrCache = {}
var sgrCacheSize = 0

function sgrCached(params, current) {
  // Resets and anything that is not a plain 24-bit foreground depend on the
  // color before them, so only "38;2;r;g;b" goes through the cache.
  if (params.charCodeAt(0) !== 51 || params.charCodeAt(1) !== 56 || params.charCodeAt(2) !== 59 || params.charCodeAt(3) !== 50)
    return sgr(params, current)
  var hit = sgrCache[params]
  if (hit !== undefined) return hit
  if (sgrCacheSize > 8192) { sgrCache = {}; sgrCacheSize = 0 }
  var color = sgr(params, current)
  sgrCache[params] = color
  sgrCacheSize++
  return color
}

// One output row -> runs of { col, text, color }. A run is cut at every space
// and color change, since nothing is drawn for a space.
function parseRow(row) {
  var runs = [], color = null, col = 0, run = null
  var i = 0, n = row.length
  while (i < n) {
    var code = row.charCodeAt(i)
    if (code === 27) {
      if (row.charCodeAt(i + 1) === 91) {
        var j = i + 2
        // Parameter bytes run until the final byte, 0x40-0x7e.
        while (j < n) {
          var cj = row.charCodeAt(j)
          if (cj >= 64 && cj <= 126) break
          j++
        }
        if (row.charCodeAt(j) === 109) color = sgrCached(row.substring(i + 2, j), color)
        i = j + 1
      } else {
        i += 2
      }
      continue
    }
    i++
    if (code === 13) continue
    if (code === 32) { run = null; col++; continue }
    if (run === null || run.color !== color) {
      run = { col: col, text: "", color: color }
      runs.push(run)
    }
    run.text += row.charAt(i - 1)
    col++
  }
  return runs
}

// Block elements are drawn as rectangles so neighbouring cells meet without
// the hairline seams a font leaves. [x, y, w, h, alpha] in cell fractions.
var BLOCKS = {
  "█": [0, 0, 1, 1, 1], "▀": [0, 0, 1, 0.5, 1], "▄": [0, 0.5, 1, 0.5, 1],
  "▌": [0, 0, 0.5, 1, 1], "▐": [0.5, 0, 0.5, 1, 1],
  "░": [0, 0, 1, 1, 0.25], "▒": [0, 0, 1, 1, 0.5], "▓": [0, 0, 1, 1, 0.75],
  "▁": [0, 0.875, 1, 0.125, 1], "▂": [0, 0.75, 1, 0.25, 1], "▃": [0, 0.625, 1, 0.375, 1],
  "▅": [0, 0.375, 1, 0.625, 1], "▆": [0, 0.25, 1, 0.75, 1], "▇": [0, 0.125, 1, 0.875, 1],
  "▏": [0, 0, 0.125, 1, 1], "▎": [0, 0, 0.25, 1, 1], "▍": [0, 0, 0.375, 1, 1],
  "▋": [0, 0, 0.625, 1, 1], "▊": [0, 0, 0.75, 1, 1], "▉": [0, 0, 0.875, 1, 1]
}

// Plain text as parsed rows, centered on the canvas like ttfx would, for when
// ttfx is not there to animate it.
function plainFrame(text, columns, rows, color) {
  var lines = String(text).split("\n")
  var width = 0
  for (var i = 0; i < lines.length; i++) width = Math.max(width, lines[i].length)
  var left = Math.max(0, Math.floor((columns - width) / 2))
  var top = Math.max(0, Math.floor((rows - lines.length) / 2))
  var frame = []
  for (var r = 0; r < top; r++) frame.push([])
  for (var k = 0; k < lines.length; k++) {
    frame.push(parseRow(lines[k]).map(function(run) {
      return { col: run.col + left, text: run.text, color: String(color) }
    }))
  }
  return frame
}

// What a custom input shows instead of the typed text: checking, the failure,
// the security key's status, or `idle` when there is nothing to report.
function inputStatus(lock, idle) {
  if (!lock) return idle
  if (lock.authenticatingPassword) return "Checking…"
  if (lock.errorState) return lock.failureMessage
  if (lock.fido2Active) return lock.fido2Status.length > 0 ? lock.fido2Status : "Waiting for your key…"
  return idle
}

// The typed password as a custom input shows it: dots, or the text itself
// while the eye toggle is on, capped at `max` characters from the end.
function masked(lock, dot, max) {
  if (!lock) return ""
  var t = lock.passwordVisible && !lock.fido2Active ? lock.passwordText : dot.repeat(lock.passwordText.length)
  return t.length > max ? "…" + t.slice(t.length - max + 1) : t
}

// The square Omarchy logo from /usr/share/omarchy/icon.txt, for when neither
// the branding copy nor that file can be read.
var ICON = [
  "██████████████████████████████████████████████████████",
  "██████████████████████████████████████████████████████",
  "████                     ████                     ████",
  "████                     ████                     ████",
  "████    █████████████████████         ████████    ████",
  "████    █████████████████████         ████████    ████",
  "████    ████                              ████    ████",
  "████    ████                              ████    ████",
  "████    ████                              ████    ████",
  "████    ████                              ████    ████",
  "████    ████                              ████    ████",
  "████    ████                              ████    ████",
  "████████████                              ████    ████",
  "████████████                              ████    ████",
  "████    ████                              ████    ████",
  "████    ████                              ████    ████",
  "████    ████                              ████    ████",
  "████    ████                              ████    ████",
  "████    ████                              ████    ████",
  "████    ████                              ████    ████",
  "████    ██████████████████████████████████████    ████",
  "████    ██████████████████████████████████████    ████",
  "████                     ████                     ████",
  "████                     ████                     ████",
  "█████████████████████████████     ████████████████████",
  "█████████████████████████████     ████████████████████"
].join("\n")

// 3x5 digits, each lit pixel two cells wide so they come out square-ish.
var GLYPHS = {
  "0": ["###", "# #", "# #", "# #", "###"],
  "1": [" # ", "## ", " # ", " # ", "###"],
  "2": ["###", "  #", "###", "#  ", "###"],
  "3": ["###", "  #", "###", "  #", "###"],
  "4": ["# #", "# #", "###", "  #", "  #"],
  "5": ["###", "#  ", "###", "  #", "###"],
  "6": ["###", "#  ", "###", "# #", "###"],
  "7": ["###", "  #", "  #", "  #", "  #"],
  "8": ["###", "# #", "###", "# #", "###"],
  "9": ["###", "# #", "###", "  #", "###"],
  ":": [" ", "#", " ", "#", " "]
}

function blockText(text) {
  var chars = String(text).split("").filter(function(c) { return GLYPHS[c] !== undefined })
  var rows = ["", "", "", "", ""]
  for (var k = 0; k < chars.length; k++) {
    var g = GLYPHS[chars[k]]
    for (var r = 0; r < 5; r++) {
      if (k > 0) rows[r] += "  "
      rows[r] += g[r].replace(/#/g, "██").replace(/ /g, "  ")
    }
  }
  return rows.join("\n")
}
