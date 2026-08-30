.pragma library

var DEFAULT_ID = "card"

var CATEGORIES = [
  { id: "all", name: "All" },
  { id: "minimal", name: "Minimal" },
  { id: "cards", name: "Cards" },
  { id: "clock", name: "Clock" },
  { id: "type", name: "Typography" },
  { id: "dark", name: "Dark" },
  { id: "fun", name: "Fun" },
  { id: "motion", name: "Motion" },
  { id: "reactive", name: "Reactive" },
  { id: "custom", name: "Custom" }
]

var DESIGNS = [
  { id: "card", file: "Card.qml", name: "Greeting Card", description: "Clock, avatar and greeting on a frosted card", tags: ["cards", "clock"] },
  { id: "classic", file: "Classic.qml", name: "Classic", description: "The stock Omarchy lock screen", tags: ["minimal"] },
  { id: "editorial", file: "Editorial.qml", name: "Editorial", description: "Big clock bottom left, field underneath", tags: ["type"] },
  { id: "zen", file: "Zen.qml", name: "Zen", description: "No input box, just type", tags: ["minimal"] },
  { id: "split", file: "Split.qml", name: "Split", description: "Wallpaper left, sign-in panel right", tags: ["cards"] },
  { id: "terminal", file: "Terminal.qml", name: "Terminal", description: "TTY style login prompt", tags: ["dark", "fun"], boot: true, bootKind: "styling" },
  { id: "ring", file: "Ring.qml", name: "Ring", description: "Progress ring around the clock fills as you type", tags: ["clock", "minimal"] },
  { id: "poster", file: "Poster.qml", name: "Poster", description: "Huge stacked hours and minutes", tags: ["type"] },
  { id: "dock", file: "Dock.qml", name: "Dock", description: "Everything in a slim bar at the bottom", tags: ["minimal"] },
  { id: "aurora", file: "Aurora.qml", name: "Aurora", description: "Slow moving color blobs, no wallpaper", tags: ["dark"], anim: true },
  { id: "analog", file: "Analog.qml", name: "Analog", description: "Analog clock face", tags: ["clock"], anim: true },
  { id: "flip", file: "Flip.qml", name: "Flip", description: "Flip clock tiles", tags: ["clock", "fun"], anim: true },
  { id: "island", file: "Island.qml", name: "Island", description: "Small pill at the top, wallpaper untouched", tags: ["minimal"] },
  { id: "cinema", file: "Cinema.qml", name: "Cinema", description: "Letterbox bars, subtitle style prompt", tags: ["fun", "type"] },
  { id: "sheet", file: "Sheet.qml", name: "Sheet", description: "Bottom sheet with the sign-in", tags: ["cards"] },
  { id: "neon", file: "Neon.qml", name: "Neon", description: "Glowing clock on a dark grid", tags: ["dark", "fun"], anim: true },
  { id: "calendar", file: "Calendar.qml", name: "Calendar", description: "Month view next to the clock", tags: ["clock", "cards"] },
  { id: "frame", file: "Frame.qml", name: "Frame", description: "Wallpaper in a photo mat", tags: ["cards"] },
  { id: "dayline", file: "Dayline.qml", name: "Dayline", description: "Progress bar for the day", tags: ["clock"] },
  { id: "profile", file: "Profile.qml", name: "Profile", description: "Big avatar, name and a pill field", tags: ["cards"] },
  { id: "weather", file: "Weather.qml", name: "Weather", description: "Current weather and 3 day forecast next to the clock", tags: ["cards", "clock"] },
  { id: "music", file: "Music.qml", name: "Music", description: "What is playing, with cover art", tags: ["cards", "fun"] },
  { id: "system", file: "System.qml", name: "System", description: "Uptime, memory, load and battery tiles", tags: ["cards", "dark"] },
  { id: "rain", file: "Rain.qml", name: "Rain", description: "Falling glyphs, you know the movie", tags: ["dark", "fun"], anim: true },
  { id: "motion", file: "Motion.qml", name: "Motion", description: "Your video looping behind the clock", tags: ["motion", "clock"], anim: true },
  { id: "pond", file: "Pond.qml", name: "Pond", description: "Keystrokes ripple across the screen", tags: ["reactive", "clock"], anim: true },
  { id: "constellation", file: "Constellation.qml", name: "Constellation", description: "Your typing draws a constellation", tags: ["reactive", "dark"], anim: true },
  { id: "sparks", file: "Sparks.qml", name: "Sparks", description: "The field throws embers as you type", tags: ["reactive", "fun"], anim: true },
  // clip: the design's video is held on its first frame while locked and plays
  // through as the unlock, see UnlockClip.qml. One clip per design.
  { id: "storm", file: "Storm.qml", name: "Storm", clip: true, description: "Calm ridge, the lightning is your unlock", tags: ["motion", "dark"], boot: true, bootKind: "clip", clipFile: "omarchy-storm.mp4", credit: "@yamzeight", anim: true },
  { id: "eyes", file: "Eyes.qml", name: "Eyes", clip: true, description: "The eyes open up when you get in", tags: ["motion", "dark"], boot: true, bootKind: "clip", clipFile: "omarchy-eye.mp4", credit: "@yamzeight", anim: true },
  { id: "river", file: "River.qml", name: "River", clip: true, description: "A painting that comes alive on unlock", tags: ["motion"], boot: true, bootKind: "clip", clipFile: "gruvbox-river.mp4", credit: "@yamzeight", anim: true }
]

var USER = []

// Not listed in the explorer, used for monitors without input.
var HIDDEN = [
  { id: "companion", file: "Companion.qml", name: "Companion", description: "Clock only, for secondary monitors", tags: [] }
]

// Designs found in ~/.config/omarchy/lock-designs, set by Service.qml.
function setUser(list) { USER = list || [] }

function all() { return DESIGNS.concat(USER) }

// Lockscreen designs split into two navs: static stylings vs animated ones.
function isAnimated(d) { return !!(d && (d.anim === true || d.clip === true)) }
function stylings() { return all().filter(function(d) { return !isAnimated(d) }) }
function animations() { return all().filter(function(d) { return isAnimated(d) }) }

function categories() { return CATEGORIES }

function inCategory(category) {
  if (!category || category === "all") return all()
  return all().filter(function(d) { return (d.tags || []).indexOf(category) !== -1 })
}

// Designs with a Plymouth twin in plymouth/<id>/, usable as the boot
// (LUKS decrypt) screen. Only built-in designs can carry one.
function bootCapable() {
  return DESIGNS.filter(function(d) { return d.boot === true })
}

function byId(id) {
  var list = all().concat(HIDDEN)
  for (var i = 0; i < list.length; i++) if (list[i].id === id) return list[i]
  return null
}

function indexOf(id) {
  var list = all()
  for (var i = 0; i < list.length; i++) if (list[i].id === id) return i
  return -1
}

function resolve(id) {
  return byId(id) || byId(DEFAULT_ID) || DESIGNS[0]
}

function fromUserFile(path) {
  var name = String(path).split("/").pop().replace(/\.qml$/, "")
  var id = "my-" + name.toLowerCase().replace(/[^a-z0-9]+/g, "-")
  var pretty = name.replace(/([a-z0-9])([A-Z])/g, "$1 $2").replace(/[-_]+/g, " ")
  return { id: id, name: pretty, description: "Custom design from ~/.config/omarchy/lock-designs", tags: ["custom"], path: "file://" + path }
}
