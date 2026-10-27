// The wake grace after a blanked screen (issues #85, #86): keys that wake the
// panel must not reach the password, but the grace is one window per wake,
// not a debounce. Every key and pointer move while blocked asks for another
// wake; a finished wake used to start the grace over, so someone typing into
// the lit screen kept the field inert until they stopped. runWake, runBlank
// and the wake process's onExited are lifted out of Service.qml and run
// against a stub root on a fake clock.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const test = require('node:test');

const source = fs.readFileSync(path.join(__dirname, '../Service.qml'), 'utf8');
const hostSource = fs.readFileSync(path.join(__dirname, '../LockHost.qml'), 'utf8');

function bodyAfter(marker, start = 0) {
  const at = source.indexOf(marker, start);
  assert(at >= 0, 'missing ' + marker);
  const open = source.indexOf('{', at);
  let depth = 1, end = open + 1;
  for (; depth; end++) {
    if (source[end] === '{') depth++;
    if (source[end] === '}') depth--;
  }
  return source.slice(open + 1, end - 1);
}

const GRACE = 1000;
const WAKE_MS = 300; // how long omarchy-system-wake takes to exit
const exitedBody = bodyAfter('onExited:', source.indexOf('id: wakeProcess'));
const triggeredBody = (() => {
  const at = source.indexOf('id: inputUnblockTimer');
  const from = source.indexOf('onTriggered:', at) + 'onTriggered:'.length;
  return source.slice(from, source.indexOf('\n', from)).trim();
})();

function lock() {
  const c = {
    now: 0,
    screenBlanked: false, inputBlocked: false, wakeGracePending: false,
    keepDisplayOn: false, displayBlankingSuppressed: false,
    lockRequested: true, sessionLock: { secure: true }, faceStart: 'off',
    lockedAt: 0, lastFaceRound: 0, faceWakeQuiet: 0, faceRoundGap: 0,
    wakeInputGrace: GRACE,
    Qt: { callLater() {} },
    retryFace() {}, retryFido2() {}, stopFace() {}, armBlankTimer() {},
    blankProcess: { running: false },
  };
  c.root = c;
  c.inputUnblockTimer = {
    interval: 0, running: false, due: 0,
    restart() { this.running = true; this.due = c.now + this.interval },
    stop() { this.running = false },
  };
  c.wakeProcess = { _running: false, endsAt: 0 };
  Object.defineProperty(c.wakeProcess, 'running', {
    get() { return this._running },
    set(v) { if (v && !this._running) { this._running = true; this.endsAt = c.now + WAKE_MS } },
  });
  vm.createContext(c);
  vm.runInContext(`function runWake() {${bodyAfter('function runWake(')}}`, c);
  vm.runInContext(`function runBlank() {${bodyAfter('function runBlank(')}}`, c);
  // Advance the clock in small steps, firing the process exit and the timer
  // in the order they fall due.
  c.advance = (ms) => {
    const end = c.now + ms;
    while (c.now < end) {
      c.now = Math.min(end, c.now + 10);
      if (c.wakeProcess._running && c.now >= c.wakeProcess.endsAt) {
        c.wakeProcess._running = false;
        vm.runInContext('(function(){' + exitedBody + '})()', c);
      }
      if (c.inputUnblockTimer.running && c.now >= c.inputUnblockTimer.due) {
        c.inputUnblockTimer.running = false;
        vm.runInContext('(function(){' + triggeredBody + '})()', c);
      }
    }
  };
  return c;
}

test('a key on a blanked screen wakes it and the field stays inert for the grace', () => {
  const c = lock();
  c.runBlank();
  assert.equal(c.inputBlocked, true);
  c.runWake();
  c.advance(WAKE_MS + GRACE - 50);
  assert.equal(c.inputBlocked, true, 'still inside the grace');
  c.advance(100);
  assert.equal(c.inputBlocked, false, 'grace over');
});

test('typing through the grace does not push the unblock back (#86)', () => {
  const c = lock();
  c.runBlank();
  c.runWake();
  // A key every 120 ms for five seconds, each asking for a wake.
  let unblockedAt = -1;
  for (let t = 0; t < 5000; t += 120) {
    c.advance(120);
    c.runWake();
    if (!c.inputBlocked && unblockedAt < 0) unblockedAt = c.now;
  }
  assert.ok(unblockedAt > 0, 'the field never took keys while someone kept typing');
  assert.ok(unblockedAt <= WAKE_MS + GRACE + 150, `unblocked late, at ${unblockedAt} ms`);
});

test('a wake with the screen already on never blocks the field', () => {
  const c = lock();
  c.runWake();
  c.advance(50);
  assert.equal(c.inputBlocked, false);
  c.advance(2000);
  assert.equal(c.inputBlocked, false);
});

test('each blank gets its own grace', () => {
  const c = lock();
  c.runBlank(); c.runWake(); c.advance(WAKE_MS + GRACE + 50);
  assert.equal(c.inputBlocked, false);
  c.runBlank();
  assert.equal(c.inputBlocked, true);
  c.runWake(); c.advance(WAKE_MS + 50);
  assert.equal(c.inputBlocked, true, 'second wake still has its grace');
  c.advance(GRACE);
  assert.equal(c.inputBlocked, false);
});

test('a wake process that never exits still lets go through the failsafe', () => {
  const c = lock();
  c.runBlank();
  c.runWake();
  c.wakeProcess.endsAt = Infinity;
  c.advance(3100);
  assert.equal(c.inputBlocked, false);
});

test('the lock hands focus back to the field when the block lifts (#85)', () => {
  assert.match(hostSource,
    /onInputBlockedChanged: if \(!inputBlocked && inputEnabled\) Qt\.callLater\(forcePasswordFocus\)/);
});
