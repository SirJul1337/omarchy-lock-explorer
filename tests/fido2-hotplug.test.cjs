// Security key presence while locked: wake and retry recheck it, the hotplug
// watcher runs for the whole lock, a failed round without a PIN waits for udev
// before asking the probe, and a key plugged back in is offered to an empty
// field. The functions are lifted out of Service.qml and run against a stub
// root, the same way the other suites read the real source.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const test = require('node:test');

const source = fs.readFileSync(path.join(__dirname, '../Service.qml'), 'utf8');

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

// The `running:` binding of a Process, up to its `command:` line.
function runningBinding(id) {
  const at = source.indexOf('id: ' + id);
  assert(at >= 0, 'missing ' + id);
  const from = source.indexOf('running:', at) + 'running:'.length;
  return source.slice(from, source.indexOf('command:', from)).trim();
}

const FUNCTIONS = {
  handleFido2Finished: 'result',
  fido2FailureChecked: '',
  countFido2Failure: '',
  startFido2: '',
  retryFido2: '',
};

function context(extra = {}) {
  const c = {
    fido2Authenticating: true, fido2NeedsPin: false, enteredPassword: '',
    fido2RoundStarted: Date.now() - 100, lockRequested: true, screenBlanked: false,
    fido2PinSubmitted: false, fido2Cue: '', fido2TokenPresent: true,
    fido2Installed: true, fido2FailurePending: false, fido2TouchMisses: 0,
    failedAttempts: 0, fido2PinAttempts: 0, fido2PinAttemptLimit: 3,
    fido2NoTouchMs: 20000, fido2TouchRetryLimit: 3, authMode: 'fido2',
    fido2Configured: true, authModeSettled: true, authenticatingPassword: false,
    failureTimes: [], failureMessage: '', fido2Status: '', fido2ProbeQueued: false,
    keyEventProbe: false, keyInsertProbe: false, lockOnKeyRemoval: false,
    wakeOnKeyInsert: false, passwordPamConfigured: true, locked: true,
    retries: 0, probes: 0, rounds: 0, wakes: 0, unlocked: false,
    Qt: { callLater(fn) { fn() } },
    PamResult: { Success: 0, Failed: 1, Error: 2 },
    sessionLock: { secure: true },
    fido2Pam: { active: false, start() { c.rounds++; return true } },
    setAuthMode(mode) {
      if (c.authMode !== mode) { c.authMode = mode; c.failureMessage = ''; c.enteredPassword = '' }
      c.authModeSettled = true
    },
    settleAuthMode() {}, finishUnlock() { c.unlocked = true }, logEvent() {},
    runWake() { c.wakes++; c.screenBlanked = false }, beginLock() {},
    refreshFido2Status() { c.probes++ },
    ...extra,
  };
  Object.defineProperty(c, 'fido2Active', { get: () => c.authMode === 'fido2' });
  Object.defineProperty(c, 'fido2Exhausted', { get: () => c.fido2PinAttempts >= c.fido2PinAttemptLimit });
  c.fido2RetryTimer = { restart() { c.retries++ } };
  c.fido2FailureSettle = { running: false, restart() { this.running = true }, stop() { this.running = false } };
  c.fido2CheckProc = { running: false };
  c.fido2CheckStdout = { text: '' };
  c.root = c;
  vm.createContext(c);
  vm.runInContext('function t(text) { return text }; String.prototype.arg = function(v) { return this.replace("%1", v) };', c);
  for (const [name, args] of Object.entries(FUNCTIONS))
    vm.runInContext(`function ${name}(${args}) {${bodyAfter('function ' + name + '(')}}`, c);
  return c;
}

const probeBody = bodyAfter('onExited:', source.indexOf('id: fido2CheckProc'));
function probeAnswers(c, present) {
  c.fido2CheckStdout.text = 'yes ' + (present ? 'present' : 'absent');
  vm.runInContext('(function(){' + probeBody + '})()', c);
}
// The settle timer firing, then its probe answering.
function settle(c, present) {
  c.fido2FailureSettle.running = false;
  probeAnswers(c, present);
}

test('wake and retry recheck presence instead of trusting the last answer', () => {
  const c = context({ fido2Authenticating: false, fido2TouchMisses: 2 });
  c.retryFido2();
  assert.equal(c.probes, 1);
  assert.equal(c.rounds, 0);
  assert.equal(c.fido2TouchMisses, 0);
});

test('a key gone while asleep is found by the wake probe, not charged', () => {
  const c = context({ fido2Authenticating: false });
  c.retryFido2();
  probeAnswers(c, false);
  assert.equal(c.rounds, 0);
  assert.equal(c.failedAttempts, 0);
  assert.equal(c.fido2Status, 'No security key found');
  assert.equal(c.authMode, 'fido2');
});

test('a failed round without a PIN waits for the settle before probing', () => {
  const c = context({ fido2Cue: 'Touch your security key' });
  c.handleFido2Finished(1);
  assert.equal(c.fido2FailurePending, true);
  assert.equal(c.fido2FailureSettle.running, true);
  assert.equal(c.probes, 0);
  assert.equal(c.failedAttempts, 0);
});

test('a probe that lands inside the settle window does not decide the failure', () => {
  const c = context({ fido2Cue: 'Touch your security key' });
  c.handleFido2Finished(1);
  probeAnswers(c, true);
  assert.equal(c.fido2FailurePending, true);
  assert.equal(c.failedAttempts, 0);
  settle(c, false);
  assert.equal(c.fido2FailurePending, false);
  assert.equal(c.failedAttempts, 0);
});

test('a key pulled mid-round keeps the no-key state from #53', () => {
  const c = context({ fido2Cue: 'Touch your security key' });
  c.handleFido2Finished(1);
  settle(c, false);
  assert.equal(c.authMode, 'fido2');
  assert.equal(c.fido2Status, 'No security key found');
  assert.equal(c.fido2TouchMisses, 0);
  assert.equal(c.failureMessage, '');
});

test('a real miss with the key still attached is counted', () => {
  const c = context({ fido2Cue: 'Touch your security key' });
  c.handleFido2Finished(1);
  settle(c, true);
  assert.equal(c.failedAttempts, 1);
  assert.equal(c.fido2TouchMisses, 1);
  assert.equal(c.retries, 1);
});

test('three real misses still hand over the password', () => {
  const c = context({ fido2Cue: 'Touch your security key' });
  for (let i = 0; i < 3; i++) {
    c.fido2Authenticating = true;
    c.handleFido2Finished(1);
    settle(c, true);
  }
  assert.equal(c.authMode, 'password');
  assert.equal(c.failureMessage, 'Too many tries');
});

test('a PIN failure is charged at once, without waiting', () => {
  const c = context({ fido2PinSubmitted: true });
  c.handleFido2Finished(1);
  assert.equal(c.fido2FailurePending, false);
  assert.equal(c.fido2PinAttempts, 1);
  assert.equal(c.fido2FailureSettle.running, false);
});

test('only a PAM success unlocks', () => {
  const c = context({ fido2Cue: 'Touch your security key' });
  c.handleFido2Finished(1);
  settle(c, false);
  assert.equal(c.unlocked, false);
  c.fido2Authenticating = true;
  c.handleFido2Finished(0);
  assert.equal(c.unlocked, true);
});

for (const [name, extra, mode] of [
  ['an empty password field', {}, 'fido2'],
  ['a partly typed password', { enteredPassword: 'hunter' }, 'password'],
  ['a password check in flight', { authenticatingPassword: true }, 'password'],
  ['a key at its PIN limit', { fido2PinAttempts: 3 }, 'password'],
]) {
  test('a key plugged back in with ' + name + ' leaves the lock on ' + mode, () => {
    const c = context({ authMode: 'password', fido2Authenticating: false, fido2TokenPresent: false, fido2TouchMisses: 3, ...extra });
    probeAnswers(c, true);
    assert.equal(c.authMode, mode);
    if (mode === 'fido2') {
      assert.equal(c.fido2TouchMisses, 0);
      assert.equal(c.rounds, 1);
    }
  });
}

test('a key already attached is not re-offered after the user picked the password', () => {
  const c = context({ authMode: 'password', fido2Authenticating: false, fido2TokenPresent: true });
  probeAnswers(c, true);
  assert.equal(c.authMode, 'password');
});

function binding(id, state) {
  const c = { ...state };
  c.root = c;
  vm.createContext(c);
  return vm.runInContext(runningBinding(id), c);
}

const locked = {
  lockRequested: true, fido2Configured: true, fido2Exhausted: false,
  fido2TokenPresent: true, fido2Authenticating: true, authenticatingPassword: false,
  enteredPassword: 'abc', authModeSettled: true, fido2Active: false,
  lockOnKeyRemoval: true, wakeOnKeyInsert: false, screenBlanked: false,
};

test('the hotplug watcher runs for the whole lock, key present or not', () => {
  assert.equal(binding('fido2HotplugWatch', locked), true);
  assert.equal(binding('fido2HotplugWatch', { ...locked, lockRequested: false }), false);
  assert.equal(binding('fido2HotplugWatch', { ...locked, fido2Exhausted: true }), false);
  assert.equal(binding('fido2HotplugWatch', { ...locked, fido2Exhausted: true, wakeOnKeyInsert: true }), true);
});

test('the removal watcher only runs unlocked, so the two never overlap', () => {
  assert.equal(binding('keyEventWatch', locked), false);
  assert.equal(binding('keyEventWatch', { ...locked, lockRequested: false }), true);
  assert.equal(binding('keyEventWatch', { ...locked, lockRequested: false, lockOnKeyRemoval: false }), false);
});
