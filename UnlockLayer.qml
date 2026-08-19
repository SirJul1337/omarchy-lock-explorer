import QtQuick

// Wraps the lock screen so it can leave the screen instead of blinking away.
// The compositor paints black under the lock surface, so the plain wallpaper
// underneath is what keeps the unlock from fading through black: the design
// dissolves into the background the desktop is about to show anyway.
Item {
  id: layer

  // "fade", "zoom", "rise" or "none", see `omarchy-shell lock unlockAnimation`.
  property string animation: "fade"
  property int duration: 400
  property bool active: false
  property string backgroundUrl: ""

  default property alias content: stage.data

  readonly property bool animated: animation !== "none" && duration > 0

  Image {
    anchors.fill: parent
    // Only needed once the design starts fading, but it loads with the lock so
    // it is decoded by then. Nothing sees it appear, the stage still covers it.
    visible: layer.animated && layer.active && status === Image.Ready
    source: layer.animated ? layer.backgroundUrl : ""
    fillMode: Image.PreserveAspectCrop
    asynchronous: true
    cache: false
    sourceSize.width: width
    sourceSize.height: height
  }

  Item {
    id: stage
    anchors.fill: parent

    readonly property bool leaving: layer.active && layer.animated
    property real zoom: leaving && layer.animation === "zoom" ? 1.06 : 1
    property real lift: leaving && layer.animation === "rise" ? -0.06 * height : 0

    opacity: leaving ? 0 : 1

    Behavior on opacity { NumberAnimation { duration: layer.duration; easing.type: Easing.OutCubic } }
    Behavior on zoom { NumberAnimation { duration: layer.duration; easing.type: Easing.OutCubic } }
    Behavior on lift { NumberAnimation { duration: layer.duration; easing.type: Easing.OutCubic } }

    transform: [
      Scale {
        origin.x: stage.width / 2
        origin.y: stage.height / 2
        xScale: stage.zoom
        yScale: stage.zoom
      },
      Translate { y: stage.lift }
    ]
  }
}
