import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "Ttfx.js" as Ttfx

// Plays a ttfx effect (Omarchy's terminal text effects, /usr/bin/ttfx) on a
// block of text. ttfx paces the animation itself and streams ANSI frames on
// stdout; every frame starts with a cursor-up, which is where one ends and the
// next begins. Only the newest frame is parsed and painted, once per rendered
// frame, so a slow machine skips frames instead of falling behind.
//
// Nothing here touches authentication. If ttfx is missing or fails, the text
// is shown plain in the theme color.
Item {
  id: fx

  property string text: ""
  property string effect: "decrypt"
  // Options after the effect name, per effect: { burn: ["--burn-colors", ...] }.
  // An entry can also be a named variant of an effect,
  // { blip: { effect: "vhstape", args: [...] } }, played with play("blip").
  // Effects not listed get the theme preset from Ttfx.js.
  property var effectOptions: ({})
  // ttfx frame rate. Effects are a fixed number of frames, so a higher rate
  // plays the same effect faster.
  property int frameRate: 60
  // Paints per second at most. ttfx keeps its own pace, frames in between are
  // skipped, so this trades smoothness for CPU without slowing the effect.
  property int maxPaintRate: 60
  // Canvas in cells. 0 fits the text with `margin` cells around it.
  property int columns: 0
  property int rows: 0
  property int margin: 2
  // Where the text sits in the canvas: c, n, s, e, w, ne, nw, se or sw.
  property string anchorText: "c"

  property int pixelSize: Style.font.body
  property string fontFamily: Style.font.family
  property color textColor: Color.lock.text
  property color accentColor: Color.lock.borderActive
  property color mutedColor: Color.muted
  property color errorColor: Color.lock.textError
  property color backgroundColor: Color.background

  // Plays an effect again whenever `text` changes: `replayEffect`, or `effect`
  // when that is empty.
  property bool replayOnTextChange: true
  property string replayEffect: ""
  property bool autoPlay: true
  // Frame rate for the automatic play on load, 0 for `frameRate`.
  property int autoPlayRate: 0
  // Stop ttfx while nothing shows it. Items keep visible: true inside a window
  // that is not mapped, and the lock surface and the explorer preview both
  // keep their design loaded in one, so the window has to be checked too.
  // Nothing to draw for while the display is off, and ttfx is a process and a
  // canvas repaint per frame -- the most expensive thing a design does. The
  // design carries that as DesignBase.animating; this sits some way inside it,
  // so the flag is found by walking up the parents. Reading it here is what
  // binds to it, so the effect stops and starts with the panel.
  readonly property bool designAwake: {
    var p = parent
    while (p) {
      if (p.animating !== undefined) return p.animating === true
      p = p.parent
    }
    return true
  }
  property bool active: designAwake && visible && Window.window !== null && Window.window.visible

  readonly property bool playing: proc.running
  readonly property int textColumns: {
    var w = 0
    var lines = String(text).split("\n")
    for (var i = 0; i < lines.length; i++) w = Math.max(w, lines[i].length)
    return w
  }
  readonly property int textRows: String(text).split("\n").length
  readonly property int canvasColumns: columns > 0 ? columns : textColumns + margin * 2
  readonly property int canvasRows: rows > 0 ? rows : textRows + margin * 2
  readonly property real cellWidth: probe.contentWidth / 10
  readonly property real cellHeight: Math.ceil(probe.contentHeight)

  signal finished()
  // Reduce motion shows a still frame of the design; the moment an effect is
  // done is the frame worth holding, so the design is told (DesignBase).
  onFinished: {
    var p = parent
    while (p) {
      if (typeof p.stillRequested === "function") { p.stillRequested(); return }
      p = p.parent
    }
  }

  implicitWidth: Math.ceil(canvasColumns * cellWidth)
  implicitHeight: canvasRows * cellHeight

  property string queuedEffect: ""
  property int queuedRate: 0
  property string runningEffect: ""
  property int runningRate: 0
  property real sincePaint: 1
  property var frameRows: []
  property bool frameStarted: false
  property var latestRows: null
  property bool gotFrame: false
  property var frame: []

  function palette() {
    return { text: textColor, accent: accentColor, muted: mutedColor, error: errorColor, background: backgroundColor }
  }

  // Plays `name`, or `effect` when omitted, at `rate` frames per second or
  // `frameRate`. A running effect is cut short.
  function play(name, rate) {
    if (!active || text.length === 0) return
    queuedEffect = name || effect
    queuedRate = rate || 0
    if (proc.running) { proc.running = false; return } // onExited starts the queued one
    start()
  }

  function stop() {
    queuedEffect = ""
    proc.running = false
  }

  function start() {
    var name = queuedEffect || effect
    var rate = queuedRate || frameRate
    queuedEffect = ""
    queuedRate = 0
    runningEffect = name
    runningRate = rate
    var option = effectOptions ? effectOptions[name] : undefined
    var ttfxEffect = option && option.effect ? option.effect : name
    var extra = option ? (option.effect ? option.args || [] : option) : Ttfx.effectArgs(name, palette())
    frameRows = []
    frameStarted = false
    proc.command = [
      "sh", "-c", "t=$1; shift; exec ttfx \"$@\" <<__TTFX_TEXT__\n$t\n__TTFX_TEXT__", "ttfx",
      text,
      "--ignore-terminal-dimensions",
      "--canvas-width", String(canvasColumns),
      "--canvas-height", String(canvasRows),
      "--anchor-canvas", "c",
      "--anchor-text", anchorText,
      "--frame-rate", String(rate),
      "--terminal-background-color", Ttfx.hex(backgroundColor),
      ttfxEffect
    ].concat(extra)
    proc.running = true
  }

  // Measures a cell the way the Canvas will draw it. FontMetrics resolves a
  // generic family like "monospace" to a different face and comes out narrow.
  Text {
    id: probe
    visible: false
    text: "MMMMMMMMMM"
    font.family: fx.fontFamily
    font.pixelSize: fx.pixelSize
  }

  Process {
    id: proc
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: function(data) { fx.feed(data) }
    }
    onExited: function(exitCode) {
      if (fx.frameStarted && fx.frameRows.length > 0) fx.latestRows = fx.frameRows
      fx.frameRows = []
      fx.frameStarted = false
      // Starting again from inside this handler is ignored, so wait a turn.
      if (fx.queuedEffect.length > 0 && fx.active) { Qt.callLater(fx.start); return }
      if (exitCode !== 0 && !fx.gotFrame) console.warn("TtfxText: ttfx exited with " + exitCode)
      fx.finished()
    }
  }

  function feed(line) {
    var re = /\x1b\[\d+A/
    for (;;) {
      var m = re.exec(line)
      if (!m) break
      if (frameStarted) {
        frameRows.push(line.substring(0, m.index))
        latestRows = frameRows
      }
      frameRows = []
      frameStarted = true
      line = line.substring(m.index + m[0].length)
    }
    if (frameStarted) frameRows.push(line)
  }

  FrameAnimation {
    running: fx.latestRows !== null
    onTriggered: {
      fx.sincePaint += frameTime
      if (fx.sincePaint < 1 / Math.max(1, fx.maxPaintRate) - 0.004) return
      fx.sincePaint = 0
      var rows = fx.latestRows
      fx.latestRows = null
      if (!rows) return
      fx.frame = rows.map(Ttfx.parseRow)
      fx.gotFrame = true
      canvas.requestPaint()
    }
  }

  // Before the first frame arrives the plain text would flash up and vanish
  // again, so it only shows once ttfx has had its chance.
  readonly property bool showPlain: !gotFrame && !proc.running && queuedEffect.length === 0
  onShowPlainChanged: canvas.requestPaint()

  Canvas {
    id: canvas
    anchors.centerIn: parent
    width: Math.ceil(fx.canvasColumns * fx.cellWidth)
    height: fx.canvasRows * fx.cellHeight
    // Painted on its own thread, so a busy effect does not hold up the
    // field and the rest of the lock screen.
    renderStrategy: Canvas.Threaded
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
      var ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)
      var rows = fx.gotFrame ? fx.frame : fx.showPlain ? Ttfx.plainFrame(fx.text, fx.canvasColumns, fx.canvasRows, fx.textColor) : []
      var cw = fx.cellWidth, ch = fx.cellHeight
      ctx.font = fx.pixelSize + "px \"" + fx.fontFamily + "\""
      ctx.textBaseline = "middle"
      for (var r = 0; r < rows.length; r++) {
        var runs = rows[r]
        var y = r * ch
        for (var k = 0; k < runs.length; k++) {
          var run = runs[k]
          var color = run.color || String(fx.textColor)
          ctx.fillStyle = color
          // Consecutive text cells go out as one fillText and consecutive full
          // blocks as one rectangle; a frame of the logo is a few hundred
          // calls instead of thousands. The cell width is measured the way the
          // Canvas draws, so a run of text keeps to the grid.
          var t = run.text, i = 0, n = t.length
          while (i < n) {
            var b = Ttfx.BLOCKS[t.charAt(i)]
            var j = i + 1
            if (!b) {
              while (j < n && !Ttfx.BLOCKS[t.charAt(j)]) j++
              ctx.fillText(t.substring(i, j), (run.col + i) * cw, y + ch / 2)
            } else {
              // Only whole-width blocks of the same kind merge sideways.
              if (b[0] === 0 && b[2] === 1)
                while (j < n && t.charAt(j) === t.charAt(i)) j++
              var x = (run.col + i) * cw
              var x0 = Math.floor(x + b[0] * cw), y0 = Math.floor(y + b[1] * ch)
              // Snapped to whole pixels and grown to the next one so cells
              // overlap instead of leaving a seam.
              var x1 = b[0] === 0 && b[2] === 1 ? Math.ceil((run.col + j) * cw) : Math.ceil(x + (b[0] + b[2]) * cw)
              if (b[4] !== 1) ctx.globalAlpha = b[4]
              ctx.fillRect(x0, y0, x1 - x0, Math.ceil(y + (b[1] + b[3]) * ch) - y0)
              if (b[4] !== 1) ctx.globalAlpha = 1
            }
            i = j
          }
        }
      }
    }
  }

  onTextChanged: if (replayOnTextChange && (gotFrame || proc.running)) play(replayEffect)
  // The first play usually starts before the design has its size, so a canvas
  // that changes under a running effect starts that effect over at the new size.
  onCanvasColumnsChanged: Qt.callLater(restartForSize)
  onCanvasRowsChanged: Qt.callLater(restartForSize)
  function restartForSize() {
    if (proc.running && queuedEffect.length === 0) play(runningEffect, runningRate)
  }
  onActiveChanged: {
    if (!active) stop()
    else if (autoPlay) play(effect, autoPlayRate)
  }
  Component.onCompleted: if (autoPlay) Qt.callLater(play, effect, autoPlayRate)
}
