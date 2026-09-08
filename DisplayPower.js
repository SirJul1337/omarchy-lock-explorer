// Opt-in workaround for HDMI drivers that fail after locked display sleep.
function keepDisplaysOn(config, pluginId, screens) {
  var entries = config && Array.isArray(config.plugins) ? config.plugins : []
  var enabled = false
  for (var i = 0; i < entries.length; i++) {
    var entry = entries[i]
    if (entry && entry.id === pluginId && entry.keepDisplaysOnWithHdmi === true) enabled = true
  }
  if (!enabled) return false
  for (var j = 0; screens && j < screens.length; j++) {
    var screen = screens[j]
    if (screen && /^HDMI-A-[0-9]+$/.test(String(screen.name || ""))) return true
  }
  return false
}

if (typeof module !== "undefined") module.exports = { keepDisplaysOn: keepDisplaysOn }
