const assert = require("node:assert/strict");
const { test } = require("node:test");
const fs = require("node:fs");
const path = require("node:path");

// A file the account itself can write is read through designs/CappedFile.qml
// (a child process: a regular file only, a byte cap), never through a
// FileView: a FIFO there stalls the read and the size is unbounded. A FileView
// may still read what root owns (/etc, /proc, /usr), and may watch or write a
// user file as long as it never loads it (`preload: false`). LocalSettings is
// the one exception, explained where it is declared.

const root = path.join(__dirname, "..");
const SKIP = new Set([".git", "node_modules", ".claude"]);
const ALLOWED_READS = new Set(["LocalSettings.qml"]);

function files(dir, out = []) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (SKIP.has(entry.name)) continue;
    const p = path.join(dir, entry.name);
    if (entry.isDirectory()) files(p, out);
    else if (entry.name.endsWith(".qml")) out.push(p);
  }
  return out;
}

function blockAt(src, open) {
  let depth = 0;
  for (let i = open; i < src.length; i++) {
    if (src[i] === "{") depth++;
    if (src[i] === "}" && --depth === 0) return src.slice(open, i + 1);
  }
  return src.slice(open);
}

test("no FileView loads a file the account can write", () => {
  const offenders = [];
  for (const file of files(root)) {
    const rel = path.relative(root, file).replace(/\\/g, "/");
    if (ALLOWED_READS.has(rel)) continue;
    const src = fs.readFileSync(file, "utf8");
    const re = /\bFileView\s*\{/g;
    let m;
    while ((m = re.exec(src))) {
      const block = blockAt(src, src.indexOf("{", m.index));
      const pathLine = (block.match(/^\s*path:\s*(.*)$/m) || [, ""])[1];
      const rootOwned = /^"\/(etc|proc|usr|sys)\//.test(pathLine.trim());
      const neverLoads = /^\s*preload:\s*false\s*$/m.test(block);
      // A FileView whose path is set later says so above it.
      const before = src.slice(Math.max(0, m.index - 200), m.index);
      if (/root-owned/.test(before)) continue;
      if (!rootOwned && !neverLoads) {
        const line = src.slice(0, m.index).split("\n").length;
        offenders.push(`${rel}:${line} (${pathLine.trim() || "no path"})`);
      }
    }
  }
  assert.deepEqual(offenders, [], "read these through CappedFile instead");
});

test("CappedFile refuses anything but a capped regular file", () => {
  const src = fs.readFileSync(path.join(root, "designs/CappedFile.qml"), "utf8");
  assert.match(src, /\[ -f "\$f" \]/);
  assert.match(src, /\[ ! -L "\$f" \]/);
  assert.match(src, /stat -L -c %s/);
  assert.match(src, /head -c "\$n"/);
});
