const assert = require("node:assert/strict");
const { test } = require("node:test");
const fs = require("node:fs");
const path = require("node:path");

// The lock screen standards, see standards.md. Budgets are checked against the
// last full benchmark (tests/bench-results/full-1080p.csv, written by
// tests/bench-lock-load.sh); the code rules are checked straight from the .qml.
const root = path.join(__dirname, "..");
const LIMIT = { cpu: 35, gpu: 10, rss: 320 };

// Over the limit when the standards were written. Allowed to stay, never to get
// worse (the figure is the CPU/GPU they measured, with a little room for noise).
// Do not add to this list: bring the design under the limit instead.
const LEGACY = {
  statusline: { cpu: 140, gpu: 10 },
  digital: { cpu: 130, gpu: 10 },
  fireworks: { cpu: 75, gpu: 10 },
  screensaver: { cpu: 55, gpu: 10 },
  binary: { cpu: 55, gpu: 10 },
  rain: { cpu: 55, gpu: 11 },
  synthwave: { cpu: 55, gpu: 10 },
  supernova: { cpu: 50, gpu: 10 },
  panel: { cpu: 45, gpu: 10 },
  beacon: { cpu: 45, gpu: 10 },
  aurora: { cpu: 35, gpu: 15 },
};

// Enabled designs from Designs.js, as { id: file }. Commented-out entries are
// work in progress and do not count.
const registry = fs.readFileSync(path.join(root, "Designs.js"), "utf8");
const designs = {};
for (const m of registry.matchAll(/^\s*\{ id: "([^"]+)", file: "([^"]+)"/gm)) designs[m[1]] = m[2];

function results() {
  const rows = fs.readFileSync(path.join(root, "tests/bench-results/full-1080p.csv"), "utf8").trim().split("\n").slice(1);
  const out = {};
  for (const row of rows) {
    const [id, cpu, gpu, rss] = row.split(",");
    out[id] = { cpu: Number(cpu), gpu: Number(gpu), rss: Number(rss) };
  }
  return out;
}

test("every enabled design has a benchmark result", () => {
  const measured = results();
  const missing = Object.keys(designs).filter((id) => !(id in measured));
  assert.deepEqual(missing, [], "run tests/bench-lock-load.sh and refresh tests/bench-results/full-1080p.csv");
});

test("designs stay within the CPU, GPU and memory limits", () => {
  const measured = results();
  for (const id of Object.keys(designs)) {
    const m = measured[id];
    if (!m) continue;
    const allowed = LEGACY[id] || LIMIT;
    assert.ok(m.cpu <= allowed.cpu, `${id}: ${m.cpu}% CPU is over ${allowed.cpu}%`);
    assert.ok(m.gpu <= allowed.gpu, `${id}: ${m.gpu}% GPU is over ${allowed.gpu}%`);
    assert.ok(m.rss <= LIMIT.rss, `${id}: ${m.rss} MB is over ${LIMIT.rss} MB`);
  }
});

test("legacy exceptions are still needed", () => {
  const measured = results();
  for (const id of Object.keys(LEGACY)) {
    assert.ok(id in designs, `${id} is in LEGACY but not an enabled design`);
    const m = measured[id];
    if (!m) continue;
    assert.ok(m.cpu > LIMIT.cpu || m.gpu > LIMIT.gpu, `${id} is under the limit now, remove it from LEGACY`);
  }
});

test("a Canvas repainted from a timer is gated on animating and has no shadowBlur", () => {
  for (const [id, file] of Object.entries(designs)) {
    const src = fs.readFileSync(path.join(root, "designs", file), "utf8");
    // requestPaint() in a timer or frame handler, not just on a resize.
    if (!/on(Frame)?Triggered[^]{0,500}?requestPaint\s*\(/.test(src)) continue;
    assert.ok(/\banimating\b/.test(src), `${id}: repaints from a timer but never checks animating`);
    assert.ok(!/shadowBlur\s*=\s*[1-9]/.test(src), `${id}: shadowBlur on an animated canvas`);
  }
});
