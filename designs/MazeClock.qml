import QtQuick
import qs.Commons

// A maze that builds itself and then solves itself, over and over, with the time
// in a box in the middle of it. The idea is the "ScreenMazer" macOS
// screensaver (https://github.com/dado3212/screenmazer); the code here is new.
//
// The maze is carved by a depth first search, a few cells at a time. When it is
// done a path runs from the top left corner to the bottom right one, then the
// whole thing waits a moment, fades and starts a new maze. It is flat: solid
// blocks with hard edges, in a few colors.
DesignBase {
  id: lock
  inputItem: field.input
  shakeOnFail: true

  // ======================================================================
  // Settings. Change a number and save: the design reloads.
  // ======================================================================

  // ---- Speed and cost -------------------------------------------------
  // How many steps a second. Each step carves some cells or draws some blocks
  // of the path, then redraws what changed. Every step costs about half a percent
  // of CPU on an Intel UHD 630 (8 is about 4%, 12 about 6%, 20 about 9%), so raise
  // it with fewer cells per step if you want it smoother.
  property real stepsPerSecond: 8
  // Cells carved per step, and blocks of the path drawn per step.
  property int carvePerStep: 75
  property int solvePerStep: 105
  // Seconds the finished maze, with its path, is left on screen before it fades
  // and a new one starts, and how long the fade takes (milliseconds).
  property real holdSeconds: 8
  property int fadeDuration: 1200

  // ---- The maze -------------------------------------------------------
  // Size of one block in pixels on a 1080 pixel tall screen. Walls and
  // corridors are each one block wide. Smaller makes a bigger, finer maze.
  property real blockSize: 12

  // ---- Colors ---------------------------------------------------------
  // The walls (the theme's accent, darkened), the corridors the search has been
  // down, the way it finally found, and the box and digits of the clock.
  property color wallColor: Qt.darker(Color.lock.borderActive, 1.5)
  property color searchColor: Qt.lighter(Color.lock.borderActive, 1.3)
  property color pathColor: Qt.lighter(Color.lock.borderActive, 1.9)
  property color clockColor: wallColor
  property color boxColor: wallColor

  // ---- The clock ------------------------------------------------------
  // Where the middle of the clock box is, as a share of the screen (0 to 1).
  property real clockX: 0.5
  property real clockY: 0.4
  // How many blocks across each pixel of a digit is. 1 gives a tiny clock.
  property int clockScale: 3
  // Show the box around the digits, and how thick it is in blocks.
  property bool showBox: true
  property int boxThickness: 2

  // ---- Driven by the design; do not set --------------------------------
  readonly property real block: Math.max(6, Math.round(blockSize * lock.height / 1080))
  // Cells: the maze has cols x rows cells, and (2 cols + 1) x (2 rows + 1)
  // blocks, so the walls take a block each.
  readonly property int cols: Math.max(4, Math.floor((lock.width / block - 1) / 2))
  readonly property int rows: Math.max(4, Math.floor((lock.height / block - 1) / 2))
  readonly property int bw: cols * 2 + 1
  readonly property int bh: rows * 2 + 1
  readonly property real offsetX: (lock.width - bw * block) / 2
  readonly property real offsetY: (lock.height - bh * block) / 2

  // The block grid: 0 wall, 1 corridor, 2 the clock box (kept out of the maze).
  property var grid: new Uint8Array(0)
  // 1 on blocks that are part of the path.
  property var onPath: new Uint8Array(0)
  property var visited: new Uint8Array(0)
  property var stack: []
  property var pathList: []
  property var solution: []
  property int pathDrawn: 0
  // What the maze is doing: "carve", "solve", "hold" or "fade".
  property string phase: "carve"
  property int holdTicks: 0
  // The picture: one number per block, an index into `palette` (0 is nothing).
  // The design writes it, the canvas shows it.
  property var pix: new Uint8Array(0)
  readonly property var palette: [null, wallColor, searchColor, pathColor, clockColor, boxColor]

  // The 3 x 5 pixel digits of the clock, row by row, 1 is lit.
  readonly property var font3x5: ({
    "0": "111101101101111", "1": "010110010010111", "2": "111001111100111",
    "3": "111001111001111", "4": "101101111001001", "5": "111100111001111",
    "6": "111100111101111", "7": "111001001001001", "8": "111101111101111",
    "9": "111101111001111", ":": "000010000010000"
  })

  function gi(x, y) { return y * bw + x }

  // The clock box, in blocks: where it starts and how big it is.
  readonly property string timeText: lock.clock("HH:mm")
  readonly property int digitCols: 3 * clockScale
  readonly property int boxPad: showBox ? boxThickness + 1 : 1
  readonly property int clockW: (timeText.length * 3 + (timeText.length - 1)) * clockScale + 2 * boxPad
  readonly property int clockH: 5 * clockScale + 2 * boxPad
  readonly property int clockLeft: Math.max(1, Math.min(bw - clockW - 1, Math.round(bw * clockX - clockW / 2)))
  readonly property int clockTop: Math.max(1, Math.min(bh - clockH - 1, Math.round(bh * clockY - clockH / 2)))

  // Put palette color `ci` on a block (0 clears it).
  function paint(x, y, ci) {
    var i = gi(x, y)
    if (pix[i] === ci) return
    pix[i] = ci
    changes.push(i)
  }
  // Blocks changed since the canvas last painted, and whether to paint it all.
  property var changes: []
  property bool paintAll: true

  // Reserve the clock's blocks and draw the time into them.
  function drawClock(markOnly) {
    var pad = boxPad
    for (var y = 0; y < clockH; y++) for (var x = 0; x < clockW; x++)
      grid[gi(clockLeft + x, clockTop + y)] = 2
    if (markOnly) return
    // The box: a one block ring, with a one block gap inside it.
    for (var by = 0; by < clockH; by++) for (var bx = 0; bx < clockW; bx++) {
      var t = boxThickness
      var edge = showBox && (bx < t || by < t || bx >= clockW - t || by >= clockH - t)
      paint(clockLeft + bx, clockTop + by, edge ? 5 : 0)
    }
    var x0 = clockLeft + pad
    var y0 = clockTop + pad
    for (var c = 0; c < timeText.length; c++) {
      var glyph = font3x5[timeText.charAt(c)] || font3x5["0"]
      var gx = x0 + c * 4 * clockScale
      for (var r = 0; r < 5; r++) for (var k = 0; k < 3; k++) {
        if (glyph.charAt(r * 3 + k) !== "1") continue
        for (var sy = 0; sy < clockScale; sy++) for (var sx = 0; sx < clockScale; sx++)
          paint(gx + k * clockScale + sx, y0 + r * clockScale + sy, 4)
      }
    }
    painter.requestPaint()
  }

  // Start a new maze: all wall, the clock box reserved, nothing visited.
  function reset() {
    var n = bw * bh
    grid = new Uint8Array(n)
    onPath = new Uint8Array(n)
    visited = new Uint8Array(rows * cols)
    stack = []
    pathList = []
    pathDrawn = 0
    holdTicks = 0
    pix = new Uint8Array(n)
    changes = []
    paintAll = true
    drawClock(true)
    // Cells that touch the clock box are not part of the maze.
    for (var cy = 0; cy < rows; cy++) for (var cx = 0; cx < cols; cx++) {
      var bx = cx * 2 + 1, by = cy * 2 + 1
      if (grid[gi(bx, by)] === 2) visited[cy * cols + cx] = 2
    }
    // Start in the top left cell, finish in the bottom right one.
    var s = 0
    visited[s] = 1
    stack.push(s)
    var sx = 1, sy = 1
    grid[gi(sx, sy)] = 1
    // Every block that is still a wall.
    for (var wy = 0; wy < bh; wy++) for (var wx = 0; wx < bw; wx++)
      if (grid[gi(wx, wy)] === 0) paint(wx, wy, 1)
    phase = "carve"
    painter.opacity = 1
    drawClock(false)
    painter.requestPaint()
  }

  // Carve a few cells with the depth first search.
  function carve() {
    for (var i = 0; i < carvePerStep; i++) {
      if (stack.length === 0) { startSolve(); return }
      var cur = stack[stack.length - 1]
      var cx = cur % cols, cy = Math.floor(cur / cols)
      var options = []
      if (cx > 0 && visited[cur - 1] === 0) options.push([-1, 0])
      if (cx < cols - 1 && visited[cur + 1] === 0) options.push([1, 0])
      if (cy > 0 && visited[cur - cols] === 0) options.push([0, -1])
      if (cy < rows - 1 && visited[cur + cols] === 0) options.push([0, 1])
      if (options.length === 0) { stack.pop(); continue }
      var pick = options[Math.floor(Math.random() * options.length)]
      var nx = cx + pick[0], ny = cy + pick[1]
      var bx = cx * 2 + 1, by = cy * 2 + 1
      // Open the wall between, and the new cell.
      grid[gi(bx + pick[0], by + pick[1])] = 1
      grid[gi(nx * 2 + 1, ny * 2 + 1)] = 1
      paint(bx + pick[0], by + pick[1], 0)
      paint(nx * 2 + 1, ny * 2 + 1, 0)
      visited[ny * cols + nx] = 1
      stack.push(ny * cols + nx)
    }
    painter.requestPaint()
  }

  // Search for the way from the start to the finish, depth first, remembering
  // every block the search visits so it can be shown, then the way it found.
  function startSolve() {
    var sx = 1, sy = 1
    var endCell = (rows - 1) * cols + (cols - 1)
    var goal = gi((endCell % cols) * 2 + 1, Math.floor(endCell / cols) * 2 + 1)
    var n = bw * bh
    var from = new Int32Array(n).fill(-1)
    var order = []
    var stk = [gi(sx, sy)]
    from[gi(sx, sy)] = gi(sx, sy)
    while (stk.length > 0) {
      var cur = stk.pop()
      order.push(cur)
      if (cur === goal) break
      var x = cur % bw, y = Math.floor(cur / bw)
      var nb = [[x + 1, y], [x - 1, y], [x, y + 1], [x, y - 1]]
      for (var i = 0; i < 4; i++) {
        var px = nb[i][0], py = nb[i][1]
        if (px < 0 || py < 0 || px >= bw || py >= bh) continue
        var id = gi(px, py)
        if (grid[id] !== 1 || from[id] >= 0) continue
        from[id] = cur
        stk.push(id)
      }
    }
    var way = []
    if (from[goal] >= 0) {
      var at = goal
      while (at !== gi(sx, sy)) { way.push(at); at = from[at] }
      way.push(gi(sx, sy))
      way.reverse()
    }
    pathList = order
    solution = way
    pathDrawn = 0
    phase = "solve"
  }

  function solve() {
    for (var i = 0; i < solvePerStep && pathDrawn < pathList.length; i++) {
      var id = pathList[pathDrawn++]
      paint(id % bw, Math.floor(id / bw), 2)
    }
    if (pathDrawn >= pathList.length) {
      // The way it found, over the search.
      for (var j = 0; j < solution.length; j++)
        paint(solution[j] % bw, Math.floor(solution[j] / bw), 3)
      phase = "hold"
      holdTicks = 0
    }
    painter.requestPaint()
  }

  function tick() {
    if (phase === "carve") carve()
    else if (phase === "solve") solve()
    else if (phase === "hold") {
      if (++holdTicks >= holdSeconds * stepsPerSecond) { phase = "fade"; fadeOut.restart() }
    }
  }

  Rectangle { anchors.fill: parent; color: Color.background }

  Timer {
    interval: Math.round(1000 / Math.max(1, lock.stepsPerSecond))
    repeat: true
    running: lock.animating && lock.phase !== "fade"
    onTriggered: lock.tick()
  }

  SequentialAnimation {
    id: fadeOut
    NumberAnimation { target: painter; property: "opacity"; to: 0; duration: lock.fadeDuration }
    ScriptAction { script: lock.reset() }
  }

  // The maze, flat blocks with hard edges. Every block of one color is a
  // rectangle in a single path, so a paint is only a handful of fills.
  Canvas {
    id: painter
    anchors.fill: parent
    renderTarget: Canvas.FramebufferObject
    renderStrategy: Canvas.Threaded
    onPaint: {
      var ctx = getContext("2d")
      var src = lock.pix
      if (src.length === 0) return
      var cols = lock.bw
      var b = lock.block
      var ox = Math.round(lock.offsetX)
      var oy = Math.round(lock.offsetY)
      // Which blocks to draw: all of them after a reset, otherwise the ones that
      // changed. The canvas keeps what was drawn before.
      var list
      if (lock.paintAll) {
        lock.paintAll = false
        ctx.clearRect(0, 0, width, height)
        list = []
        for (var k = 0; k < src.length; k++) if (src[k] !== 0) list.push(k)
      } else {
        list = lock.changes
      }
      lock.changes = []
      // Sort the blocks into one list per color, drawn as one path each.
      var groups = [[], [], [], [], [], []]
      for (var i = 0; i < list.length; i++) {
        var id = list[i]
        var ci = src[id]
        var x = ox + (id % cols) * b
        var y = oy + Math.floor(id / cols) * b
        groups[ci].push(x, y)
      }
      // Color 0 is the background, drawn over a block that was cleared. Painting it
      // as one path with the rest is much cheaper than clearing block by block.
      for (var c = 0; c < groups.length; c++) {
        var g = groups[c]
        if (g.length === 0) continue
        ctx.fillStyle = c === 0 ? Color.background : lock.palette[c]
        ctx.beginPath()
        for (var j = 0; j < g.length; j += 2) ctx.rect(g[j], g[j + 1], b, b)
        ctx.fill()
      }
    }
  }
  onBwChanged: Qt.callLater(reset)
  onBhChanged: Qt.callLater(reset)
  onWidthChanged: Qt.callLater(reset)
  onHeightChanged: Qt.callLater(reset)

  // The clock, redrawn when the minute changes.
  onTimeTextChanged: Qt.callLater(function() { if (lock.grid.length > 0) lock.drawClock(false) })

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: { lock.wakeRequested(); lock.forcePasswordFocus() }
    onPositionChanged: lock.wakeRequested()
  }

  PasswordField {
    id: field
    lock: lock
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
    anchors.verticalCenterOffset: Math.round(lock.height * 0.34)
    width: 380
    height: 56
    radius: 28
    showLockGlyph: false
    color: lock.withAlpha(Color.lock.background, 0.8)
    placeholder: lock.greeting() + ", " + lock.displayName
  }

  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 6
    opacity: lock.snapshotMode ? 0 : 1
    text: lock.failedAttempts > 0
      ? lock.tr(lock.failedAttempts === 1 ? "1 failed attempt" : "%1 failed attempts").arg(lock.failedAttempts)
      : (lock.fingerprintConfigured ? lock.fingerprintHint(lock.tr("Touch the sensor or press Enter")) : lock.tr("Press Enter to unlock"))
    textFormat: Text.PlainText
    color: lock.failedAttempts > 0 ? Color.lock.textError : lock.withAlpha(Color.lock.text, 0.7)
    font.family: Style.font.family
    font.pixelSize: Style.font.bodySmall
    font.letterSpacing: 2
  }
}
