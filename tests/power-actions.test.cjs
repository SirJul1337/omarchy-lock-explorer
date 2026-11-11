// Lock screen power buttons: Restart and Shutdown run Omarchy's own command
// for the action. Omarchy 4.5 replaced the standalone omarchy-system-reboot
// and omarchy-system-shutdown scripts with `omarchy-system <action>`, so the
// command runPowerAction hands to execDetached is run here against a PATH that
// has only one layout or the other, and must reach the script that exists.
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const vm = require('node:vm');
const { spawnSync } = require('node:child_process');
const assert = require('node:assert/strict');
const test = require('node:test');

const source = fs.readFileSync(path.join(__dirname, '../Service.qml'), 'utf8');

function functionSource(name) {
  const at = source.indexOf('function ' + name + '(');
  assert(at >= 0, 'missing ' + name);
  const open = source.indexOf('{', at);
  let depth = 1, end = open + 1;
  for (; depth; end++) {
    if (source[end] === '{') depth++;
    if (source[end] === '}') depth--;
  }
  return source.slice(at, end);
}

// The argv runPowerAction would start, with the setting on.
function commandFor(action) {
  const c = {
    powerActions: true, started: [], events: [],
    Quickshell: { execDetached(argv) { c.started.push(argv) } },
    logEvent(e) { c.events.push(e) },
  };
  vm.createContext(c);
  vm.runInContext(functionSource('runPowerAction') + '\nthis.result = runPowerAction(' + JSON.stringify(action) + ')', c);
  assert.equal(c.result, true);
  assert.equal(c.started.length, 1);
  return JSON.parse(JSON.stringify(c.started[0]));
}

// The command is a bash one-liner run on the user's machine; it is run the same
// way here, on Linux only (on Windows `bash` may be WSL's, with another PATH).
const linux = process.platform === 'linux';

// Runs argv with PATH holding only stub scripts; returns what they recorded.
function runWith(argv, stubs) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'power-'));
  const log = path.join(dir, 'ran');
  for (const name of stubs) {
    const p = path.join(dir, name);
    fs.writeFileSync(p, '#!/bin/sh\necho "' + name + ' $*" >> "' + log.replace(/\\/g, '/') + '"\n');
    fs.chmodSync(p, 0o755);
  }
  // PATH is the stub directory alone: the real omarchy-system may live in
  // /usr/bin, and reaching it here would reboot the machine running the test.
  const bashPath = spawnSync('sh', ['-c', 'command -v bash'], { encoding: 'utf8' }).stdout.trim();
  assert.equal(argv[0], 'bash');
  const res = spawnSync(bashPath, argv.slice(1), {
    encoding: 'utf8',
    env: { PATH: dir },
  });
  const ran = fs.existsSync(log) ? fs.readFileSync(log, 'utf8').trim() : '';
  fs.rmSync(dir, { recursive: true, force: true });
  return { status: res.status, ran };
}

for (const action of ['reboot', 'shutdown']) {
  test(action + ' runs `omarchy-system ' + action + '` where Omarchy 4.5 ships only that', { skip: !linux }, () => {
    const r = runWith(commandFor(action), ['omarchy-system']);
    assert.equal(r.ran, 'omarchy-system ' + action);
  });

  test(action + ' still runs the standalone script on an older Omarchy', { skip: !linux }, () => {
    const r = runWith(commandFor(action), ['omarchy-system-' + action]);
    assert.equal(r.ran, 'omarchy-system-' + action);
  });
}

test('suspend is systemctl, and nothing runs with the setting off', () => {
  assert.deepEqual(commandFor('suspend'), ['systemctl', 'suspend']);
  const c = { powerActions: false, started: [], Quickshell: { execDetached(a) { c.started.push(a) } }, logEvent() {} };
  vm.createContext(c);
  vm.runInContext(functionSource('runPowerAction') + '\nthis.result = runPowerAction("reboot")', c);
  assert.equal(c.result, false);
  assert.equal(c.started.length, 0);
});
