import QtQuick
import qs.Commons

// The time in words: a grid of letters that lights up "IT IS HALF PAST TEN".
// Four dots in the corners count the minutes between the five-minute marks.
// The idea is the one in the "Word Clock" macOS screensavers; the grid and the
// code here are new. It changes once a minute, so it costs next to nothing.
//
// The words are English. The grid is a layout, not text to translate, so it is
// not in Strings.js; another language needs its own grid and word table.
DesignBase {
  id: lock
  inputItem: field.input
  shakeOnFail: true

  // ======================================================================
  // Settings. Change a number and save: the design reloads.
  // ======================================================================

  // ---- Layout ---------------------------------------------------------
  // How much of the screen's width the grid takes up (0..1). It is also kept
  // to about half the screen's height.
  property real gridWidthShare: 0.5
  // Where the middle of the grid sits down the screen (0 top, 1 bottom).
  property real gridVerticalPosition: 0.4
  // Letter size as a share of one grid cell.
  property real letterSize: 0.62
  // Space around the grid for the minute dots, in cells.
  property real dotMargin: 0.9

  // ---- Colors and fading ----------------------------------------------
  // Letters that are part of the time, and the rest of them.
  property color litColor: Color.lock.text
  property color dimColor: Color.lock.text
  property real litOpacity: 1.0
  property real dimOpacity: 0.10
  // How long a letter takes to light or go dark, in milliseconds.
  property int fadeDuration: 700
  // The four minute dots (0..4 of them are lit).
  property bool showMinuteDots: true
  property color dotColor: Color.lock.borderActive
  property real dotOpacityOff: 0.15

  // ---- Grid -----------------------------------------------------------
  // 11 letters by 10 rows. The letters that are not words are filler: change
  // them freely. The words below point at cells of this grid, so keep the
  // words where they are.
  readonly property var rows: [
    "ITLISASAMPM",
    "ACQUARTERDC",
    "TWENTYFIVEX",
    "HALFBTENFTO",
    "PASTERUNINE",
    "ONESIXTHREE",
    "FOURFIVETWO",
    "EIGHTELEVEN",
    "SEVENTWELVE",
    "TENSEOCLOCK"
  ]
  // Each word: row, first column, length.
  readonly property var words: ({
    "IT": [0, 0, 2], "IS": [0, 3, 2], "A": [1, 0, 1], "QUARTER": [1, 2, 7],
    "TWENTY": [2, 0, 6], "FIVE": [2, 6, 4], "HALF": [3, 0, 4], "TEN": [3, 5, 3],
    "TO": [3, 9, 2], "PAST": [4, 0, 4], "OCLOCK": [9, 5, 6],
    "H1": [5, 0, 3], "H2": [6, 8, 3], "H3": [5, 6, 5], "H4": [6, 0, 4],
    "H5": [6, 4, 4], "H6": [5, 3, 3], "H7": [8, 0, 5], "H8": [7, 0, 5],
    "H9": [4, 7, 4], "H10": [9, 0, 3], "H11": [7, 5, 6], "H12": [8, 5, 6]
  })
  // The words lit for each five minutes past the hour (0 is on the hour).
  // "NEXT" means the hour that is coming, used after the half hour.
  readonly property var minuteWords: [
    ["OCLOCK"], ["FIVE", "PAST"], ["TEN", "PAST"], ["A", "QUARTER", "PAST"],
    ["TWENTY", "PAST"], ["TWENTY", "FIVE", "PAST"], ["HALF", "PAST"],
    ["TWENTY", "FIVE", "TO", "NEXT"], ["TWENTY", "TO", "NEXT"], ["A", "QUARTER", "TO", "NEXT"],
    ["TEN", "TO", "NEXT"], ["FIVE", "TO", "NEXT"]
  ]

  // The time as a short key, so the grid is worked out again only when the
  // words or the dots change, not every second.
  readonly property string key: now.getHours() + ":" + now.getMinutes()
  // One entry per cell, row by row: true if its letter is lit.
  readonly property var lit: litCells(key)
  // How many dots are lit, 0 to 4.
  readonly property int dotsLit: now.getMinutes() % 5

  function litCells(timeKey) {
    var parts = timeKey.split(":")
    var hour = parseInt(parts[0])
    var minute = parseInt(parts[1])
    var bucket = Math.floor(minute / 5)
    var list = ["IT", "IS"]
    var spec = minuteWords[bucket]
    var next = bucket >= 7
    for (var i = 0; i < spec.length; i++) if (spec[i] !== "NEXT") list.push(spec[i])
    var h = (hour + (next ? 1 : 0)) % 12
    list.push("H" + (h === 0 ? 12 : h))

    var cells = []
    for (var c = 0; c < 110; c++) cells.push(false)
    for (var w = 0; w < list.length; w++) {
      var at = words[list[w]]
      for (var k = 0; k < at[2]; k++) cells[at[0] * 11 + at[1] + k] = true
    }
    return cells
  }

  readonly property real cell: Math.min(lock.width * gridWidthShare / 11, lock.height * 0.5 / 10)

  Rectangle { anchors.fill: parent; color: Color.background }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: { lock.wakeRequested(); lock.forcePasswordFocus() }
    onPositionChanged: lock.wakeRequested()
  }

  Item {
    id: grid
    width: lock.cell * 11
    height: lock.cell * 10
    x: (lock.width - width) / 2
    y: lock.height * lock.gridVerticalPosition - height / 2
    opacity: lock.snapshotMode ? 0 : 1

    Repeater {
      model: 110
      Text {
        required property int index
        readonly property bool on: lock.lit[index]
        x: (index % 11) * lock.cell
        y: Math.floor(index / 11) * lock.cell
        width: lock.cell
        height: lock.cell
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: lock.rows[Math.floor(index / 11)].charAt(index % 11)
        color: on ? lock.litColor : lock.dimColor
        opacity: on ? lock.litOpacity : lock.dimOpacity
        font.family: Style.font.family
        font.pixelSize: Math.round(lock.cell * lock.letterSize)
        font.weight: Font.Medium
        Behavior on opacity { NumberAnimation { duration: lock.fadeDuration; easing.type: Easing.InOutQuad } }
      }
    }

    // The minute dots, one in each corner, lit in turn clockwise.
    Repeater {
      model: lock.showMinuteDots ? 4 : 0
      Rectangle {
        required property int index
        width: Math.max(5, lock.cell * 0.16)
        height: width
        radius: width / 2
        color: lock.dotColor
        opacity: index < lock.dotsLit ? 1 : lock.dotOpacityOff
        x: (index === 0 || index === 3 ? -lock.dotMargin * lock.cell * 0.5 : grid.width + lock.dotMargin * lock.cell * 0.5) - width / 2
        y: (index < 2 ? -lock.dotMargin * lock.cell * 0.5 : grid.height + lock.dotMargin * lock.cell * 0.5) - height / 2
        Behavior on opacity { NumberAnimation { duration: lock.fadeDuration } }
      }
    }
  }

  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    y: grid.y + grid.height + lock.cell * 1.1
    opacity: lock.snapshotMode ? 0 : 1
    text: lock.date("dddd, d MMMM")
    color: lock.withAlpha(Color.lock.text, 0.7)
    font.family: Style.font.family
    font.pixelSize: Style.font.heading
    font.letterSpacing: 2
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
    color: lock.withAlpha(Color.lock.background, 0.55)
    placeholder: lock.greeting() + ", " + lock.displayName
  }

  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 40
    opacity: lock.snapshotMode ? 0 : 1
    text: lock.failedAttempts > 0
      ? lock.tr(lock.failedAttempts === 1 ? "1 failed attempt" : "%1 failed attempts").arg(lock.failedAttempts)
      : (lock.fingerprintConfigured ? lock.fingerprintHint(lock.tr("Touch the sensor or press Enter")) : lock.tr("Press Enter to unlock"))
    textFormat: Text.PlainText
    color: lock.failedAttempts > 0 ? Color.lock.textError : lock.withAlpha(Color.lock.text, 0.55)
    font.family: Style.font.family
    font.pixelSize: Style.font.bodySmall
    font.letterSpacing: 2
  }
}
