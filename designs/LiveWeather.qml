import QtQuick
import Quickshell
import Quickshell.Io

// Current weather for the designer's Weather piece, from wttr.in for the place
// set in Omarchy's weather settings. The answer is kept for half an hour in the
// runtime dir, one file per language, and a lock taken around the fetch makes
// every other piece (the explorer's thumbnails, a second monitor) wait for it
// and read that file instead of asking again.
Item {
  id: weather
  property var lock: null
  readonly property string language: lock && lock.language ? String(lock.language) : "en"

  property string locationQuery: ""
  property var report: null
  property bool loading: true
  property bool failed: false

  readonly property var current: report && report.current_condition && report.current_condition.length ? report.current_condition[0] : null
  readonly property string tempC: current ? current.temp_C + "°" : ""
  readonly property string tempF: current ? current.temp_F + "°" : ""
  // wttr.in puts the translated description under lang_<code>.
  readonly property string condition: {
    if (!current) return ""
    var own = current["lang_" + language]
    if (own && own.length && own[0].value) return String(own[0].value)
    return current.weatherDesc && current.weatherDesc.length ? String(current.weatherDesc[0].value) : ""
  }
  readonly property string place: report && report.nearest_area && report.nearest_area.length && report.nearest_area[0].areaName
    ? String(report.nearest_area[0].areaName[0].value) : ""
  readonly property string glyph: current ? glyphFor(current.weatherCode) : "󰖐"

  function glyphFor(code) {
    var c = parseInt(code || "0")
    if (c === 113) return "󰖙"
    if (c === 116) return "󰖕"
    if (c === 119 || c === 122) return "󰖐"
    if (c === 143 || c === 248 || c === 260) return "󰖑"
    if ([200, 386, 389, 392].indexOf(c) !== -1) return "󰖓"
    if ([179, 227, 230, 323, 326, 329, 332, 335, 338, 368, 371, 395].indexOf(c) !== -1) return "󰖘"
    if ([182, 185, 281, 284, 311, 314, 317, 320, 350, 362, 365, 374, 377].indexOf(c) !== -1) return "󰙿"
    if ([305, 308, 356, 359].indexOf(c) !== -1) return "󰖖"
    if (c >= 176) return "󰖗"
    return "󰖐"
  }

  // As in the Weather design: a j1 answer is a few tens of kilobytes, and
  // anything reaching this cap is refused rather than parsed.
  readonly property int responseCap: 262144
  // The per-user runtime dir, and nothing shared: without one every piece
  // fetches for itself instead of caching.
  readonly property string cacheDir: Quickshell.env("XDG_RUNTIME_DIR") || ""

  function refresh() {
    if (!fetchProc.running && locationKnown) fetchProc.running = true
  }
  property bool locationKnown: false

  FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/settings/weather.json"
    printErrors: false
    onLoaded: {
      try {
        var d = JSON.parse(text())
        var lat = parseFloat(d.latitude), lon = parseFloat(d.longitude)
        if (!isNaN(lat) && !isNaN(lon)) weather.locationQuery = lat + "," + lon
        else if (d.name) weather.locationQuery = encodeURIComponent(d.name)
      } catch (e) {}
      weather.locationKnown = true
      weather.refresh()
    }
    onLoadFailed: { weather.locationKnown = true; weather.refresh() }
  }

  onLanguageChanged: refresh()

  Process {
    id: fetchProc
    // Everything the script needs travels as arguments: the URL, the cap and
    // the cache file (keyed by place and language).
    command: ["bash", "-c",
      'set -o pipefail; c="$3"; '
      + 'if [ -z "$c" ]; then curl -fsS --max-time 15 --max-filesize "$2" "$1" | head -c "$2"; exit; fi; '
      + 'exec 9>"$c.lock"; flock -w 30 9 || true; '
      + 'if [ -s "$c" ] && [ $(( $(date +%s) - $(stat -c %Y "$c") )) -lt 1800 ]; then cat "$c"; exit 0; fi; '
      + 'curl -fsS --max-time 15 --max-filesize "$2" "$1" | head -c "$2" > "$c.part" && mv -f "$c.part" "$c" && cat "$c"',
      "weather", "https://wttr.in/" + weather.locationQuery + "?format=j1&lang=" + weather.language, String(weather.responseCap),
      weather.cacheDir.length > 0
        ? weather.cacheDir + "/omarchy-lock-explorer-weather-" + Qt.md5(weather.locationQuery + "|" + weather.language) + ".json" : ""]
    stdout: StdioCollector { id: fetchOut; waitForEnd: true }
    onExited: function(code) {
      var body = String(fetchOut.text || "")
      var ok = false
      if (code === 0 && body.length > 0 && body.length < weather.responseCap) {
        try { weather.report = JSON.parse(body); ok = true } catch (e) {}
      }
      weather.failed = !ok
      weather.loading = false
      if (!ok && !weather.retried) { weather.retried = true; retryTimer.start() }
    }
  }
  property bool retried: false
  Timer { id: retryTimer; interval: 20000; onTriggered: weather.refresh() }
  Timer { interval: 30 * 60 * 1000; running: true; repeat: true; onTriggered: weather.refresh() }
}
