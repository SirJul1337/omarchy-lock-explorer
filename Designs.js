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
  { id: "seasonal", name: "Seasonal" },
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
  // Work in progress, disabled so they do not load. Uncomment to bring them back.
  { id: "waves", file: "Waves.qml", name: "Waves", description: "Slow silk ribbons drift across the screen in your theme colors, and swell as you type", tags: ["dark", "reactive"], anim: true },
  { id: "clockwall", file: "ClockWall.qml", name: "Clock Wall", description: "A clock made of 24 little clocks whose hands draw the time", tags: ["clock", "fun"], anim: true },
  { id: "wordclock", file: "WordClock.qml", name: "Word Clock", description: "A grid of letters lights up the time in words, with four dots for the minutes", tags: ["clock", "type"], anim: true },
  { id: "ringwordclock", file: "RingWordClock.qml", name: "Ring Word Clock", description: "Hours, minutes and seconds on turning rings that line up as a sentence", tags: ["clock", "type"], anim: true },
  { id: "solclock", file: "SolClock.qml", name: "SolClock", description: "The time over concentric rings centred on a sun that circles the screen once a day", tags: ["clock", "dark"], anim: true },
  { id: "mazeclock", file: "MazeClock.qml", name: "Maze Clock", description: "A maze builds itself and then solves itself, with the time in a box in the middle", tags: ["clock", "fun"], anim: true },
  { id: "predator", file: "PredatorClock.qml", name: "Predator Clock", description: "The time as four glowing alien glyphs, like the countdown in the Predator films", tags: ["clock", "dark", "fun"], anim: true },
  { id: "lightspeed", file: "Lightspeed.qml", name: "Lightspeed", description: "Stars stretch into streaks as you jump to hyperspace", tags: ["reactive", "dark", "fun"], anim: true },
  { id: "terminator", file: "Terminator.qml", name: "Terminator", description: "Your wallpaper in red under a grid, with this machine's specs and live CPU and GPU, and a target box that closes in as you type", tags: ["dark", "fun", "reactive"], anim: true },
  // { id: "tracker", file: "Tracker.qml", name: "Motion Tracker", description: "Contacts creep in on a radar dial, every key sends another", tags: ["dark", "reactive"], anim: true },
  // { id: "circuits", file: "Circuits.qml", name: "Time Circuits", description: "Pick a destination and hit 88 mph, the password sets the speed", tags: ["clock", "fun", "reactive"], anim: true },
  // { id: "proton", file: "Proton.qml", name: "Proton Stream", description: "Braided proton streams crossing in a white hot knot", tags: ["reactive", "fun"], anim: true },
  // { id: "bullet", file: "Bullet.qml", name: "Bullet Time", description: "Every key fires a bullet through hanging glass in slow motion", tags: ["reactive", "dark"], anim: true },
  { id: "cipher", file: "Cipher.qml", name: "Cipher", description: "A block clock that decrypts itself, drawn by ttfx", tags: ["dark", "clock", "fun"], anim: true },
  { id: "screensaver", file: "Screensaver.qml", name: "Screensaver", description: "Your Omarchy logo through ttfx effects, like the screensaver", tags: ["dark", "fun"], anim: true },
  { id: "ember", file: "Ember.qml", name: "Ember", description: "The clock burns into place, drawn by ttfx", tags: ["dark", "clock"], anim: true },
  { id: "synthwave", file: "Synthwave.qml", name: "Synthwave", description: "A grid draws across the screen and dissolves into the clock", tags: ["dark", "fun"], anim: true },
  { id: "etch", file: "Etch.qml", name: "Etch", description: "A laser etches the greeting and time", tags: ["type", "fun"], anim: true },
  { id: "bounce", file: "Bounce.qml", name: "Bounce", description: "The clock rains down as bouncing balls", tags: ["fun", "clock"], anim: true },
  { id: "digital", file: "Digital.qml", name: "Digital", description: "Code rain that settles into the clock", tags: ["dark", "fun"], anim: true },
  { id: "spotlight", file: "Spotlight.qml", name: "Spotlight", description: "Spotlights search a dark stage and light up the time", tags: ["dark", "clock"], anim: true },
  { id: "fireworks", file: "Fireworks.qml", name: "Fireworks", description: "Fireworks burst and fall into the clock", tags: ["fun", "clock"], anim: true },
  { id: "vhs", file: "Vhs.qml", name: "VHS", description: "A paused tape with a clock that tracks badly", tags: ["fun", "type"], anim: true },
  { id: "horizon", file: "Horizon.qml", name: "Event Horizon", description: "The clock falls into a black hole and bursts back out", tags: ["dark", "fun"], anim: true },
  { id: "orbit", file: "Orbit.qml", name: "Orbit", description: "Launchers circle the screen and fire the clock in", tags: ["fun", "clock"], anim: true },
  { id: "binary", file: "Binary.qml", name: "Binary", description: "Streams of binary settle into the Omarchy logo", tags: ["dark", "fun"], anim: true },
  { id: "tracking", file: "Tracking.qml", name: "Tracking", description: "The Omarchy logo on a worn tape", tags: ["fun"], anim: true },
  { id: "login", file: "Login.qml", name: "Login", description: "The Omarchy logo next to a terminal prompt", tags: ["dark", "type"], anim: true },
  { id: "keycode", file: "Keycode.qml", name: "Keycode", description: "The Omarchy logo over a row of password cells", tags: ["dark", "minimal"], anim: true },
  { id: "statusline", file: "Statusline.qml", name: "Statusline", description: "An editor status bar with :unlock", tags: ["dark", "fun"], anim: true },
  { id: "forge", file: "Forge.qml", name: "Forge", description: "The Omarchy logo burns into place", tags: ["dark", "fun"], anim: true },
  { id: "mainframe", file: "Mainframe.qml", name: "Mainframe", description: "The Omarchy logo decrypts itself", tags: ["dark", "minimal"], anim: true },
  { id: "beacon", file: "Beacon.qml", name: "Beacon", description: "Beams light the Omarchy logo, then it pulses", tags: ["dark", "fun"], anim: true },
  { id: "supernova", file: "Supernova.qml", name: "Supernova", description: "The Omarchy logo bursts out of a black hole", tags: ["dark", "fun"], anim: true },
  { id: "core", file: "Core.qml", name: "Core", description: "Type into the middle of the Omarchy logo", tags: ["dark", "minimal"], anim: true },
  { id: "panel", file: "Panel.qml", name: "Panel", description: "The Omarchy logo cut out of an accent panel", tags: ["cards", "type"], anim: true },
  // clip: the design's video is held on its first frame while locked and plays
  // through as the unlock, see UnlockClip.qml. One clip per design.
  { id: "storm", file: "Storm.qml", name: "Storm", clip: true, description: "Calm ridge, the lightning is your unlock", tags: ["motion", "dark"], boot: true, bootKind: "clip", clipFile: "omarchy-storm.mp4", credit: "@yamzeight", anim: true },
  { id: "eyes", file: "Eyes.qml", name: "Eyes", clip: true, description: "The eyes open up when you get in", tags: ["motion", "dark"], boot: true, bootKind: "clip", clipFile: "omarchy-eye.mp4", credit: "@yamzeight", anim: true },
  { id: "river", file: "River.qml", name: "River", clip: true, description: "A painting that comes alive on unlock", tags: ["motion"], boot: true, bootKind: "clip", clipFile: "gruvbox-river.mp4", credit: "@yamzeight", anim: true },
  { id: "ticket", file: "Ticket.qml", name: "Ticket", description: "A boarding pass: the time departs, the password is the gate", tags: ["cards", "fun"] },
  { id: "marquee", file: "Marquee.qml", name: "Marquee", description: "Digits bigger than the screen, cut off at the bottom edge", tags: ["type"] },
  { id: "meridian", file: "Meridian.qml", name: "Meridian", description: "One line down the middle, time left, day right, field across", tags: ["minimal"] },
  { id: "blueprint", file: "Blueprint.qml", name: "Blueprint", description: "A drafting sheet: the time dimensioned, a title block, the sign-in as a detail", tags: ["type", "dark"] },
  { id: "receipt", file: "Receipt.qml", name: "Receipt", description: "The lock screen on till paper: date, time and user as the lines, the PIN to pay", tags: ["type", "fun", "cards"] },
  { id: "metro", file: "Metro.qml", name: "Metro", description: "The day as a transit line, a station an hour, the train where the time is", tags: ["clock", "type"] },
  { id: "seismograph", file: "Seismograph.qml", name: "Seismograph", description: "A strip chart that records every key; a wrong password is a quake", tags: ["reactive", "dark"], anim: true },
  // Seasonal: their own palettes, listed under the Seasonal nav.
  { id: "ghosts", file: "Ghosts.qml", name: "Ghosts", description: "Sheet ghosts drift over your wallpaper, eyes on the field, a BOO on a wrong password", tags: ["seasonal", "reactive"], anim: true },
  { id: "cobweb", file: "Cobweb.qml", name: "Cobweb", description: "A dewy web in the corner and a spider that comes down as you type", tags: ["seasonal", "dark", "reactive"], anim: true },
]

// Not listed in the explorer, used for monitors without input.
var HIDDEN = [
  { id: "companion", file: "Companion.qml", name: "Companion", description: "Clock only, for secondary monitors", tags: [] }
]

// Designs found in ~/.config/omarchy/lock-designs live on Service.userDesigns
// and are passed in. Module state here is not shared between importing files
// once the shell's load patch rewrites them, so it must not hold that list.
function all(user) { return DESIGNS.concat(user || []) }

// Lockscreen designs split into navs: static stylings, animated ones, and
// seasonal ones of either kind, which get a nav of their own instead of
// sitting among the rest.
function isAnimated(d) { return !!(d && (d.anim === true || d.clip === true)) }
function isSeasonal(d) { return !!(d && (d.tags || []).indexOf("seasonal") !== -1) }
function stylings(user) { return all(user).filter(function(d) { return !isAnimated(d) && !isSeasonal(d) }) }
function animations(user) { return all(user).filter(function(d) { return isAnimated(d) && !isSeasonal(d) }) }
function seasonal(user) { return all(user).filter(function(d) { return isSeasonal(d) }) }

function categories() { return CATEGORIES }

function inCategory(category, user) {
  if (!category || category === "all") return all(user)
  return all(user).filter(function(d) { return (d.tags || []).indexOf(category) !== -1 })
}

// Designs with a Plymouth twin in plymouth/<id>/, usable as the boot
// (LUKS decrypt) screen. Only built-in designs can carry one.
function bootCapable() {
  return DESIGNS.filter(function(d) { return d.boot === true })
}

function byId(id, user) {
  var list = all(user).concat(HIDDEN)
  for (var i = 0; i < list.length; i++) if (list[i].id === id) return list[i]
  return null
}

function indexOf(id, user) {
  var list = all(user)
  for (var i = 0; i < list.length; i++) if (list[i].id === id) return i
  return -1
}

function resolve(id, user) {
  return byId(id, user) || byId(DEFAULT_ID) || DESIGNS[0]
}

function fromUserFile(path) {
  var name = String(path).split("/").pop().replace(/\.qml$/, "")
  var id = "my-" + name.toLowerCase().replace(/[^a-z0-9]+/g, "-")
  var pretty = name.replace(/([a-z0-9])([A-Z])/g, "$1 $2").replace(/[-_]+/g, " ")
  return { id: id, name: pretty, description: "Custom design from ~/.config/omarchy/lock-designs", tags: ["custom"], path: "file://" + path }
}
