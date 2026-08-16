.pragma library

var DEFAULT_ID = "card"

var DESIGNS = [
  { id: "card", file: "Card.qml", name: "Greeting Card", description: "Clock, avatar and greeting on a frosted card" },
  { id: "classic", file: "Classic.qml", name: "Classic", description: "The stock Omarchy lock screen" },
  { id: "editorial", file: "Editorial.qml", name: "Editorial", description: "Big clock bottom left, field underneath" },
  { id: "zen", file: "Zen.qml", name: "Zen", description: "No input box, just type" },
  { id: "split", file: "Split.qml", name: "Split", description: "Wallpaper left, sign-in panel right" },
  { id: "terminal", file: "Terminal.qml", name: "Terminal", description: "TTY style login prompt" }
]

function all() { return DESIGNS }

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
