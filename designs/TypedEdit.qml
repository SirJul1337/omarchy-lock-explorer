import QtQuick
import "Typing.js" as Typing

// A multi-line TextEdit that only the keyboard changes, for the code editors.
//
// The same reason as TypedInput: an editable TextEdit pastes on Ctrl+V,
// Shift+Insert, a middle click and a drop, and every one of those reads the
// whole foreign clipboard offer on the shell's main thread, with no size cap
// and no deadline. A read-only TextEdit does none of them. This one stays
// read-only for its lifetime and edits through insert() and remove() from
// its own key handler: typing, Backspace and Delete (by word with Ctrl),
// Return keeping the line's indentation, Tab, Ctrl+X, and Ctrl+Z / Ctrl+Y
// for undo and redo. Cursor movement, selection by mouse and keyboard, Copy
// and Select all are TextEdit's own. There is no paste and no input-method
// composition.
TextEdit {
  id: edit

  // A type that owns its Keys.onPressed sets this false and calls editKey()
  // itself.
  property bool typing: true
  // What Tab puts in.
  property string tabText: "  "

  readOnly: true
  selectByKeyboard: true
  selectByMouse: true

  // Qt draws the cursor of editable text only, so this one is drawn here.
  cursorVisible: activeFocus
  cursorDelegate: Rectangle {
    width: 2
    color: edit.color
    visible: edit.cursorVisible
    SequentialAnimation on opacity {
      running: edit.cursorVisible
      loops: Animation.Infinite
      PropertyAction { value: 1 }
      PauseAnimation { duration: 530 }
      PropertyAction { value: 0 }
      PauseAnimation { duration: 530 }
    }
  }

  // Replaces [start, end) with `text` and puts the cursor after it.
  function replaceSpan(start, end, text) {
    if (end > start) edit.remove(start, end)
    if (text.length > 0) edit.insert(start, text)
    edit.cursorPosition = start + text.length
  }

  // The span a key replaces: the selection, or the cursor.
  function span() {
    return edit.selectionEnd > edit.selectionStart
      ? { start: edit.selectionStart, end: edit.selectionEnd }
      : { start: edit.cursorPosition, end: edit.cursorPosition }
  }

  // Applies the key to the text when it is an editing key, and says so.
  function editKey(event) {
    if (event.accepted) return false
    var ctrl = (event.modifiers & Qt.ControlModifier) !== 0
    var shift = (event.modifiers & Qt.ShiftModifier) !== 0
    if (ctrl && event.key === Qt.Key_Z && !shift) { edit.undo(); event.accepted = true; return true }
    if (ctrl && (event.key === Qt.Key_Y || (event.key === Qt.Key_Z && shift))) { edit.redo(); event.accepted = true; return true }
    if (ctrl && event.key === Qt.Key_X) {
      if (edit.selectionEnd > edit.selectionStart) {
        edit.copy()
        edit.replaceSpan(edit.selectionStart, edit.selectionEnd, "")
      }
      event.accepted = true
      return true
    }
    if (!ctrl && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
      var s = edit.span()
      var t = edit.text
      var lineStart = t.lastIndexOf("\n", s.start - 1) + 1
      var indent = ""
      for (var i = lineStart; i < s.start && (t.charAt(i) === " " || t.charAt(i) === "\t"); i++) indent += t.charAt(i)
      edit.replaceSpan(s.start, s.end, "\n" + indent)
      event.accepted = true
      return true
    }
    if (!ctrl && event.key === Qt.Key_Tab) {
      var tab = edit.span()
      edit.replaceSpan(tab.start, tab.end, edit.tabText)
      event.accepted = true
      return true
    }
    var op = Typing.edit({
      text: edit.text,
      cursor: edit.cursorPosition,
      selectionStart: edit.selectionStart,
      selectionEnd: edit.selectionEnd,
      maximumLength: 0
    }, { key: event.key, text: event.text, modifiers: event.modifiers })
    if (!op) return false
    edit.replaceSpan(op.start, op.end, op.insert)
    event.accepted = true
    return true
  }

  Keys.onPressed: function(event) {
    if (edit.typing) edit.editKey(event)
  }
}
