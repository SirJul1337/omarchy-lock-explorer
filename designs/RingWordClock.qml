import QtQuick
import qs.Commons

// The time in words on turning rings. Hours, minutes and seconds each have a
// ring of number words, set out like the spokes of a wheel. Every ring turns so
// that its current word lies on the same line, and the three of them read
// across as one sentence: "Nine forty-one and twenty seconds". The other
// words fan out around that line.
// The idea is the rotary mode of Simon Heys' Word Clock
// (https://www.simonheys.com/portfolio/wordclock); the code here is new.
// The rings turn a little every few seconds and sit still in between, so it
// costs next to nothing.
DesignBase {
  id: lock
  inputItem: field.input
  shakeOnFail: true

  // ======================================================================
  // Settings. Change a number and save: the design reloads.
  // ======================================================================

  // ---- Layout ---------------------------------------------------------
  // Where the middle of the rings sits, as a share of the screen (0 is the
  // left or top edge, 1 the right or bottom). At the left edge, halfway down,
  // only the half of the wheel that reads outward shows.
  property real centerX: 0.0
  property real centerY: 0.5
  // Text size as a share of the screen's height, and how much bigger the
  // current words are than the rest.
  property real fontSizeShare: 0.036
  property real currentScale: 1.35
  // The font. The default is the theme's; a plain sans such as "Helvetica" or
  // "Liberation Sans" looks closer to the original.
  property string fontFamily: Style.font.family
  // How far from the middle the sentence starts, as a share of the screen's
  // height. The rings start where each of the current words does, so they
  // slide as the words change length.
  property real ringStartShare: 0.2

  // ---- Which rings ----------------------------------------------------
  // The seconds ring. It moves in steps of secondsStep seconds (1 to 30), so
  // a bigger step means fewer turns and less work. 10 is calm.
  property bool showSeconds: true
  property int secondsStep: 10
  // Start the hour words with a capital, so the sentence begins like one:
  // "Nine forty-one and twenty seconds".
  property bool capitalizeHours: true
  // The words that join the sentence: "Nine forty-one AND twenty SECONDS".
  property string andWord: "and"
  property string secondsWord: "seconds"
  // The word shown on the seconds ring at 0 (which replaces "and ... seconds").
  property string zeroSecondsWord: "precisely"
  // The word shown on the minutes ring at 0.
  property string zeroMinutesWord: "o'clock"

  // ---- Fan ------------------------------------------------------------
  // How quickly words shrink with their distance from the current word (in
  // words), and the smallest they get (share of full size). 0 keeps every
  // word the same size.
  property real falloff: 0.0
  property real smallestScale: 0.45
  // How bright the words that are not current are (0..1). The current words
  // are always fully bright.
  property real otherOpacity: 0.25
  // The current words are bold.
  property bool boldCurrent: true

  // ---- Colors and motion ------------------------------------------------
  property color currentColor: Color.lock.text
  property color otherColor: Color.lock.text
  // How long a ring takes to turn to the next word, in milliseconds.
  property int turnDuration: 900

  // ---- Words ----------------------------------------------------------
  // English number words. Another language needs its own lists here.
  readonly property var small: ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine",
    "ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen"]
  readonly property var tens: ["", "", "twenty", "thirty", "forty", "fifty"]

  function numberWord(n) {
    if (n < 20) return small[n]
    var t = Math.floor(n / 10)
    var o = n % 10
    return tens[t] + (o ? "-" + small[o] : "")
  }

  // Hours run 1 to 12 with the 12-hour setting and 0 to 23 without it.
  readonly property var hourWords: {
    var list = []
    if (lock.twelveHour) for (var h = 1; h <= 12; h++) list.push(numberWord(h))
    else for (var d = 0; d < 24; d++) list.push(numberWord(d))
    if (capitalizeHours) list = list.map(function(w) { return w.charAt(0).toUpperCase() + w.slice(1) })
    return list
  }
  readonly property var minuteWords: {
    var list = []
    for (var m = 0; m < 60; m++) list.push(m === 0 ? zeroMinutesWord : (m < 10 ? "oh-" + small[m] : numberWord(m)))
    return list
  }
  readonly property var secondWords: {
    var list = []
    for (var s = 0; s < 60; s++) list.push(s === 0 ? zeroSecondsWord : numberWord(s))
    return list
  }

  // Which word of each ring is current.
  readonly property int hourIndex: lock.twelveHour ? ((now.getHours() % 12) || 12) - 1 : now.getHours()
  readonly property int minuteIndex: now.getMinutes()
  readonly property int secondIndex: Math.floor(now.getSeconds() / Math.max(1, secondsStep)) * Math.max(1, secondsStep)

  // ---- Driven by the design; do not set --------------------------------
  readonly property real fs: Math.max(12, Math.round(lock.height * fontSizeShare))
  readonly property string hourWord: hourWords[hourIndex]
  readonly property string minuteWord: minuteWords[minuteIndex]
  readonly property string secondWord: secondWords[secondIndex]
  // "and ... seconds" go with every seconds word but the one for 0.
  readonly property bool joined: showSeconds && secondIndex !== 0

  // How wide the current words are, set bold at their size, so the sentence
  // can be laid out and each ring started where its word does.
  TextMetrics { id: hourMetrics; text: lock.hourWord; font.family: lock.fontFamily; font.pixelSize: lock.fs * lock.currentScale; font.bold: lock.boldCurrent }
  TextMetrics { id: minuteMetrics; text: lock.minuteWord; font.family: lock.fontFamily; font.pixelSize: lock.fs * lock.currentScale; font.bold: lock.boldCurrent }
  TextMetrics { id: andMetrics; text: lock.andWord; font.family: lock.fontFamily; font.pixelSize: lock.fs * lock.currentScale; font.bold: lock.boldCurrent }
  TextMetrics { id: secondMetrics; text: lock.secondWord; font.family: lock.fontFamily; font.pixelSize: lock.fs * lock.currentScale; font.bold: lock.boldCurrent }
  TextMetrics { id: spaceMetrics; text: "n n"; font.family: lock.fontFamily; font.pixelSize: lock.fs * lock.currentScale; font.bold: lock.boldCurrent }
  TextMetrics { id: nMetrics; text: "nn"; font.family: lock.fontFamily; font.pixelSize: lock.fs * lock.currentScale; font.bold: lock.boldCurrent }
  // One space.
  readonly property real space: spaceMetrics.advanceWidth - nMetrics.advanceWidth

  // Where each word of the sentence starts, along the line from the middle.
  property real hoursStart: lock.height * ringStartShare
  readonly property real minutesStartTarget: hoursStart + hourMetrics.advanceWidth + space
  readonly property real andStartTarget: minutesStartTarget + minuteMetrics.advanceWidth + space
  readonly property real secondsStartTarget: joined ? andStartTarget + andMetrics.advanceWidth + space : andStartTarget
  readonly property real suffixStartTarget: secondsStartTarget + secondMetrics.advanceWidth + space
  // The rings slide to their new start rather than jumping.
  property real minutesStart: minutesStartTarget
  property real andStart: andStartTarget
  property real secondsStart: secondsStartTarget
  property real suffixStart: suffixStartTarget
  Behavior on minutesStart { NumberAnimation { duration: lock.turnDuration; easing.type: Easing.InOutCubic } }
  Behavior on andStart { NumberAnimation { duration: lock.turnDuration; easing.type: Easing.InOutCubic } }
  Behavior on secondsStart { NumberAnimation { duration: lock.turnDuration; easing.type: Easing.InOutCubic } }
  Behavior on suffixStart { NumberAnimation { duration: lock.turnDuration; easing.type: Easing.InOutCubic } }

  Rectangle { anchors.fill: parent; color: Color.background }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: { lock.wakeRequested(); lock.forcePasswordFocus() }
    onPositionChanged: lock.wakeRequested()
  }

  // One ring of words. Word i sits at angle i * 360 / count, reading outward
  // from `start`, and the whole ring is turned so the current word points right.
  component Ring: Item {
    id: ring
    property var words: []
    property int current: 0
    property real start: 0

    // The ring is an item at the middle of the wheel, so rotating it turns
    // every word about that point.
    width: 0
    height: 0
    rotation: -current * 360 / Math.max(1, words.length)
    Behavior on rotation { RotationAnimation { duration: lock.turnDuration; direction: RotationAnimation.Shortest; easing.type: Easing.InOutCubic } }

    Repeater {
      model: ring.words.length
      Item {
        id: spoke
        required property int index
        width: 0
        height: 0
        rotation: index * 360 / ring.words.length

        // Distance, in words, from the current one, going whichever way is shorter.
        readonly property real away: {
          var n = ring.words.length
          var d = Math.abs(index - ring.current)
          return Math.min(d, n - d)
        }
        readonly property bool isCurrent: away < 0.5

        Text {
          x: ring.start
          y: -height / 2
          transformOrigin: Item.Left
          text: ring.words[spoke.index]
          color: spoke.isCurrent ? lock.currentColor : lock.otherColor
          font.family: lock.fontFamily
          font.pixelSize: lock.fs
          font.bold: spoke.isCurrent && lock.boldCurrent
          scale: spoke.isCurrent ? lock.currentScale : Math.max(lock.smallestScale, 1 - lock.falloff * spoke.away)
          opacity: spoke.isCurrent ? 1 : lock.otherOpacity
          Behavior on scale { NumberAnimation { duration: lock.turnDuration } }
          Behavior on opacity { NumberAnimation { duration: lock.turnDuration } }
        }
      }
    }
  }

  // The wheel.
  Item {
    id: wheel
    x: lock.width * lock.centerX
    y: lock.height * lock.centerY
    opacity: lock.snapshotMode ? 0 : 1

    Ring { words: lock.hourWords; current: lock.hourIndex; start: lock.hoursStart }
    Ring { words: lock.minuteWords; current: lock.minuteIndex; start: lock.minutesStart }
    Ring { visible: lock.showSeconds; words: lock.secondWords; current: lock.secondIndex; start: lock.secondsStart }

    // The words that join the current ones into a sentence, on the same line.
    Text {
      visible: lock.joined
      x: lock.andStart
      y: -height / 2
      text: lock.andWord
      color: lock.currentColor
      font.family: lock.fontFamily
      font.pixelSize: lock.fs * lock.currentScale
      font.bold: lock.boldCurrent
    }
    Text {
      visible: lock.joined
      x: lock.suffixStart
      y: -height / 2
      text: lock.secondsWord
      color: lock.currentColor
      font.family: lock.fontFamily
      font.pixelSize: lock.fs * lock.currentScale
      font.bold: lock.boldCurrent
    }
  }

  Text {
    anchors.left: parent.left
    anchors.leftMargin: 48
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 40
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
    anchors.verticalCenterOffset: Math.round(lock.height * 0.36)
    width: 380
    height: 56
    radius: 28
    showLockGlyph: false
    color: lock.withAlpha(Color.lock.background, 0.7)
    placeholder: lock.greeting() + ", " + lock.displayName
  }

  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 12
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
