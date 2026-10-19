const assert = require("node:assert/strict");
const { test } = require("node:test");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

// designs/Typing.js is a QML JavaScript library; drop the pragma and run it.
const root = path.join(__dirname, "..");
const source = fs.readFileSync(path.join(root, "designs/Typing.js"), "utf8").replace(/^\.pragma library\s*/, "");
const T = {};
vm.runInNewContext(source + "\nthis.edit = edit; this.KEY = KEY; this.MOD = MOD;", T);

const CTRL = T.MOD.Control;
const META = T.MOD.Meta;
const SHIFT = 0x02000000;
const ALT = 0x08000000;
const KEY_A = 0x41, KEY_RETURN = 0x01000004, KEY_TAB = 0x01000001, KEY_ESCAPE = 0x01000000, KEY_LEFT = 0x12;

function field(text, cursor, selectionStart, selectionEnd, maximumLength) {
  return {
    text,
    cursor: cursor ?? text.length,
    selectionStart: selectionStart ?? 0,
    selectionEnd: selectionEnd ?? 0,
    maximumLength: maximumLength ?? 0,
  };
}
function key(code, text, modifiers) { return { key: code, text: text ?? "", modifiers: modifiers ?? 0 }; }
function apply(state, op) {
  return { text: state.text.slice(0, op.start) + op.insert + state.text.slice(op.end), cursor: op.start + op.insert.length };
}
// Results come out of the library's own realm; compare them as plain objects.
function op(o) { return o === null ? null : { start: o.start, end: o.end, insert: o.insert }; }

test("printable text goes in at the cursor", () => {
  const s = field("abd", 2);
  assert.deepEqual(apply(s, T.edit(s, key(0x43, "c"))), { text: "abcd", cursor: 3 });
});

test("typing over a selection replaces it", () => {
  const s = field("hello world", 5, 0, 5);
  assert.deepEqual(apply(s, T.edit(s, key(0x48, "H"))), { text: "H world", cursor: 1 });
});

test("control characters and empty keys are not typing", () => {
  assert.equal(T.edit(field("abc"), key(KEY_RETURN, "\r")), null);
  assert.equal(T.edit(field("abc"), key(KEY_TAB, "\t")), null);
  assert.equal(T.edit(field("abc"), key(KEY_ESCAPE, "\u001b")), null);
  assert.equal(T.edit(field("abc"), key(KEY_LEFT, "")), null);
  assert.equal(T.edit(field("abc"), key(SHIFT, "")), null);
});

test("shortcuts are left to the field and the shell", () => {
  assert.equal(T.edit(field("abc"), key(KEY_A, "\u0001", CTRL)), null);
  assert.equal(T.edit(field("abc"), key(0x56, "v", CTRL)), null);
  assert.equal(T.edit(field("abc"), key(KEY_A, "a", META)), null);
  // Alt on its own is not a shortcut layer here, as in TextInput.
  const s = field("ab");
  assert.deepEqual(apply(s, T.edit(s, key(KEY_A, "a", ALT))), { text: "aba", cursor: 3 });
});

test("backspace takes one code point, including a surrogate pair", () => {
  const plain = field("abc", 3);
  assert.deepEqual(apply(plain, T.edit(plain, key(T.KEY.Backspace, "\b"))), { text: "ab", cursor: 2 });
  const emoji = field("a\u{1F512}", 3);
  assert.deepEqual(apply(emoji, T.edit(emoji, key(T.KEY.Backspace, "\b"))), { text: "a", cursor: 1 });
  const middle = field("abc", 1);
  assert.deepEqual(apply(middle, T.edit(middle, key(T.KEY.Backspace, "\b"))), { text: "bc", cursor: 0 });
});

test("backspace at the start and delete at the end change nothing but are still edits", () => {
  assert.deepEqual(op(T.edit(field("abc", 0), key(T.KEY.Backspace, "\b"))), { start: 0, end: 0, insert: "" });
  assert.deepEqual(op(T.edit(field("abc", 3), key(T.KEY.Delete, "\u007f"))), { start: 3, end: 3, insert: "" });
});

test("backspace and delete remove the selection first", () => {
  const s = field("hello world", 11, 6, 11);
  assert.deepEqual(apply(s, T.edit(s, key(T.KEY.Backspace, "\b"))), { text: "hello ", cursor: 6 });
  assert.deepEqual(apply(s, T.edit(s, key(T.KEY.Delete, "\u007f"))), { text: "hello ", cursor: 6 });
});

test("delete takes the code point after the cursor", () => {
  const s = field("a\u{1F512}b", 1);
  assert.deepEqual(apply(s, T.edit(s, key(T.KEY.Delete, "\u007f"))), { text: "ab", cursor: 1 });
});

test("ctrl+backspace and ctrl+delete take a word", () => {
  const s = field("one two  three", 9);
  assert.deepEqual(apply(s, T.edit(s, key(T.KEY.Backspace, "\b", CTRL))), { text: "one three", cursor: 4 });
  const t = field("one two  three", 3);
  assert.deepEqual(apply(t, T.edit(t, key(T.KEY.Delete, "\u007f", CTRL))), { text: "one  three", cursor: 3 });
});

test("maximumLength caps what goes in", () => {
  const full = field("12345", 5, 0, 0, 5);
  assert.deepEqual(op(T.edit(full, key(0x36, "6"))), { start: 5, end: 5, insert: "" });
  const nearly = field("1234", 4, 0, 0, 5);
  assert.deepEqual(apply(nearly, T.edit(nearly, key(0x36, "67"))), { text: "12346", cursor: 5 });
  const over = field("12345", 5, 2, 5, 5);
  assert.deepEqual(apply(over, T.edit(over, key(0x36, "6789"))), { text: "12678", cursor: 5 });
});

test("a cursor or selection beyond the text is clamped", () => {
  assert.deepEqual(op(T.edit(field("ab", 9), key(0x63, "c"))), { start: 2, end: 2, insert: "c" });
  assert.deepEqual(op(T.edit(field("ab", 2, 1, 9), key(T.KEY.Backspace, "\b"))), { start: 1, end: 2, insert: "" });
});
