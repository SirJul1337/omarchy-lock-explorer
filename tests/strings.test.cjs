const assert = require("node:assert/strict");
const { test } = require("node:test");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

// designs/Strings.js is a QML JavaScript library; drop the pragma and run it.
const root = path.join(__dirname, "..");
const source = fs.readFileSync(path.join(root, "designs/Strings.js"), "utf8").replace(/^\.pragma library\s*/, "");
const S = {};
vm.runInNewContext(source + "\nthis.TEXT = TEXT; this.LANGUAGES = LANGUAGES; this.tr = tr; this.fromLocale = fromLocale;", S);

test("every language has every line", () => {
  const langs = Array.from(Object.keys(S.TEXT));
  const all = new Set(langs.flatMap((l) => Object.keys(S.TEXT[l])));
  for (const l of langs) {
    const missing = [...all].filter((k) => !(k in S.TEXT[l]));
    assert.deepEqual(missing, [], `${l} is missing lines`);
  }
  assert.deepEqual([...langs].sort(), Array.from(S.LANGUAGES, (l) => l.id).filter((id) => id !== "en").sort());
});

test("placeholders survive translation", () => {
  for (const [l, table] of Object.entries(S.TEXT))
    for (const [k, v] of Object.entries(table))
      assert.equal((v.match(/%1/g) || []).length, (k.match(/%1/g) || []).length, `${l}: ${k}`);
});

test("every lock.tr() text in a design is a known line", () => {
  const keys = new Set(Object.keys(S.TEXT.de).map((k) => k.toLowerCase()));
  const dir = path.join(root, "designs");
  for (const file of fs.readdirSync(dir).filter((f) => f.endsWith(".qml"))) {
    const text = fs.readFileSync(path.join(dir, file), "utf8");
    for (const m of text.matchAll(/\btr\("((?:[^"\\]|\\.)*)"\)/g)) {
      const translated = S.tr("de", m[1]);
      assert.notEqual(translated, m[1], `${file}: "${m[1]}" has no translation`);
    }
  }
  assert.ok(keys.size > 0);
});

test("parts, icons and case are kept", () => {
  assert.equal(S.tr("de", "󰌾  Locked  ·  Esc clears input"), "󰌾  Gesperrt  ·  Esc löscht die Eingabe");
  assert.equal(S.tr("de", "󰌾  LOCKED"), "󰌾  GESPERRT");
  assert.equal(S.tr("da", "enter to unlock"), "enter låser op");
  assert.equal(S.tr("de", "%1 failed attempts"), "%1 Fehlversuche");
  assert.equal(S.tr("pl", "1 failed attempt"), "1 nieudana próba");
  assert.equal(S.tr("en", "Locked"), "Locked");
  assert.equal(S.tr("de", "Not a line"), "Not a line");
});

test("locales map to a language", () => {
  assert.equal(S.fromLocale("de_DE.UTF-8"), "de");
  assert.equal(S.fromLocale("pt_BR"), "pt");
  assert.equal(S.fromLocale("nn_NO"), "nb");
  assert.equal(S.fromLocale("C"), "en");
  assert.equal(S.fromLocale("ja_JP.UTF-8"), "en");
});
