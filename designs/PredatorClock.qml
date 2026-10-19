import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.Commons

// A clock in glyphs, like the alien countdown in the Predator films: four
// figures, each a little body of bars, some lit and some dark, glowing red. The
// idea is the "Predator" macOS screensaver (https://github.com/vpeschenkov/Predator);
// the glyph design and the code here are new.
//
// How to read it. Each figure is one digit, hours then minutes. It has nine
// bars: a top tick (T), two shoulder bars (L, R), the four sides of a diamond
// (UL, UR, LL, LR) and two legs (B1, B2). For a digit d:
//
//   diamond sides   binary, UL = 8, UR = 4, LL = 2, LR = 1
//   T               d is 5 or more
//   L               d is 0, 3, 6 or 9        (d mod 3 is 0)
//   R               d is 1, 4 or 7           (d mod 3 is 1)
//   B1              d is even
//   B2              d is odd
//
// so 0 has only the shoulder and the left leg, and 7 has the three diamond sides
// UR, LL and LR, the top tick, the right shoulder and the right leg.
//
// Only the lit bars change, once a minute, so it costs next to nothing. Every
// key you type makes the lit bars flare.
DesignBase {
  id: lock
  inputItem: field.input
  shakeOnFail: true

  // ======================================================================
  // Settings. Change a number and save: the design reloads.
  // ======================================================================

  // ---- Layout ---------------------------------------------------------
  // How big the figures are: the row of four takes rowWidthShare of the
  // screen's width (as in the film), but a figure is never taller than
  // glyphHeightShare of the screen's height.
  property real rowWidthShare: 0.61
  property real glyphHeightShare: 0.42
  // Where the middle of the clock sits (0 to 1 across and down).
  property real clockX: 0.5
  property real clockY: 0.494
  // Space between figures, and the extra space between the hours and the minutes,
  // in figure widths.
  property real glyphGap: 0.11
  property real pairGap: 0.11
  // Show the seconds as two more, smaller figures.
  property bool showSeconds: false
  property real secondsScale: 0.55

  // ---- Bars -----------------------------------------------------------
  // How thick a bar is, as a share of a figure's width. The ends are pointed.
  property real barThickness: 0.0887
  // How long the pointed ends are, as a share of the bar's thickness. 0.5 makes
  // right angle points; smaller is blunter, 0 is square.
  property real tipDepth: 0.5
  // Draw the outline round the bars that are off, as in the film.
  property bool showOutline: true
  // The soft glow round the lit bars: how far it spreads (0 to 1, about up to
  // the bar's own thickness; 0 turns it off) and how bright it is. It is a blur
  // of the lit bars, made once a minute when they change.
  property real glowSize: 0.5
  property real glowOpacity: 0.9
  // How bright the bars that are off are (0 hides them completely).
  property real unlitOpacity: 1.0

  // ---- Colors ---------------------------------------------------------
  // Lit bars, the dark bars and their outline. These are the film's red. To
  // follow the theme instead, set litColor to Color.lock.borderActive or
  // Color.lock.textError and unlitColor to Qt.darker(litColor, 2.5).
  property color litColor: Qt.rgba(1, 0.05, 0.05, 1)
  property color unlitColor: Qt.rgba(0.36, 0.03, 0.024, 1)
  property color outlineColor: Qt.rgba(0.73, 0.03, 0.02, 1)

  // ---- Typing ---------------------------------------------------------
  // How much brighter and bigger the glow gets for a key (0 for none), and how
  // long it takes to settle, in milliseconds.
  property real flare: 0.6
  property int flareDuration: 450

  // ---- Driven by the design; do not set --------------------------------
  readonly property string digits: lock.clock("HH:mm").replace(/\D/g, "").padStart(4, "0").slice(0, 4)
  readonly property string secs: ("0" + lock.now.getSeconds()).slice(-2)
  readonly property real figureH: lock.height * glyphHeightShare
  // The row is four figures plus gaps (and the seconds, if shown). The size is
  // cut back if it would not fit across the screen.
  readonly property real rowUnits: 4 * 141 + 141 * (2 * glyphGap + pairGap) + (showSeconds ? 282 * secondsScale + 141 * (pairGap + glyphGap) : 0)
  // One unit in pixels (a figure is 141 units wide, 227 tall).
  readonly property real unit: Math.min(figureH / 227, lock.width * rowWidthShare / rowUnits)
  // 0..1: how much a key has flared the lit bars lately.
  property real energy: 0

  // The nine bars, in units where a figure is 141 wide and 227 tall (the
  // film's proportions), in the order T L R UL UR LL LR B1 B2. The straight ones
  // are [centre x, centre y, length, angle in degrees]; the diagonals are in
  // `diagonals` below.
  readonly property var bars: [
    [70, 30.5, 61, 90], [30.5, 58, 61, 0], [110.5, 58, 61, 0],
    null, null, null, null,
    [70, 183.5, 61, 90], [89, 195.5, 61, 90]
  ]

  // The diagonal bars UL UR LL LR (indices 3 to 6) by their two far corners:
  // [inner x, inner y, outer x, outer y], measured off the film's glyphs. Each
  // end is cut square, flat across and flat up and down, cornerSize long.
  readonly property var diagonals: [null, null, null,
    [55, 69, 11, 113], [87, 69, 131, 113], [55, 161, 11, 116], [88, 161, 132, 117], null, null]
  // The square notch at each end of a diagonal bar, in the same units.
  readonly property real cornerSize: 9.5

  // Which bars are lit for a digit, in the same order as `bars`.
  function code(d) {
    return [d >= 5, d % 3 === 0, d % 3 === 1, (d & 8) !== 0, (d & 4) !== 0, (d & 2) !== 0, (d & 1) !== 0, d % 2 === 0, d % 2 === 1]
  }

  Rectangle { anchors.fill: parent; color: Color.background }

  NumberAnimation {
    id: settle
    target: lock
    property: "energy"
    from: 1
    to: 0
    duration: lock.flareDuration
    easing.type: Easing.OutCubic
  }
  Typing {
    id: typing
    lock: lock
    onTyped: if (lock.flare > 0) settle.restart()
    onDeleted: if (lock.flare > 0) settle.restart()
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: { lock.wakeRequested(); lock.forcePasswordFocus() }
    onPositionChanged: lock.wakeRequested()
  }

  // A bar with pointed ends, as a closed polygon given by its points.
  component Hex: Shape {
    property var points: []
    property color fill: "red"
    property color stroke: "transparent"
    property real strokeW: 0
    ShapePath {
      fillColor: fill
      strokeColor: stroke
      strokeWidth: strokeW
      PathPolyline { path: points }
    }
  }

  // The corners of bar `i` of a figure, in pixels, for one unit `u` and bar
  // thickness `t`. Straight bars get pointed ends; diagonal bars are cut square
  // at both ends, as in the film (see `diagonals`). `grow` is unused for now.
  function barPoints(i, u, t, grow) {
    var out = []
    var dg = diagonals[i]
    if (dg) {
      var ix = dg[0] * u, iy = dg[1] * u, ox = dg[2] * u, oy = dg[3] * u
      var c = cornerSize * u
      var dx = ox > ix ? 1 : -1
      var dy = oy > iy ? 1 : -1
      var pts = [[ix + dx * c, iy], [ix, iy], [ix, iy + dy * c], [ox - dx * c, oy], [ox, oy], [ox, oy - dy * c]]
      for (var k = 0; k < pts.length; k++) out.push(Qt.point(pts[k][0], pts[k][1]))
      out.push(out[0])
      return out
    }
    var b = bars[i]
    var cx = b[0] * u, cy = b[1] * u, l = b[2] * u + t * grow, th = t * (1 + grow)
    var a = b[3] * Math.PI / 180
    var ca = Math.cos(a), sa = Math.sin(a)
    var d = th * lock.tipDepth
    var raw = [[-l / 2, 0], [-l / 2 + d, -th / 2], [l / 2 - d, -th / 2], [l / 2, 0], [l / 2 - d, th / 2], [-l / 2 + d, th / 2], [-l / 2, 0]]
    for (var j = 0; j < raw.length; j++)
      out.push(Qt.point(cx + raw[j][0] * ca - raw[j][1] * sa, cy + raw[j][0] * sa + raw[j][1] * ca))
    return out
  }

  // One figure.
  component Figure: Item {
    id: fig
    property int digit: 0
    property real scaleBy: 1
    // Only the lit bars, plain, as the source of the glow.
    property bool glowOnly: false
    readonly property real u: lock.unit * scaleBy
    readonly property var lit: lock.code(digit)
    width: 141 * u
    height: 227 * u

    Repeater {
      model: 9
      Item {
        id: bar
        required property int index
        readonly property bool on: fig.lit[index]
        readonly property var b: lock.bars[index]
        readonly property real thick: Math.max(3, 141 * fig.u * lock.barThickness)

        // The bar: bright if lit, dark with an outline if not.
        Hex {
          visible: !fig.glowOnly || bar.on
          points: lock.barPoints(bar.index, fig.u, bar.thick, 0)
          fill: bar.on ? lock.litColor : lock.unlitColor
          stroke: !fig.glowOnly && !bar.on && lock.showOutline ? lock.outlineColor : "transparent"
          strokeW: !fig.glowOnly && !bar.on && lock.showOutline ? Math.max(1, bar.thick * 0.1) : 0
          opacity: fig.glowOnly ? 1 : (bar.on ? Math.min(1, 0.92 + lock.energy * lock.flare) : lock.unlitOpacity)
        }
      }
    }
  }

  // The glow: the lit bars alone, blurred once and laid under the bars.
  Row {
    id: glowRow
    x: lock.width * lock.clockX - width / 2
    y: lock.height * lock.clockY - height / 2
    spacing: lock.glyphGap * 141 * lock.unit
    visible: false

    Figure { glowOnly: true; digit: parseInt(lock.digits.charAt(0)) }
    Figure { glowOnly: true; digit: parseInt(lock.digits.charAt(1)) }
    Item { width: Math.max(0, (lock.pairGap - lock.glyphGap) * 141 * lock.unit); height: 1 }
    Figure { glowOnly: true; digit: parseInt(lock.digits.charAt(2)) }
    Figure { glowOnly: true; digit: parseInt(lock.digits.charAt(3)) }
    Item { visible: lock.showSeconds; width: Math.max(0, (lock.pairGap - lock.glyphGap) * 141 * lock.unit); height: 1 }
    Figure { glowOnly: true; visible: lock.showSeconds; scaleBy: lock.secondsScale; digit: parseInt(lock.secs.charAt(0)); anchors.bottom: parent.bottom }
    Figure { glowOnly: true; visible: lock.showSeconds; scaleBy: lock.secondsScale; digit: parseInt(lock.secs.charAt(1)); anchors.bottom: parent.bottom }
  }

  MultiEffect {
    source: glowRow
    x: glowRow.x
    y: glowRow.y
    width: glowRow.width
    height: glowRow.height
    visible: lock.glowSize > 0 && !lock.snapshotMode
    autoPaddingEnabled: true
    blurEnabled: true
    blur: Math.min(1, lock.glowSize)
    blurMax: Math.max(4, Math.round(lock.unit * 141 * lock.barThickness * 1.2))
    brightness: 0.2
    opacity: Math.min(1, lock.glowOpacity * (1 + lock.energy * lock.flare))
  }

  Row {
    id: clockRow
    x: lock.width * lock.clockX - width / 2
    y: lock.height * lock.clockY - height / 2
    spacing: lock.glyphGap * 141 * lock.unit
    opacity: lock.snapshotMode ? 0 : 1

    Figure { digit: parseInt(lock.digits.charAt(0)) }
    Figure { digit: parseInt(lock.digits.charAt(1)) }
    Item { width: Math.max(0, (lock.pairGap - lock.glyphGap) * 141 * lock.unit); height: 1 }
    Figure { digit: parseInt(lock.digits.charAt(2)) }
    Figure { digit: parseInt(lock.digits.charAt(3)) }
    Item { visible: lock.showSeconds; width: Math.max(0, (lock.pairGap - lock.glyphGap) * 141 * lock.unit); height: 1 }
    Figure { visible: lock.showSeconds; scaleBy: lock.secondsScale; digit: parseInt(lock.secs.charAt(0)); anchors.bottom: parent.bottom }
    Figure { visible: lock.showSeconds; scaleBy: lock.secondsScale; digit: parseInt(lock.secs.charAt(1)); anchors.bottom: parent.bottom }
  }

  PasswordField {
    id: field
    lock: lock
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
    anchors.verticalCenterOffset: Math.round(lock.height * 0.34)
    width: 380
    height: 52
    radius: 26
    showLockGlyph: false
    color: lock.withAlpha(Color.lock.background, 0.85)
    placeholder: lock.greeting() + ", " + lock.displayName
  }

  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 24
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
