import QtQuick
import QtQuick.Effects
import qs.Commons

Item {
  id: wall

  property var lock: null
  property real blur: 0.85
  property real dim: 0.08
  property real contrast: -0.05
  property bool vignette: true
  property real vignetteTop: 0.35
  property real vignetteMiddle: 0.10
  property real vignetteBottom: 0.45

  // What is drawn: the design's blur and dim, as the wallpaper setting on the
  // lock (see DesignBase) adjusts them.
  readonly property real shownBlur: wall.lock && wall.lock.wallpaperBlur !== undefined && wall.lock.wallpaperBlur >= 0
                                    ? wall.lock.wallpaperBlur : wall.blur
  readonly property real shownDim: Math.max(0, Math.min(0.9, wall.dim
                                   + (wall.lock && wall.lock.wallpaperDim !== undefined ? wall.lock.wallpaperDim : 0)))

  Rectangle {
    anchors.fill: parent
    color: Color.background
  }

  Image {
    id: image
    anchors.fill: parent
    source: (wall.lock && wall.lock.loadBackground) ? wall.lock.fileUrl(wall.lock.backgroundPath) : ""
    fillMode: Image.PreserveAspectCrop
    asynchronous: true
    // The url ends in ?v=backgroundVersion, so a new wallpaper is a new url and
    // this cannot serve a stale one. Sharing it matters in the explorer, where
    // every preview would otherwise decode the same file on its own.
    cache: true
    sourceSize.width: width
    sourceSize.height: height
    visible: wall.shownBlur <= 0
  }

  MultiEffect {
    anchors.fill: image
    source: image
    // Hidden until the image decodes: with a broken wallpaper (e.g. WebP
    // without qt6-imageformats) the effect paints its empty source as solid
    // black, hiding the theme-color fallback underneath.
    visible: wall.shownBlur > 0 && image.status === Image.Ready
    autoPaddingEnabled: false
    blurEnabled: wall.shownBlur > 0 && image.status === Image.Ready
    blur: wall.shownBlur
    blurMax: 96
    blurMultiplier: 1.25
    contrast: wall.contrast
    brightness: -wall.shownDim
  }

  Rectangle {
    anchors.fill: parent
    visible: wall.vignette
    gradient: Gradient {
      GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, wall.vignetteTop) }
      GradientStop { position: 0.45; color: Qt.rgba(0, 0, 0, wall.vignetteMiddle) }
      GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, wall.vignetteBottom) }
    }
  }
}
