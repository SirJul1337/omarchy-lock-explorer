const assert = require("node:assert/strict");
const { test } = require("node:test");
const fs = require("node:fs");
const path = require("node:path");

// Every text field in the plugin is a TypedInput or a TypedEdit: Qt's text
// items read the foreign clipboard when they are editable (automatically on
// every clipboard change for TextInput, on paste, middle click and drop for
// TextEdit), unbounded and on the shell's main thread. A plain TextInput,
// TextEdit, TextField or TextArea may only appear with `readOnly: true` set
// in its own block, the way the two Typed types declare themselves.

const root = path.join(__dirname, "..");
const SKIP = new Set([".git", "node_modules", ".claude"]);
const TYPES = /(^|[\s;{])((?:[A-Za-z]+\.)?(TextInput|TextEdit|TextField|TextArea))\s*\{/g;

function files(dir, ext, out = []) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (SKIP.has(entry.name)) continue;
    const p = path.join(dir, entry.name);
    if (entry.isDirectory()) files(p, ext, out);
    else if (entry.name.endsWith(ext)) out.push(p);
  }
  return out;
}

// The text of the block that starts at the "{" at `open`, braces balanced,
// strings and comments ignored for counting.
function block(source, open) {
  let depth = 0;
  for (let i = open; i < source.length; i++) {
    const c = source[i];
    if (c === "/" && source[i + 1] === "/") { i = source.indexOf("\n", i); if (i < 0) break; continue; }
    if (c === "/" && source[i + 1] === "*") { i = source.indexOf("*/", i + 2) + 1; if (i <= 0) break; continue; }
    if (c === '"' || c === "'") { const q = c; for (i++; i < source.length && source[i] !== q; i++) if (source[i] === "\\") i++; continue; }
    if (c === "{") depth++;
    else if (c === "}" && --depth === 0) return source.slice(open, i + 1);
  }
  return source.slice(open);
}

// readOnly set to the literal true at the top level of the block, not in a
// nested item.
function readOnlyAtTop(body) {
  let depth = 0;
  const lines = body.split("\n");
  for (const line of lines) {
    if (depth === 1 && /^\s*readOnly:\s*true\s*(\/\/.*)?$/.test(line)) return true;
    for (const c of line.replace(/"(?:[^"\\]|\\.)*"/g, "")) {
      if (c === "{") depth++;
      else if (c === "}") depth--;
    }
  }
  return false;
}

test("no QML file declares an editable text field", () => {
  const offenders = [];
  for (const file of files(root, ".qml")) {
    const source = fs.readFileSync(file, "utf8");
    for (const m of source.matchAll(TYPES)) {
      const open = m.index + m[0].length - 1;
      if (!readOnlyAtTop(block(source, open))) {
        const line = source.slice(0, open).split("\n").length;
        offenders.push(`${path.relative(root, file)}:${line} ${m[2]}`);
      }
    }
  }
  assert.deepEqual(offenders, [], "use TypedInput or TypedEdit instead");
});

test("no script generates an editable text field", () => {
  const offenders = [];
  for (const file of files(root, ".js")) {
    const source = fs.readFileSync(file, "utf8");
    for (const m of source.matchAll(/["'`][^"'`\n]*\b(TextInput|TextEdit|TextField|TextArea)\s*\{/g)) {
      offenders.push(`${path.relative(root, file)}:${source.slice(0, m.index).split("\n").length} ${m[1]}`);
    }
  }
  assert.deepEqual(offenders, [], "generated QML must use LockInput, TypedInput or TypedEdit");
});

test("the two typed fields are read-only themselves", () => {
  for (const f of ["designs/TypedInput.qml", "designs/TypedEdit.qml"]) {
    const source = fs.readFileSync(path.join(root, f), "utf8");
    const m = source.match(/^(TextInput|TextEdit)\s*\{/m);
    assert(m, `${f} declares its base type`);
    assert(readOnlyAtTop(block(source, m.index + m[0].length - 1)), `${f} sets readOnly: true`);
  }
});
