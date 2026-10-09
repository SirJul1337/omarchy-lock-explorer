// Model a native property that changes without notifying its QML binding,
// as WlSessionLock.locked does on normal unlock in Quickshell 0.3.2.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const test = require('node:test');
const source = fs.readFileSync(path.join(__dirname, '../Service.qml'), 'utf8');

function bodyAfter(marker) {
  const at = source.indexOf(marker);
  assert(at >= 0, 'missing ' + marker);
  const open = source.indexOf('{', at);
  let depth = 1, end = open + 1;
  for (; depth; end++) {
    if (source[end] === '{') depth++;
    if (source[end] === '}') depth--;
  }
  return source.slice(open + 1, end - 1);
}

function locker() {
  const queued = [];
  const c = {
    sessionLock: { locked: false, secure: false },
    unlockTimer: { stop() {} }, clipFailsafe: { stop() {} },
    sessionLockStabilizeTimer: { stop() {} }, pendingSessionLockTimer: { stop() {} },
    clipUnlocking: false, unlockPlayback: false, unlocking: false,
    pendingAwayReport: null, motionReduced: true, faceStart: 'wake',
    logEvent() {}, startFingerprint() {}, startFido2() {}, startFace() {},
    resetAuthenticationState() {}, runWake() {},
    Qt: { callLater(fn) { queued.push(fn); } },
  };
  c.root = c;
  Object.defineProperty(c, 'secure', { get: () => c.sessionLock.secure });
  let revision = 0, requested = false;
  const cache = new Map();
  Object.defineProperty(c, 'lockStateRevision', {
    get: () => revision,
    set(value) { revision = value; cache.clear(); },
  });
  Object.defineProperty(c, 'lockRequested', {
    get: () => requested,
    set(value) { requested = value; cache.delete('locked'); },
  });
  vm.createContext(c);
  for (const name of ['locked', 'holdsLock']) {
    const body = bodyAfter('readonly property bool ' + name + ':');
    Object.defineProperty(c, name, { get() {
      if (!cache.has(name)) cache.set(name, vm.runInContext('(function() {' + body + '})()', c));
      return cache.get(name);
    } });
  }
  for (const name of ['refreshLockState', 'releaseLock']) {
    c[name] = vm.runInContext('(function() {' + bodyAfter('function ' + name + '(') + '})', c);
  }
  c.secureChanged = () => vm.runInContext(bodyAfter('onSecureStateChanged:'), c);
  c.flush = () => { while (queued.length) queued.shift()(); };
  return c;
}

function acquire(c) {
  c.lockRequested = true;
  c.sessionLock.locked = true;
  c.sessionLock.secure = true;
  c.secureChanged();
  c.flush();
  assert.equal(c.locked, true);
  assert.equal(c.holdsLock, true);
}

test('release clears both cached bindings without a native locked notification', () => {
  const c = locker();
  acquire(c);
  // finishUnlock clears the request before releasing the native lock.
  c.lockRequested = false;
  assert.equal(c.locked, true);
  c.sessionLock.secure = false;
  c.releaseLock();
  assert.equal(c.locked, false);
  assert.equal(c.holdsLock, false);
});

test('secure change refreshes after the native manager finishes updating', () => {
  const c = locker();
  acquire(c);
  c.lockRequested = false;
  assert.equal(c.locked, true);
  c.sessionLock.secure = false;
  c.secureChanged();
  // The signal is delivered before the native locked getter changes.
  c.sessionLock.locked = false;
  assert.equal(c.locked, true);
  c.flush();
  assert.equal(c.locked, false);
  assert.equal(c.holdsLock, false);
});

test('repeated lock and unlock cycles leave the next lock available', () => {
  const c = locker();
  for (let i = 0; i < 3; i++) {
    acquire(c);
    c.lockRequested = false;
    assert.equal(c.locked, true);
    c.sessionLock.secure = false;
    c.releaseLock();
    assert.equal(c.locked, false);
    assert.equal(c.holdsLock, false);
  }
});
