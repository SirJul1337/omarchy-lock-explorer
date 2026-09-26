import QtQuick
import QtQuick.Effects
import qs.Commons

// One piece of a design made in the visual designer. The designer's canvas and
// the generated design file both render through this, so what you arrange is
// exactly what the lock screen draws.
//
// `spec` carries the settings for the kind (see Designer.js for the list). It
// is read through p(), which keeps every binding depending on `spec` as a
// whole — the designer hands over a fresh object on each edit and the piece
// repaints.
Item {
  id: piece
  function tr(text) { return lock && typeof lock.tr === "function" ? lock.tr(text) : text }

  property var lock: null
  property string kind: "label"
  property var spec: ({})

  function p(key, fallback) {
    if (spec && spec[key] !== undefined && spec[key] !== null) return spec[key]
    return fallback
  }

  // Only the designer's canvas sets this: it holds the "Custom QML" snippet
  // as text and builds it here. A generated design file carries the same
  // snippet inline as a child instead, where `lock` resolves to the design —
  // exactly what it resolves to in here.
  property string customQml: ""
  property string customError: ""
  property Item customItem: null

  onCustomQmlChanged: rebuildCustom()
  Component.onCompleted: if (customQml.length > 0) rebuildCustom()

  function rebuildCustom() {
    if (customItem) { customItem.destroy(); customItem = null }
    customError = ""
    if (kind !== "custom" || customQml.length === 0) return
    // QtMultimedia is offered to the snippet when it is installed. The import
    // line stays in both versions (commented out in the second), so the error
    // line numbers below hold either way.
    var imports = 'import QtQuick\n'
      + 'import QtQuick.Effects\n'
    var body = 'import qs.Commons\n'
      + 'import "' + Qt.resolvedUrl(".") + '"\n'
      + 'Item {\n  anchors.fill: parent\n' + customQml + '\n}'
    try {
      try {
        customItem = Qt.createQmlObject(imports + 'import QtMultimedia\n' + body, piece)
      } catch (withMultimedia) {
        var reason = String(withMultimedia) + (withMultimedia.qmlErrors || [])
          .map(function(err) { return err.message }).join("\n")
        if (reason.indexOf('"QtMultimedia" is not installed') === -1) throw withMultimedia
        customItem = Qt.createQmlObject(imports + '// QtMultimedia is not installed\n' + body, piece)
      }
    } catch (e) {
      var msg = String(e)
      if (e.qmlErrors && e.qmlErrors.length)
        msg = e.qmlErrors.map(function(err) { return "line " + (err.lineNumber - 6) + ": " + err.message }).join("\n")
      customError = msg
    }
  }

  Text {
    anchors.centerIn: parent
    width: parent.width
    visible: piece.customError.length > 0
    text: piece.customError
    textFormat: Text.PlainText
    color: Color.lock.textError
    font.family: Style.font.family
    font.pixelSize: 13
    wrapMode: Text.Wrap
    maximumLineCount: 4
    elide: Text.ElideRight
    horizontalAlignment: Text.AlignHCenter
  }

  // Set from the layout: 0 means "size yourself from your content", which is
  // what the text pieces do. `fillParent` is for the full-screen backgrounds.
  property int fixedWidth: 0
  property int fixedHeight: 0
  property bool fillParent: false

  // Where the password goes, for `inputItem` on the design. Null for
  // everything that is not an input.
  readonly property Item inputItem: (loader.item && loader.item.field !== undefined) ? loader.item.field : null

  readonly property bool isText: kind === "clock" || kind === "date" || kind === "greeting"
    || kind === "label" || kind === "username" || kind === "hostname" || kind === "status"
    || kind === "weather" || kind === "media" || kind === "battery" || kind === "system"

  // The live pieces read their data from a source made only for them, so a
  // layout without a weather piece never asks for the weather.
  Loader {
    id: live
    active: sourceComponent !== null
    sourceComponent: {
      switch (piece.kind) {
      case "weather": return liveWeatherC
      case "media": case "art": return liveMediaC
      case "battery": return liveBatteryC
      case "system": return liveSystemC
      }
      return null
    }
  }
  readonly property var liveData: live.item
  Component { id: liveWeatherC; LiveWeather { lock: piece.lock } }
  Component { id: liveMediaC; LiveMedia {} }
  Component { id: liveBatteryC; LiveBattery {} }
  Component { id: liveSystemC; LiveSystem {} }

  implicitWidth: loader.item ? loader.item.implicitWidth : 0
  implicitHeight: loader.item ? loader.item.implicitHeight : 0
  width: (fillParent && parent) ? parent.width : (fixedWidth > 0 ? fixedWidth : implicitWidth)
  height: (fillParent && parent) ? parent.height
    : ((kind === "avatar" || kind === "art") ? width : (fixedHeight > 0 ? fixedHeight : implicitHeight))

  function roleColor(role) {
    var r = String(role || "text")
    if (r.charAt(0) === "#") return r
    switch (r) {
    case "accent": return Color.lock.borderActive
    case "error": return Color.lock.textError
    case "placeholder": return Color.lock.placeholder
    case "surface": return Color.lock.background
    case "background": return Color.background
    case "black": return "#000000"
    case "white": return "#ffffff"
    }
    return Color.lock.text
  }

  function tint(role, alpha) {
    var c = roleColor(role)
    return Qt.rgba(c.r, c.g, c.b, Math.max(0, Math.min(1, alpha === undefined ? 1 : alpha)))
  }

  // The words each text kind shows. Reads lock.now, so it ticks.
  function displayText() {
    if (!lock) return ""
    switch (kind) {
    case "clock": return lock.clock(String(p("format", "HH:mm")))
    case "date": return lock.date(String(p("format", "dddd, d MMMM")))
    case "greeting": return lock.greeting() + (p("withName", true) ? ", " + lock.displayName : "")
    case "username": return lock.displayName
    case "hostname": return lock.hostName
    case "status":
      if (lock.failureMessage.length > 0) return lock.failureMessage
      if (piece.fingerprintFailed) return lock.fingerprintStatus
      if (p("attempts", true) && lock.failedAttempts > 0)
        return tr(lock.failedAttempts === 1 ? "1 failed attempt" : "%1 failed attempts").arg(lock.failedAttempts)
      if (lock.authenticatingPassword) return tr("Checking…")
      if ((lock.fingerprintStatus || "").length > 0) return lock.fingerprintStatus
      return String(p("text", ""))
    case "weather": return weatherText()
    case "media": return mediaText()
    case "battery": return batteryText()
    case "system": return systemText()
    }
    return String(p("text", ""))
  }

  function weatherText() {
    var w = piece.liveData
    if (!w || !w.current) return w && !w.loading ? tr("Weather unavailable") : tr("Loading weather")
    var parts = [(p("icon", true) ? w.glyph + "  " : "") + (p("unit", "c") === "f" ? w.tempF : w.tempC)]
    if (p("condition", true) && w.condition.length > 0) parts.push(w.condition)
    if (p("place", false) && w.place.length > 0) parts.push(w.place)
    return parts.join("  ·  ")
  }

  function mediaText() {
    var m = piece.liveData
    if (!m || !m.hasMedia) return tr(String(p("idle", "Nothing playing")))
    var show = p("show", "both")
    var words = show === "title" ? m.title
      : (show === "artist" ? m.artist
      : (m.artist.length > 0 ? m.title + "  ·  " + m.artist : m.title))
    return (p("icon", true) ? (m.playing ? "󰐊  " : "󰏤  ") : "") + words
  }

  function batteryText() {
    var b = piece.liveData
    var icon = p("icon", true) && b ? b.glyph + "  " : ""
    if (!b || !b.hasBattery) return p("hideWithout", false) ? "" : icon + tr("No battery")
    return icon + b.percent + "%" + (p("state", true) && b.charging ? "  ·  " + tr("Charging") : "")
  }

  function systemText() {
    var s = piece.liveData
    if (!s) return ""
    var stat = p("stat", "uptime")
    var value = stat === "memory" ? s.memory : (stat === "load" ? s.load : (stat === "kernel" ? s.kernel : s.uptime))
    if (!p("label", true)) return value
    var label = stat === "memory" ? tr("Memory") : (stat === "load" ? tr("Load") : (stat === "kernel" ? tr("Kernel") : tr("Uptime")))
    return label + "  " + value
  }

  // The reader reported a failure. The designer's preview has no reader, so
  // the property can be missing there.
  readonly property bool fingerprintFailed: !!(lock && lock.fingerprintStatusIsError && (lock.fingerprintStatus || "").length > 0)
  readonly property color textColor: (kind === "status" && lock && (lock.failureMessage.length > 0 || fingerprintFailed))
    ? Color.lock.textError
    : tint(p("color", "text"), p("alpha", 1))

  Loader {
    id: loader
    anchors.fill: parent
    sourceComponent: {
      switch (piece.kind) {
      case "wallpaper": return wallpaperC
      case "video": return videoC
      case "color": return colorC
      case "password": return passwordC
      case "dots": return dotsC
      case "avatar": return avatarC
      case "image": return imageC
      case "panel": return panelC
      case "line": return lineC
      case "ttfx": return ttfxC
      case "art": return artC
      case "month": return monthC
      case "custom": return null
      }
      return piece.isText ? textC : null
    }
  }

  // ------------------------------------------------------------ backgrounds

  Component {
    id: wallpaperC
    Wallpaper {
      lock: piece.lock
      blur: piece.p("blur", 0.85)
      dim: piece.p("dim", 0.08)
      vignette: piece.p("vignette", true)
    }
  }

  // VideoWallpaper imports QtMultimedia, so it is loaded by URL: naming the
  // type here would stop this file — and the explorer, which draws its
  // thumbnails and canvas through it — from loading without qt6-multimedia.
  // There the piece falls back to the still wallpaper.
  Component {
    id: videoC
    Loader {
      source: Qt.resolvedUrl("VideoWallpaper.qml")
      onLoaded: {
        // The fallback arrives here too, and brings its own bindings.
        if (sourceComponent === wallpaperC) return
        item.lock = Qt.binding(function() { return piece.lock })
        item.dim = Qt.binding(function() { return piece.p("dim", 0.25) })
        item.vignette = Qt.binding(function() { return piece.p("vignette", true) })
        item.playing = Qt.binding(function() { return piece.lock ? piece.lock.videoPlaying : true })
      }
      onStatusChanged: if (status === Loader.Error) sourceComponent = wallpaperC
    }
  }

  Component {
    id: colorC
    Rectangle { color: piece.tint(piece.p("color", "background"), piece.p("alpha", 1)) }
  }

  // ------------------------------------------------------------------ text

  Component {
    id: textC
    Text {
      readonly property string body: piece.displayText()
      text: piece.p("caps", false) ? body.toUpperCase() : body
      textFormat: Text.PlainText
      color: piece.textColor
      font.family: Style.font.family
      font.pixelSize: Math.max(1, Math.round(piece.p("size", 22)))
      font.weight: Math.round(piece.p("weight", 400))
      font.letterSpacing: piece.p("spacing", 0)
      horizontalAlignment: piece.p("align", "center") === "left" ? Text.AlignLeft
        : (piece.p("align", "center") === "right" ? Text.AlignRight : Text.AlignHCenter)
      verticalAlignment: Text.AlignVCenter
      // A width set in the designer turns the label into a wrapping block;
      // left on its own it hugs its text (and never feeds its own width back
      // into the size it asks for).
      wrapMode: piece.fixedWidth > 0 ? Text.Wrap : Text.NoWrap
      elide: piece.fixedWidth > 0 ? Text.ElideRight : Text.ElideNone
      layer.enabled: piece.p("shadow", false)
      layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: Qt.rgba(0, 0, 0, 0.55)
        shadowBlur: 0.8
        shadowVerticalOffset: 2
      }
    }
  }

  // ----------------------------------------------------------------- input

  Component {
    id: passwordC
    PasswordField {
      id: passwordBox
      property Item field: passwordBox.input
      lock: piece.lock
      placeholder: String(piece.p("placeholder", tr("Enter password")))
      showLockGlyph: piece.p("glyph", true)
      fontScale: piece.p("fontScale", 1)
      textAlignment: piece.p("align", "center") === "left" ? TextInput.AlignLeft
        : (piece.p("align", "center") === "right" ? TextInput.AlignRight : TextInput.AlignHCenter)
      implicitWidth: 400
      implicitHeight: 60
    }
  }

  // No box: a dot per character, and a hidden LockInput taking the keys.
  Component {
    id: dotsC
    Item {
      id: dotsRoot
      property alias field: hidden
      implicitWidth: 320
      implicitHeight: Math.max(24, Math.round(piece.p("size", 14) * 2))

      readonly property int count: piece.lock ? piece.lock.passwordText.length : 0
      readonly property int shown: Math.min(count, Math.max(1, Math.round(piece.p("max", 24))))
      readonly property color dotColor: piece.lock && piece.lock.errorState
        ? Color.lock.textError : piece.tint(piece.p("color", "text"), piece.p("alpha", 0.9))

      LockInput {
        id: hidden
        lock: piece.lock
        anchors.centerIn: parent
        width: 1
        height: 1
        opacity: 0
      }

      Text {
        anchors.centerIn: parent
        visible: piece.lock ? (piece.lock.passwordVisible && dotsRoot.count > 0) : false
        text: piece.lock ? piece.lock.passwordText : ""
        textFormat: Text.PlainText
        color: dotsRoot.dotColor
        font.family: Style.font.family
        font.pixelSize: Math.round(piece.p("size", 14) * 1.8)
        font.letterSpacing: 2
      }

      Row {
        anchors.centerIn: parent
        visible: piece.lock ? !piece.lock.passwordVisible : true
        spacing: Math.max(1, Math.round(piece.p("gap", 14)))
        Repeater {
          model: dotsRoot.shown
          Rectangle {
            width: Math.max(2, Math.round(piece.p("size", 14)))
            height: width
            radius: width / 2
            color: dotsRoot.dotColor
            antialiasing: true
            opacity: 0
            Component.onCompleted: opacity = 1
            Behavior on opacity { NumberAnimation { duration: 140 } }
          }
        }
      }
    }
  }

  // ----------------------------------------------------------------- media

  Component {
    id: avatarC
    Avatar {
      lock: piece.lock
      borderWidth: Math.round(piece.p("borderWidth", 0))
      borderColor: piece.tint("text", piece.p("borderAlpha", 0.25))
      shadow: piece.p("shadow", true)
      implicitWidth: 120
      implicitHeight: 120
    }
  }

  Component {
    id: imageC
    Item {
      implicitWidth: 240
      implicitHeight: 160
      Rectangle {
        anchors.fill: parent
        visible: picture.status !== Image.Ready
        radius: piece.p("radius", 8)
        color: piece.tint("text", 0.08)
        border.width: 1
        border.color: piece.tint("text", 0.2)
        Text {
          anchors.centerIn: parent
          text: String(piece.p("path", "")).length > 0 ? "󰋫" : "󰋩"
          color: piece.tint("text", 0.5)
          font.family: Style.font.family
          font.pixelSize: Math.min(48, Math.max(14, parent.height / 3))
        }
      }
      Image {
        id: picture
        anchors.fill: parent
        source: {
          var path = String(piece.p("path", ""))
          if (path.length === 0) return ""
          if (path.indexOf("file://") === 0) return path
          return "file://" + path.split("/").map(encodeURIComponent).join("/")
        }
        asynchronous: true
        opacity: piece.p("alpha", 1)
        fillMode: piece.p("mode", "crop") === "fit" ? Image.PreserveAspectFit
          : (piece.p("mode", "crop") === "stretch" ? Image.Stretch : Image.PreserveAspectCrop)
        sourceSize.width: Math.round(width)
        sourceSize.height: Math.round(height)
        layer.enabled: piece.p("radius", 8) > 0 && status === Image.Ready
        layer.smooth: true
        layer.effect: MultiEffect {
          maskEnabled: true
          maskSource: imageMask
          maskThresholdMin: 0.5
          maskSpreadAtMin: 0.05
        }
      }
      Item {
        id: imageMask
        anchors.fill: parent
        visible: false
        layer.enabled: true
        Rectangle { anchors.fill: parent; radius: piece.p("radius", 8); color: "white"; antialiasing: true }
      }
    }
  }

  // The playing track's cover, or a note while there is none.
  Component {
    id: artC
    Item {
      implicitWidth: 200
      implicitHeight: 200
      readonly property string url: piece.liveData ? piece.liveData.artUrl : ""
      opacity: piece.p("hideIdle", false) && !(piece.liveData && piece.liveData.hasMedia) ? 0 : 1
      Behavior on opacity { NumberAnimation { duration: 250 } }
      Rectangle {
        anchors.fill: parent
        visible: cover.status !== Image.Ready
        radius: piece.p("radius", 16)
        color: piece.tint("text", 0.08)
        border.width: 1
        border.color: piece.tint("text", 0.16)
        Text {
          anchors.centerIn: parent
          text: "󰝚"
          color: piece.tint("text", 0.45)
          font.family: Style.font.family
          font.pixelSize: Math.min(72, Math.max(14, parent.height / 3))
        }
      }
      Image {
        id: cover
        anchors.fill: parent
        source: parent.url
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: Math.round(width)
        sourceSize.height: Math.round(height)
        opacity: piece.p("alpha", 1)
        layer.enabled: piece.p("radius", 16) > 0 && status === Image.Ready
        layer.smooth: true
        layer.effect: MultiEffect {
          maskEnabled: true
          maskSource: artMask
          maskThresholdMin: 0.5
          maskSpreadAtMin: 0.05
        }
      }
      Item {
        id: artMask
        anchors.fill: parent
        visible: false
        layer.enabled: true
        Rectangle { anchors.fill: parent; radius: piece.p("radius", 16); color: "white"; antialiasing: true }
      }
      layer.enabled: piece.p("shadow", true)
      layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: Qt.rgba(0, 0, 0, 0.5)
        shadowBlur: 1.0
        shadowVerticalOffset: 10
      }
    }
  }

  // This month as a grid, Monday first, today marked in the accent color.
  Component {
    id: monthC
    Column {
      id: month
      readonly property int cell: Math.max(12, Math.round(piece.p("size", 36)))
      readonly property date today: piece.lock ? piece.lock.now : new Date()
      readonly property var days: {
        var first = new Date(today.getFullYear(), today.getMonth(), 1)
        var out = []
        for (var i = 0; i < (first.getDay() + 6) % 7; i++) out.push(0)
        var count = new Date(today.getFullYear(), today.getMonth() + 1, 0).getDate()
        for (var d = 1; d <= count; d++) out.push(d)
        while (out.length % 7 !== 0) out.push(0)
        return out
      }
      // 1 January 2024 was a Monday.
      readonly property var weekdays: {
        var out = []
        for (var i = 0; i < 7; i++)
          out.push(piece.lock ? piece.lock.date("ddd", new Date(2024, 0, 1 + i)).substring(0, 2) : "")
        return out
      }
      readonly property color ink: piece.tint(piece.p("color", "text"), piece.p("alpha", 1))
      spacing: Math.round(cell * 0.2)

      Text {
        visible: piece.p("title", true)
        width: monthGrid.width
        text: piece.lock ? piece.lock.date("MMMM yyyy") : ""
        textFormat: Text.PlainText
        horizontalAlignment: Text.AlignHCenter
        color: month.ink
        font.family: Style.font.family
        font.pixelSize: Math.round(month.cell * 0.55)
        font.weight: Font.DemiBold
      }
      Row {
        visible: piece.p("weekdays", true)
        Repeater {
          model: month.weekdays
          Text {
            required property string modelData
            width: month.cell
            text: modelData
            textFormat: Text.PlainText
            horizontalAlignment: Text.AlignHCenter
            color: piece.tint(piece.p("color", "text"), piece.p("alpha", 1) * 0.55)
            font.family: Style.font.family
            font.pixelSize: Math.round(month.cell * 0.34)
          }
        }
      }
      Grid {
        id: monthGrid
        columns: 7
        Repeater {
          model: month.days
          Item {
            required property int modelData
            readonly property bool isToday: modelData === month.today.getDate()
            width: month.cell
            height: month.cell
            Rectangle {
              anchors.centerIn: parent
              width: parent.width * 0.82
              height: width
              radius: width / 2
              visible: parent.isToday
              color: piece.roleColor(piece.p("accent", "accent"))
            }
            Text {
              anchors.centerIn: parent
              text: parent.modelData > 0 ? String(parent.modelData) : ""
              color: parent.isToday ? Color.background : month.ink
              font.family: Style.font.family
              font.pixelSize: Math.round(month.cell * 0.4)
              font.weight: parent.isToday ? Font.Bold : Font.Normal
            }
          }
        }
      }
    }
  }

  // ---------------------------------------------------------------- shapes

  Component {
    id: panelC
    Rectangle {
      implicitWidth: 460
      implicitHeight: 300
      radius: Math.round(piece.p("radius", 20))
      color: piece.tint(piece.p("color", "surface"), piece.p("alpha", 0.55))
      border.width: piece.p("borderAlpha", 0.12) > 0 ? 1 : 0
      border.color: piece.tint(piece.p("borderColor", "text"), piece.p("borderAlpha", 0.12))
      antialiasing: true
      layer.enabled: piece.p("shadow", true)
      layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: Qt.rgba(0, 0, 0, 0.5)
        shadowBlur: 1.0
        shadowVerticalOffset: 12
      }
    }
  }

  // ------------------------------------------------------------------ ttfx

  Component {
    id: ttfxC
    TtfxText {
      id: art
      text: String(piece.p("art", ""))
      effect: piece.p("effect", "decrypt")
      // Redrawing while it is being drawn in the editor: play the same effect
      // again so the canvas shows what the change looks like.
      replayEffect: piece.p("effect", "decrypt")
      pixelSize: piece.p("size", 14)
      frameRate: piece.p("rate", 60)
      margin: piece.p("margin", 1)
      textColor: piece.roleColor(piece.p("color", "text"))
      accentColor: piece.roleColor(piece.p("accent", "accent"))
      // Picking another effect in the inspector cuts the running one short
      // and plays the new one, instead of leaving it for the next replay.
      onEffectChanged: play(effect)

      Connections {
        target: piece.p("replay", true) ? piece.lock : null
        function onFailureMessageChanged() {
          if (piece.lock.failureMessage.length > 0) art.play(art.effect)
        }
      }
    }
  }

  Component {
    id: lineC
    Rectangle {
      implicitWidth: 320
      implicitHeight: 1
      color: piece.tint(piece.p("color", "text"), piece.p("alpha", 0.2))
    }
  }
}
