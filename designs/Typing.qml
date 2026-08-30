import QtQuick

// Designs only see passwordText, a string that changes. This turns it into the
// events you actually want to draw with: a key went in, a key came out, the
// field was emptied, and how fast the typing is going.
//
//   Typing {
//     lock: lock
//     onTyped: function(index) { splash(index) }
//     onCleared: calmDown()
//   }
//
// An Item rather than a QtObject on purpose: the shell only picks up
// Item derived files from a plugin directory, a QtObject here is invisible to
// the designs next to it.
Item {
  id: typing

  property var lock: null
  readonly property string text: lock ? lock.passwordText : ""

  visible: false
  width: 0
  height: 0

  // Keys per second over the last few strokes, decaying towards zero once the
  // typing stops. Handy for designs that get busier the faster you go.
  property real cadence: 0
  property real lastAt: 0
  property int previous: 0

  signal typed(int index)
  signal deleted(int index)
  signal cleared()

  Timer {
    interval: 250
    repeat: true
    running: typing.cadence > 0.01
    onTriggered: typing.cadence = typing.cadence * 0.75
  }

  onTextChanged: {
    var length = text.length
    if (length === previous) return

    var now = Date.now()
    if (length > previous) {
      if (lastAt > 0) {
        var gap = Math.max(1, now - lastAt)
        // Blend rather than jump, one slow keystroke should not zero it out.
        cadence = cadence * 0.4 + (1000 / gap) * 0.6
      } else {
        cadence = 1
      }
      lastAt = now
      for (var i = previous; i < length; i++) typed(i)
    } else if (length === 0) {
      lastAt = 0
      cleared()
    } else {
      for (var j = previous - 1; j >= length; j--) deleted(j)
    }

    previous = length
  }
}
