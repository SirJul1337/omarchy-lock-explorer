const assert = require("node:assert/strict");
const { test } = require("node:test");
const fs = require("node:fs");
const path = require("node:path");

// A key or pointer move on a blanked lock wakes it, and the field stays inert
// for the wake grace after that. The grace is started by the wake process
// exiting, so a wake process run for every later key restarted the grace each
// time: the field ignored typing for as long as typing went on (issue #86).
// Only the wake that undoes a blank may run it.

const root = path.join(__dirname, "..");
const read = (f) => fs.readFileSync(path.join(root, f), "utf8");

const body = (src, name) => {
  const at = src.indexOf(`function ${name}(`);
  assert.ok(at >= 0, `${name} not found`);
  let depth = 0, end = src.indexOf("{", at);
  for (; end < src.length; end++) {
    if (src[end] === "{") depth++;
    else if (src[end] === "}" && --depth === 0) break;
  }
  return src.slice(at, end);
};

test("only the wake after a blank runs the wake process", () => {
  const svc = read("Service.qml");
  const wake = body(svc, "runWake");
  const starts = wake.match(/wakeProcess\.running = true/g) || [];
  assert.equal(starts.length, 1);
  assert.match(wake, /if \(wakePending && !wakeProcess\.running\) \{\s*wakePending = false\s*wakeProcess\.running = true/);
  assert.match(body(svc, "runBlank"), /wakePending = true/);
});

test("the field takes focus back when the wake grace ends", () => {
  assert.match(read("LockHost.qml"),
    /onInputBlockedChanged: if \(!inputBlocked && inputEnabled\) Qt\.callLater\(forcePasswordFocus\)/);
});

// Coming back from suspend, the lock was still dark from the blank before it,
// and the key that lit it started the grace, so the first keystrokes after a
// resume went nowhere (issue #85). A resume lights the lock itself, with no
// grace, and ends one a key already started.
test("a resume wakes the lock without the grace", () => {
  const svc = read("Service.qml");
  assert.match(svc, /running: root\.lockRequested[\s\S]{0,400}now - lastTick > interval \+ \d+\) root\.wakeFromResume\(\)/);
  const resume = body(svc, "wakeFromResume");
  assert.match(resume, /inputUnblockTimer\.stop\(\)\s*inputBlocked = false/);
  assert.match(resume, /resumeWake = inputBlocked/);
  assert.match(resume, /if \(!wakeProcess\.running\) wakePending = true\s*runWake\(\)/);
  assert.match(svc, /var grace = root\.resumeWake \? 0 : root\.wakeInputGrace\s*root\.resumeWake = false/);
});
