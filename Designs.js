.pragma library

var DEFAULT_ID = "card"

var CATEGORIES = [
  { id: "all", name: "All" },
  { id: "minimal", name: "Minimal" },
  { id: "cards", name: "Cards" },
  { id: "clock", name: "Clock" },
  { id: "type", name: "Typography" },
  { id: "dark", name: "Dark" },
  { id: "fun", name: "Fun" }
]

var DESIGNS = [
  { id: "card", file: "Card.qml", name: "Greeting Card", description: "Clock, avatar and greeting on a frosted card", tags: ["cards", "clock"] },
  { id: "classic", file: "Classic.qml", name: "Classic", description: "The stock Omarchy lock screen", tags: ["minimal"] },
  { id: "editorial", file: "Editorial.qml", name: "Editorial", description: "Big clock bottom left, field underneath", tags: ["type"] },
  { id: "zen", file: "Zen.qml", name: "Zen", description: "No input box, just type", tags: ["minimal"] },
  { id: "split", file: "Split.qml", name: "Split", description: "Wallpaper left, sign-in panel right", tags: ["cards"] },
  { id: "terminal", file: "Terminal.qml", name: "Terminal", description: "TTY style login prompt", tags: ["dark", "fun"] },
  { id: "ring", file: "Ring.qml", name: "Ring", description: "Progress ring around the clock fills as you type", tags: ["clock", "minimal"] },
  { id: "poster", file: "Poster.qml", name: "Poster", description: "Huge stacked hours and minutes", tags: ["type"] },
  { id: "dock", file: "Dock.qml", name: "Dock", description: "Everything in a slim bar at the bottom", tags: ["minimal"] },
  { id: "aurora", file: "Aurora.qml", name: "Aurora", description: "Slow moving color blobs, no wallpaper", tags: ["dark"] },
  { id: "analog", file: "Analog.qml", name: "Analog", description: "Analog clock face", tags: ["clock"] },
  { id: "flip", file: "Flip.qml", name: "Flip", description: "Flip clock tiles", tags: ["clock", "fun"] },
  { id: "island", file: "Island.qml", name: "Island", description: "Small pill at the top, wallpaper untouched", tags: ["minimal"] },
  { id: "cinema", file: "Cinema.qml", name: "Cinema", description: "Letterbox bars, subtitle style prompt", tags: ["fun", "type"] },
  { id: "sheet", file: "Sheet.qml", name: "Sheet", description: "Bottom sheet with the sign-in", tags: ["cards"] },
  { id: "neon", file: "Neon.qml", name: "Neon", description: "Glowing clock on a dark grid", tags: ["dark", "fun"] },
  { id: "calendar", file: "Calendar.qml", name: "Calendar", description: "Month view next to the clock", tags: ["clock", "cards"] },
  { id: "frame", file: "Frame.qml", name: "Frame", description: "Wallpaper in a photo mat", tags: ["cards"] },
  { id: "dayline", file: "Dayline.qml", name: "Dayline", description: "Progress bar for the day", tags: ["clock"] },
  { id: "profile", file: "Profile.qml", name: "Profile", description: "Big avatar, name and a pill field", tags: ["cards"] }
]

function all() { return DESIGNS }

function categories() { return CATEGORIES }

function inCategory(category) {
  if (!category || category === "all") return DESIGNS
  return DESIGNS.filter(function(d) { return (d.tags || []).indexOf(category) !== -1 })
}

function byId(id) {
  for (var i = 0; i < DESIGNS.length; i++) if (DESIGNS[i].id === id) return DESIGNS[i]
  return null
}

function indexOf(id) {
  for (var i = 0; i < DESIGNS.length; i++) if (DESIGNS[i].id === id) return i
  return -1
}

function resolve(id) {
  return byId(id) || byId(DEFAULT_ID) || DESIGNS[0]
}
