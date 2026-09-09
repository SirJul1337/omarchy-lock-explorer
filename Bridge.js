// Shared between Service.qml and Explorer.qml so the explorer can reach its
// own service on Omarchy 4.0.3+, where the host no longer hands authentication
// services (which a clone of omarchy.lock is) to the plugin's own overlay.
//
// `.pragma library` makes this one instance per QML engine, so both files see
// the same `api`. The service publishes a facade of itself here, never the
// service object itself: the facade carries the settings and design state the
// explorer draws from, and none of the PAM state or the typed password.
.pragma library

var api = null
var listeners = []

function publish(value) {
  api = value || null
  notify()
}

function unpublish(value) {
  if (api !== value) return
  api = null
  notify()
}

function current() {
  return api
}

function subscribe(fn) {
  if (typeof fn !== "function") return function() {}
  listeners.push(fn)
  return function() {
    var i = listeners.indexOf(fn)
    if (i !== -1) listeners.splice(i, 1)
  }
}

function notify() {
  var snapshot = listeners.slice()
  for (var i = 0; i < snapshot.length; i++) {
    try { snapshot[i](api) } catch (e) { console.warn("lock-explorer bridge listener failed: " + e) }
  }
}
