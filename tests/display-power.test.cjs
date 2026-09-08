const assert = require("node:assert/strict");
const { test } = require("node:test");
const { keepDisplaysOn } = require("../DisplayPower.js");
const id = "io.github.sirjul1337.lock-explorer";
const enabled = {plugins: [{id, keepDisplaysOnWithHdmi: true}]};
const hdmi = [{name: "eDP-1"}, {name: "HDMI-A-1"}];
const cases = [
  ["missing config preserves blanking", null, id, hdmi, false],
  ["missing option preserves blanking", {plugins: [{id}]}, id, hdmi, false],
  ["false preserves blanking", {plugins: [{id, keepDisplaysOnWithHdmi: false}]}, id, hdmi, false],
  ["string true does not enable option", {plugins: [{id, keepDisplaysOnWithHdmi: "true"}]}, id, hdmi, false],
  ["another plugin cannot enable option", enabled, "another.lock", hdmi, false],
  ["missing screen list", enabled, id, null, false],
  ["empty screen list", enabled, id, [], false],
  ["internal display alone blanks", enabled, id, [{name: "eDP-1"}], false],
  ["DisplayPort alone blanks", enabled, id, [{name: "DP-1"}], false],
  ["HDMI with internal display stays lit", enabled, id, hdmi, true],
  ["HDMI alone stays lit", enabled, id, [{name: "HDMI-A-2"}], true],
  ["placeholder screens do not inhibit blanking", enabled, id, [null, {name: ""}], false],
];
for (const [name, config, plugin, screens, expected] of cases) {
  test(name, () => assert.equal(keepDisplaysOn(config, plugin, screens), expected));
}
test("disconnect restores policy and reconnect suppresses it again", () => {
  assert.equal(keepDisplaysOn(enabled, id, hdmi), true);
  assert.equal(keepDisplaysOn(enabled, id, [{name: "eDP-1"}]), false);
  assert.equal(keepDisplaysOn(enabled, id, hdmi), true);
});
