import QtQuick
import qs.Commons

// A clock made of clocks: 24 small analog clocks whose hands line up to draw
// the digits of the time, and turn to the next ones when the minute changes.
// The idea is the one in the "MultiClock" macOS screensaver; the digit shapes
// and the code here are new. Nothing moves between minutes, so it costs next to
// nothing.
DesignBase {
  id: lock
  inputItem: field.input
  shakeOnFail: true

  // ======================================================================
  // Settings. Change a number and save: the design reloads.
  // ======================================================================

  // ---- Layout ---------------------------------------------------------
  // How much of the screen's width the four digits take up (0..1).
  property real gridWidthShare: 0.7
  // Where the middle of the digits sits down the screen (0 top, 1 bottom).
  property real gridVerticalPosition: 0.36
  // Space between digits, and around the colon, in clock widths.
  property real digitGap: 0.35
  property real colonGap: 0.9

  // ---- Clocks ---------------------------------------------------------
  // How long a hand is, as a share of the clock's width (0.5 touches the next
  // clock, which joins the strokes of a digit into lines).
  property real handLength: 0.5
  // How thick a hand is, as a share of the clock's width.
  property real handThickness: 0.075
  // Draw a faint ring around each clock.
  property bool showFace: true
  property real faceOpacity: 0.16
  // The angle both hands rest at on a clock that is not part of a digit, in
  // degrees clockwise from pointing right (90 is down, 135 down and right).
  property real idleAngle: 135
  // How long the hands take to turn to the next minute, in milliseconds.
  property int turnDuration: 900

  // ---- Colors ---------------------------------------------------------
  property color handColor: Color.lock.text
  property color faceColor: Color.lock.text
  // The two dots of the colon.
  property color colonColor: Color.lock.borderActive

  // ---- Digits ---------------------------------------------------------
  // Each digit is 2 clocks wide and 3 tall. A cell is two letters, one per
  // hand, saying which way the hand points (U up, D down, L left, R right);
  // "--" means it is not part of the digit. Cells run left to right, top to
  // bottom. Edit these to change how a digit is drawn.
  readonly property var glyphs: ({
    "0": ["RD", "LD", "UD", "UD", "RU", "LU"],
    "1": ["--", "DD", "--", "UD", "--", "UU"],
    "2": ["RR", "LD", "RD", "UL", "UR", "LL"],
    "3": ["RR", "LD", "RR", "UD", "RR", "UL"],
    "4": ["DD", "DD", "UR", "UD", "--", "UU"],
    "5": ["DR", "LL", "UR", "LD", "RR", "LU"],
    "6": ["DR", "LL", "UD", "LD", "UR", "LU"],
    "7": ["RR", "LD", "--", "UD", "--", "UU"],
    "8": ["RD", "LD", "UR", "UL", "RU", "LU"],
    "9": ["RD", "LD", "UR", "LD", "RR", "LU"]
  })

  // The four digits of the time, from the clock format (24-hour unless the
  // 12-hour setting is on).
  readonly property string digits: lock.clock("HH:mm").replace(/\D/g, "").padStart(4, "0").slice(0, 4)
  // Width of one clock, so the whole grid fits gridWidthShare of the screen.
  readonly property real cell: Math.min(lock.width * gridWidthShare / (8 + 3 * digitGap + colonGap), lock.height * 0.14)

  function angle(letter) {
    return letter === "R" ? 0 : letter === "D" ? 90 : letter === "L" ? 180 : letter === "U" ? 270 : idleAngle
  }

  Rectangle { anchors.fill: parent; color: Color.background }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: { lock.wakeRequested(); lock.forcePasswordFocus() }
    onPositionChanged: lock.wakeRequested()
  }

  // The digits.
  Item {
    id: wall
    width: lock.cell * (8 + 3 * lock.digitGap + lock.colonGap)
    height: lock.cell * 3
    x: (lock.width - width) / 2
    y: lock.height * lock.gridVerticalPosition - height / 2
    opacity: lock.snapshotMode ? 0 : 1

    Repeater {
      model: 24
      Item {
        id: clock
        required property int index
        readonly property int digit: Math.floor(index / 6)
        readonly property int slot: index % 6
        readonly property string glyph: (lock.glyphs[lock.digits.charAt(digit)] || lock.glyphs["0"])[slot]

        width: lock.cell
        height: lock.cell
        x: ((digit * 2 + slot % 2) + digit * lock.digitGap + (digit >= 2 ? lock.colonGap : 0)) * lock.cell
        y: Math.floor(slot / 2) * lock.cell

        Rectangle {
          anchors.centerIn: parent
          width: parent.width * 0.92
          height: width
          radius: width / 2
          color: "transparent"
          border.width: 1
          border.color: lock.faceColor
          opacity: lock.faceOpacity
          visible: lock.showFace
        }

        Repeater {
          model: 2
          Rectangle {
            required property int index
            readonly property real target: lock.angle(clock.glyph.charAt(index))
            x: clock.width / 2
            y: clock.height / 2 - height / 2
            width: clock.width * lock.handLength
            height: Math.max(1.5, clock.width * lock.handThickness)
            radius: height / 2
            color: lock.handColor
            transformOrigin: Item.Left
            rotation: target
            antialiasing: true
            Behavior on rotation {
              RotationAnimation { duration: lock.turnDuration; direction: RotationAnimation.Shortest; easing.type: Easing.InOutCubic }
            }
          }
        }
      }
    }

    // The colon between the hours and the minutes.
    Repeater {
      model: 2
      Rectangle {
        required property int index
        width: Math.max(4, lock.cell * 0.14)
        height: width
        radius: width / 2
        color: lock.colonColor
        x: (4 + 1.5 * lock.digitGap + lock.colonGap / 2) * lock.cell - width / 2
        y: lock.cell * (index === 0 ? 1.0 : 2.0) - height / 2
      }
    }
  }

  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    y: wall.y + wall.height + lock.cell * 0.4
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
    anchors.verticalCenterOffset: Math.round(lock.height * 0.28)
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
