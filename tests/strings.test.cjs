const assert = require("node:assert/strict");
const { test } = require("node:test");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

// designs/Strings.js is a QML JavaScript library; drop the pragma and run it.
const root = path.join(__dirname, "..");
const source = fs.readFileSync(path.join(root, "designs/Strings.js"), "utf8").replace(/^\.pragma library\s*/, "");
const S = {};
vm.runInNewContext(source + "\nthis.TEXT = TEXT; this.LANGUAGES = LANGUAGES; this.tr = tr; this.fromLocale = fromLocale;"
  + " this.makeLookup = makeLookup; this.trWith = trWith;", S);

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
    // A line German spells the same (Kernel) still has to be in the table.
    const one = (t) => keys.has(t.toLowerCase().replace(/^[^a-z0-9%]+/, "").trim());
    for (const m of text.matchAll(/\btr\("((?:[^"\\]|\\.)*)"\)/g)) {
      const t = JSON.parse(`"${m[1]}"`);
      assert.ok(one(t) || t.split(/\s+·\s+/).every(one) || S.tr("de", t) !== t, `${file}: "${m[1]}" has no translation`);
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

// ExplorerStrings.js imports Strings.js as Base; hand it the same context.
const uiSource = fs.readFileSync(path.join(root, "ExplorerStrings.js"), "utf8")
  .replace(/^\.pragma library\s*/, "").replace(/^\.import .*$/m, "");
const U = { Base: S };
vm.runInNewContext(uiSource + "\nthis.TEXT = TEXT; this.tr = tr;", U);

test("the explorer has every line in every language", () => {
  const langs = Object.keys(U.TEXT);
  assert.deepEqual([...langs].sort(), Object.keys(S.TEXT).sort());
  const all = new Set(langs.flatMap((l) => Object.keys(U.TEXT[l])));
  for (const l of langs) {
    assert.deepEqual([...all].filter((k) => !(k in U.TEXT[l])), [], `${l} is missing lines`);
    for (const [k, v] of Object.entries(U.TEXT[l]))
      for (const p of ["%1", "%2"])
        assert.equal(v.split(p).length, k.split(p).length, `${l}: ${k}`);
  }
});

test("every tr() text in the explorer, designer and editor is a known line", () => {
  const keys = new Set(Object.keys(U.TEXT.de).map((k) => k.toLowerCase()));
  const one = (t) => keys.has(t.toLowerCase().replace(/^[^a-z0-9%]+/, ""));
  const known = (t) => one(t) || t.split(/\s+·\s+/).every(one);
  const files = ["Explorer.qml", "Designer.qml", "Editor.qml", "DesignerField.qml"];
  let count = 0;
  for (const file of files) {
    const text = fs.readFileSync(path.join(root, file), "utf8");
    const found = [];
    for (const m of text.matchAll(/\b(?:root|designer|editor|field)\.tr\("((?:[^"\\]|\\.)*)"\)/g)) found.push(m[1]);
    for (const m of text.matchAll(/\b(?:root|designer|editor|field)\.tr\([^()"]*\?\s*"([^"]*)"\s*:\s*"([^"]*)"\)/g)) found.push(m[1], m[2]);
    for (const t of found) assert.ok(known(JSON.parse(`"${t}"`)), `${file}: "${t}" has no translation`);
    count += found.length;
  }
  assert.ok(count > 250);
});

// The designer's pieces, their settings and choices are shown through
// designer.tr(); effect names and the clock and date samples are not checked.
test("every designer piece is a known line", () => {
  const D = {};
  const src = fs.readFileSync(path.join(root, "Designer.js"), "utf8").replace(/^\.pragma library\s*/, "").replace(/^\.import .*$/gm, "");
  vm.runInNewContext(src + "\nthis.KINDS = KINDS; this.GROUPS = GROUPS;", D);
  const keys = new Set(Object.keys(U.TEXT.de).map((k) => k.toLowerCase()));
  const texts = [...D.GROUPS];
  for (const k of Object.values(D.KINDS)) {
    texts.push(k.name, k.hint);
    for (const f of k.fields || []) {
      texts.push(f.label);
      if (f.key === "effect" || f.key === "format") continue;
      for (const o of f.options || []) if (/[a-z]/i.test(o.name)) texts.push(o.name);
    }
  }
  for (const t of texts) assert.ok(keys.has(String(t).toLowerCase()), `Designer.js: "${t}" has no translation`);
});

test("explorer lines keep their placeholders and capitals", () => {
  assert.equal(U.tr("de", "LOCK SCREEN EXPLORER"), "SPERRBILDSCHIRM-EXPLORER");
  assert.equal(U.tr("da", "%1 starred with F"), "%1 markeret med F");
  assert.equal(U.tr("fr", "Esc or ? closes this"), "Échap ou ? ferme ceci");
  assert.equal(U.tr("es", "min, Enter"), "min, Intro");
  assert.equal(U.tr("en", "Settings"), "Settings");
  assert.equal(U.tr("de", "LAYERS  ·  TOP FIRST"), "EBENEN  ·  OBERSTE ZUERST");
  assert.equal(U.tr("de", "Back  Esc"), "Zurück  Esc");
  assert.equal(U.tr("de", "Back"), "Nach hinten");
});

test("locales map to a language", () => {
  assert.equal(S.fromLocale("de_DE.UTF-8"), "de");
  assert.equal(S.fromLocale("pt_BR"), "pt");
  assert.equal(S.fromLocale("nn_NO"), "nb");
  assert.equal(S.fromLocale("C"), "en");
  assert.equal(S.fromLocale("ja_JP.UTF-8"), "en");
});
