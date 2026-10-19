.pragma library

// The keyboard editing behind TypedInput: which keys change the text, and
// how. Pure functions over a snapshot of the field, so the rules run in Node
// (tests/typing.test.cjs) as well as in the shell.
//
// edit(state, key) answers null when the key is not an edit (the TextInput
// handles movement, selection and Copy itself), or a replacement
// { start, end, insert } for the span [start, end) of the text, with the
// cursor landing right after `insert`.

var KEY = {
  Backspace: 0x01000003,
  Delete: 0x01000007
}

var MOD = {
  Control: 0x04000000,
  Meta: 0x10000000
}

function isSurrogateHigh(c) { return c >= 0xD800 && c <= 0xDBFF }
function isSurrogateLow(c) { return c >= 0xDC00 && c <= 0xDFFF }
function isSpace(ch) { return /\s/.test(ch) }

// One code point back from pos, so a Backspace over an emoji takes both
// halves of its surrogate pair.
function stepBack(text, pos) {
  if (pos <= 0) return 0
  var p = pos - 1
  if (p > 0 && isSurrogateLow(text.charCodeAt(p)) && isSurrogateHigh(text.charCodeAt(p - 1))) p--
  return p
}

function stepForward(text, pos) {
  if (pos >= text.length) return text.length
  var p = pos + 1
  if (p < text.length && isSurrogateHigh(text.charCodeAt(pos)) && isSurrogateLow(text.charCodeAt(p))) p++
  return p
}

// Ctrl+Backspace: back over the spaces before the cursor, then the word.
function wordBack(text, pos) {
  var p = pos
  while (p > 0 && isSpace(text.charAt(p - 1))) p--
  while (p > 0 && !isSpace(text.charAt(p - 1))) p--
  return p
}

function wordForward(text, pos) {
  var p = pos
  while (p < text.length && isSpace(text.charAt(p))) p++
  while (p < text.length && !isSpace(text.charAt(p))) p++
  return p
}

// Text a key carries that is worth inserting: something, and none of it a
// control character (Return, Tab, Escape and Backspace all arrive as one).
function isPrintable(text) {
  if (!text || text.length === 0) return false
  for (var i = 0; i < text.length; i++) {
    var c = text.charCodeAt(i)
    if (c < 0x20 || c === 0x7F) return false
  }
  return true
}

function edit(state, key) {
  var text = String(state.text || "")
  var cursor = Math.max(0, Math.min(text.length, state.cursor | 0))
  var selStart = Math.max(0, Math.min(text.length, state.selectionStart | 0))
  var selEnd = Math.max(0, Math.min(text.length, state.selectionEnd | 0))
  var hasSelection = selEnd > selStart
  var ctrl = (key.modifiers & MOD.Control) !== 0

  if (key.key === KEY.Backspace) {
    if (hasSelection) return { start: selStart, end: selEnd, insert: "" }
    var from = ctrl ? wordBack(text, cursor) : stepBack(text, cursor)
    return { start: from, end: cursor, insert: "" }
  }
  if (key.key === KEY.Delete) {
    if (hasSelection) return { start: selStart, end: selEnd, insert: "" }
    var to = ctrl ? wordForward(text, cursor) : stepForward(text, cursor)
    return { start: cursor, end: to, insert: "" }
  }

  // Shortcuts are not typing. Alt is left alone, as TextInput does: an Alt
  // combination with no binding of its own still inserts its character.
  if (key.modifiers & (MOD.Control | MOD.Meta)) return null
  if (!isPrintable(key.text)) return null

  var start = hasSelection ? selStart : cursor
  var end = hasSelection ? selEnd : cursor
  var insert = String(key.text)
  var maximum = state.maximumLength | 0
  if (maximum > 0) {
    var room = maximum - (text.length - (end - start))
    insert = room > 0 ? insert.slice(0, room) : ""
  }
  return { start: start, end: end, insert: insert }
}
