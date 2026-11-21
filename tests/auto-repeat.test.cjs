const assert = require("node:assert/strict");
const { test } = require("node:test");
const fs = require("node:fs");
const path = require("node:path");

// A key-up that arrives late (a stalled compositor on wake, a starved input
// method) reaches the field as client-side auto-repeat, and every repeat used
// to type the character again. Password fields drop auto-repeat before a key
// can edit the text; only Backspace and Delete may repeat, to clear it.

const root = path.join(__dirname, "..");
const read = (f) => fs.readFileSync(path.join(root, f), "utf8");

const handler = (src) => {
  const at = src.indexOf("Keys.onPressed:");
  assert.ok(at >= 0, "Keys.onPressed not found");
  let depth = 0, end = src.indexOf("{", at);
  for (; end < src.length; end++) {
    if (src[end] === "{") depth++;
    else if (src[end] === "}" && --depth === 0) break;
  }
  return src.slice(at, end);
};

const guard = /event\.isAutoRepeat && event\.key !== Qt\.Key_Backspace && event\.key !== Qt\.Key_Delete\)\s*\{\s*event\.accepted = true\s*return/;

test("the lock's password field drops auto-repeat before editing", () => {
  const keys = handler(read("designs/LockInput.qml"));
  const at = keys.search(guard);
  assert.ok(at >= 0, "auto-repeat guard missing");
  assert.ok(at < keys.indexOf("editKey("), "guard must come before editKey");
});

test("TypedInput drops auto-repeat only in password fields", () => {
  const src = read("designs/TypedInput.qml");
  assert.match(src, /property bool passwordField: false/);
  assert.match(handler(src), /input\.passwordField && event\.isAutoRepeat\s*&& event\.key !== Qt\.Key_Backspace && event\.key !== Qt\.Key_Delete\)\s*\{\s*event\.accepted = true\s*return/);
});

test("the emergency password field is a password field", () => {
  assert.match(read("LockHost.qml"), /echoMode: TextInput\.Password\s*passwordField: true/);
});
