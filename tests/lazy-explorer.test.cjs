// The explorer is built on first use, not at shell start (issue #91): the
// manifest's overlay is ExplorerHost.qml, which holds the calls and service
// requests that come before the explorer exists and replays them, in order,
// to the handlers in Explorer.qml.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const test = require('node:test');

const read = (f) => fs.readFileSync(path.join(__dirname, '..', f), 'utf8');
const host = read('ExplorerHost.qml');
const explorer = read('Explorer.qml');

function functionSource(source, name) {
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

test('the overlay entry is the host, not the explorer', () => {
  const manifest = JSON.parse(read('manifest.json'));
  assert.equal(manifest.entryPoints.overlay, 'ExplorerHost.qml');
  assert.match(host, /source: "Explorer\.qml"/);
  assert.match(host, /active: false/);
});

test('every request the host holds has a handler in the explorer', () => {
  const held = [...host.matchAll(/event: "(on[A-Za-z]+)"/g)].map((m) => m[1]);
  assert(held.length >= 5);
  const at = explorer.indexOf('id: serviceEvents');
  assert(at >= 0, 'Explorer.qml has no serviceEvents');
  const block = explorer.slice(at, explorer.indexOf('\n  }\n', at));
  for (const name of held) assert.match(block, new RegExp('function ' + name + '\\('), name);
});

function hostContext() {
  const c = {
    calls: [], loads: 0,
    explorer: { item: null, active: false },
    pending: [],
  };
  c.host = c;
  vm.createContext(c);
  for (const name of ['deliver', 'run', 'open', 'toggle', 'close'])
    vm.runInContext(functionSource(host, name), c);
  // What the Loader does once the explorer is built.
  c.finishLoad = () => {
    c.explorer.item = {
      opened: false,
      open(p) { c.calls.push('open ' + p) },
      toggle() { c.calls.push('toggle') },
      close() { c.calls.push('close') },
      replayServiceEvent(h, args) { c.calls.push(h + ' ' + args.join(',')) },
    };
    const queue = c.host.pending;
    c.host.pending = [];
    for (const e of queue) c.run(e);
  };
  return c;
}

test('nothing is built until it is needed, and early requests replay in order', () => {
  const c = hostContext();
  assert.equal(c.explorer.active, false);
  c.deliver({ event: 'onExploreTabRequested', args: ['settings'] });
  c.deliver({ event: 'onExploreViewRequested', args: ['full'] });
  c.open('{}');
  assert.equal(c.explorer.active, true);
  assert.deepEqual(c.calls, []);
  c.finishLoad();
  assert.deepEqual(c.calls, ['onExploreTabRequested settings', 'onExploreViewRequested full', 'open {}']);
  c.open('{}');
  assert.equal(c.calls.at(-1), 'open {}');
});

test('a close before the explorer is built drops the open it was waiting on', () => {
  const c = hostContext();
  c.deliver({ event: 'onBootResnapshotRequested', args: ['card', true] });
  c.open('{}');
  c.close();
  c.finishLoad();
  assert.deepEqual(c.calls, ['onBootResnapshotRequested card,true']);
});
