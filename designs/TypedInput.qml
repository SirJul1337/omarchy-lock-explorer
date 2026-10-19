import QtQuick
import "Typing.js" as Typing

// A TextInput that only the keyboard changes.
//
// Every writable TextInput subscribes to the clipboard, and on Qt up to
// 6.12.0 that subscription reads the whole foreign offer on the shell's main
// thread whenever any program on the desktop changes the clipboard: through
// a Wayland pipe with no size cap and no deadline, with the field unfocused
// and nothing pasted (QTBUG-149610). A read-only TextInput skips that
// handler, so this one is read-only for its lifetime and types through
// insert() and remove() from its own key handler instead. Movement,
// selection by mouse and keyboard, Copy, validators, maximumLength,
// echoMode, textEdited and accepted all still come from TextInput. Gone on
// purpose: Paste, Undo and input-method composition, since a read-only
// item takes no preedit.
TextInput {
  id: input

  // A type that owns its Keys.onPressed sets this false and calls editKey()
  // itself, at the point where a key is allowed to change the text.
  property bool typing: true

  readOnly: true

  // Qt drives the cursor of writable fields only, so this one is drawn here.
  cursorVisible: activeFocus
  cursorDelegate: Rectangle {
    width: 1
    color: input.color
    visible: input.cursorVisible
    SequentialAnimation on opacity {
      running: input.cursorVisible
      loops: Animation.Infinite
      PropertyAction { value: 1 }
      PauseAnimation { duration: 530 }
      PropertyAction { value: 0 }
      PauseAnimation { duration: 530 }
    }
  }

  // Applies the key to the text when it is an editing key, and says so.
  function editKey(event) {
    if (event.accepted) return false
    var op = Typing.edit({
      text: input.text,
      cursor: input.cursorPosition,
      selectionStart: input.selectionStart,
      selectionEnd: input.selectionEnd,
      maximumLength: input.maximumLength
    }, { key: event.key, text: event.text, modifiers: event.modifiers })
    if (!op) return false
    var expected = input.text.length - (op.end - op.start) + op.insert.length
    if (op.end > op.start) input.remove(op.start, op.end)
    if (op.insert.length > 0) input.insert(op.start, op.insert)
    // A validator that refused the insert has already put the text back.
    input.cursorPosition = input.text.length === expected ? op.start + op.insert.length : op.start
    event.accepted = true
    return true
  }

  Keys.onPressed: function(event) {
    if (input.typing) input.editKey(event)
  }
}
