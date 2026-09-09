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
    var src = 'import QtQuick\n'
      + 'import QtQuick.Effects\n'
      + 'import QtMultimedia\n'
      + 'import qs.Commons\n'
      + 'import "' + Qt.resolvedUrl(".") + '"\n'
      + 'Item {\n  anchors.fill: parent\n' + customQml + '\n}'
    try {
      customItem = Qt.createQmlObject(src, piece)
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

  implicitWidth: loader.item ? loader.item.implicitWidth : 0
  implicitHeight: loader.item ? loader.item.implicitHeight : 0
  width: (fillParent && parent) ? parent.width : (fixedWidth > 0 ? fixedWidth : implicitWidth)
  height: (fillParent && parent) ? parent.height
    : (kind === "avatar" ? width : (fixedHeight > 0 ? fixedHeight : implicitHeight))

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
    case "date": return Qt.formatDate(lock.now, String(p("format", "dddd, d MMMM")))
    case "greeting": return lock.greeting() + (p("withName", true) ? ", " + lock.userName : "")
    case "username": return lock.userName
    case "hostname": return lock.hostName
    case "status":
      if (lock.failureMessage.length > 0) return lock.failureMessage
      if (p("attempts", true) && lock.failedAttempts > 0)
        return lock.failedAttempts + (lock.failedAttempts === 1 ? " failed attempt" : " failed attempts")
      if (lock.authenticatingPassword) return "Checking…"
      return String(p("text", ""))
    }
    return String(p("text", ""))
  }

  readonly property color textColor: (kind === "status" && lock && lock.failureMessage.length > 0)
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

  Component {
    id: videoC
    VideoWallpaper {
      lock: piece.lock
      dim: piece.p("dim", 0.25)
      vignette: piece.p("vignette", true)
      playing: piece.lock ? piece.lock.videoPlaying : true
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
      placeholder: String(piece.p("placeholder", "Enter password"))
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

  Component {
    id: lineC
    Rectangle {
      implicitWidth: 320
      implicitHeight: 1
      color: piece.tint(piece.p("color", "text"), piece.p("alpha", 0.2))
    }
  }
}
