const assert = require("node:assert/strict");
const { test } = require("node:test");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const { spawn, spawnSync } = require("node:child_process");

// Every helper process the shell starts has a deadline, a cap on the output
// the shell takes in, and takes whatever it started down with it when it
// ends, however it ends. designs/Bounded.js does all three; this checks that
// no Process goes around it, and that it holds when actually run.

const root = path.join(__dirname, "..");
const read = (f) => fs.readFileSync(path.join(root, f), "utf8");
const B = {};
vm.runInNewContext(read("designs/Bounded.js").replace(/^\.pragma library\s*/, "") + "\nthis.run = run;", B);

// The watchers: they run as long as the lock or the explorer wants them, so
// no deadline, but a cap on every line they send.
const watchers = new Set(["fido2HotplugWatch", "keyEventWatch"]);

const qmlFiles = () => ["Service.qml", "Explorer.qml", "LockHost.qml", "ExplorerHost.qml", "SidePanel.qml"]
  .concat(fs.readdirSync(path.join(root, "designs")).filter((f) => f.endsWith(".qml")).map((f) => "designs/" + f))
  .filter((f) => fs.existsSync(path.join(root, f)));

test("every Process command goes through Bounded.run with a deadline", () => {
  let seen = 0;
  for (const f of qmlFiles()) {
    const src = read(f);
    for (const m of src.matchAll(/\bProcess \{/g)) {
      // The block up to the next Process, so a command is never credited to
      // the Process before it.
      const next = src.indexOf("Process {", m.index + 1);
      const block = src.slice(m.index, next === -1 ? m.index + 1200 : Math.min(next, m.index + 1200));
      const id = (block.match(/id:\s*(\w+)/) || [])[1] || "?";
      const inline = block.match(/\n\s*command:\s*(\S[^\n]*)/);
      const assigned = [...src.matchAll(new RegExp("\\b" + id + "\\.command\\s*=\\s*([^\\n]*)", "g"))].map((a) => a[1]);
      const commands = (inline ? [inline[1]] : []).concat(assigned);
      assert.ok(commands.length > 0, `${f}: ${id} has no command`);
      for (const c of commands) {
        assert.match(c, /^Bounded\.run\(/, `${f}: ${id} runs outside Bounded.run`);
        seen++;
      }
    }
  }
  assert.ok(seen >= 57, `only ${seen} commands found`);
});

test("only the watchers run without a deadline", () => {
  for (const f of qmlFiles()) {
    const src = read(f);
    for (const m of src.matchAll(/Bounded\.run\([\s\S]*?\{ deadline: (\d+)[^}]*\}\)/g)) {
      if (m[1] !== "0") continue;
      const before = src.slice(0, m.index);
      const id = [...before.matchAll(/id:\s*(\w+)/g)].pop()[1];
      assert.ok(watchers.has(id), `${f}: ${id} has no deadline`);
      assert.match(m[0], /line: \d+/, `${f}: ${id} needs a line cap`);
    }
  }
});

test("the ttfx stream caps a frame at the canvas height", () => {
  const src = read("designs/TtfxText.qml");
  assert.match(src, /var most = canvasRows \+ 2/);
  assert.equal((src.match(/frameRows\.length < most\) frameRows\.push/g) || []).length, 2);
});

test("root reads the theme under deadlines and caps", () => {
  const src = read("plymouth/install-root.sh");
  assert.match(src, /timeout -k 5 \d+ head -c "\$\(\(max_theme_bytes \+ 1\)\)" > "\$work\/theme\.tar"/);
  assert.match(src, /\( ulimit -f "\$\(\(max_list_bytes \/ 1024\)\)"\s*LC_ALL=C exec timeout -k 5 \d+ tar -tvf "\$work\/theme\.tar" > "\$work\/theme\.list" \) 2>&1 \\\s*\| head -c "\$max_err_bytes" > "\$work\/tar\.err" \|\| return 1/);
  assert.match(src, /timeout -k 5 \d+ tar -xmf[^\n]*\\\s*\n[^\n]*2>&1 \| head -c "\$max_err_bytes" > "\$work\/tar\.err" \|\| return 1/);
  // A process substitution leaves nothing to wait on under set -u.
  assert.doesNotMatch(src, /2> >\(|wait \$!/);
  assert.match(src, /trap '[^']*pkill -TERM -P \$\$[^']*' TERM HUP INT/);
});

// The rest runs the wrapper for real; it needs Linux with setpriv.
const linux = process.platform === "linux" && spawnSync("sh", ["-c", "command -v setpriv && command -v timeout && command -v stdbuf"]).status === 0;
const sh = (script, opts) => B.run(["bash", "-c", script], opts);
const runSync = (argv) => spawnSync(argv[0], argv.slice(1), { encoding: "utf8", timeout: 20000 });
const alive = (pid) => { try { process.kill(pid, 0); return true } catch { return false } };

test("a helper past its deadline is ended, with its children", { skip: !linux }, () => {
  const t0 = Date.now();
  const r = runSync(sh("sleep 60 & echo $!; wait", { deadline: 1, cap: 4096 }));
  assert.equal(r.status, 124);
  assert.ok(Date.now() - t0 < 6000);
  const child = Number(r.stdout.trim());
  assert.ok(child > 0 && !alive(child), "the background sleep outlived the deadline");
});

test("output past the cap fails the helper", { skip: !linux }, () => {
  const r = runSync(sh("yes x", { deadline: 10, cap: 1000 }));
  assert.notEqual(r.status, 0);
  assert.equal(r.stdout.length, 1000);
  const ok = runSync(sh("printf hello", { deadline: 10, cap: 1000 }));
  assert.equal(ok.status, 0);
  assert.equal(ok.stdout, "hello");
});

test("a stream keeps its lines but not past the line cap", { skip: !linux }, () => {
  const r = runSync(sh("printf 'short\\n'; head -c 5000 /dev/zero | tr '\\0' a; echo", { deadline: 10, line: 100 }));
  assert.equal(r.status, 0);
  const lines = r.stdout.split("\n");
  assert.equal(lines[0], "short");
  assert.equal(lines[1].length, 100);
});

test("exit codes come through", { skip: !linux }, () => {
  assert.equal(runSync(sh("exit 3", { deadline: 5, cap: 100 })).status, 3);
  assert.equal(runSync(sh("exit 2", { deadline: 5 })).status, 2);
});

const shapes = { "no cap": { deadline: 30 }, "a cap": { deadline: 30, cap: 1000 }, "a line cap": { deadline: 0, line: 100 } };
for (const sig of ["SIGTERM", "SIGKILL"]) for (const [shape, opts] of Object.entries(shapes)) {
  test(`a helper with ${shape} stopped with ${sig} takes its children with it`, { skip: !linux }, async () => {
    // The pid goes to a file: under a cap, head holds stdout until the end.
    const file = path.join(require("node:os").tmpdir(), `bounded-${process.pid}-${sig}-${shape.replace(/ /g, "")}`);
    fs.rmSync(file, { force: true });
    const argv = sh(`sleep 60 & echo $! > '${file}'; wait`, opts);
    const p = spawn(argv[0], argv.slice(1), { stdio: "ignore" });
    for (let i = 0; i < 50 && !(fs.existsSync(file) && fs.readFileSync(file, "utf8").trim()); i++) await new Promise((r) => setTimeout(r, 100));
    const child = Number(fs.readFileSync(file, "utf8").trim());
    fs.rmSync(file, { force: true });
    assert.ok(alive(child));
    p.kill(sig);
    for (let i = 0; i < 50 && alive(child); i++) await new Promise((r) => setTimeout(r, 100));
    assert.ok(!alive(child), `the background sleep outlived ${sig}`);
  });
}
