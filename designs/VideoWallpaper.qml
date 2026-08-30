import QtQuick
import QtMultimedia
import qs.Commons

// The same job as Wallpaper, with a looping video on top of it. The picture
// stays underneath: it is what shows before the first frame is decoded and what
// is left if the file will not play at all, so a design using this always has a
// background. Silent by design, a lock screen has no business making noise.
Item {
  id: wall

  property var lock: null
  property real dim: 0.25
  property bool vignette: true
  property real vignetteTop: 0.35
  property real vignetteMiddle: 0.10
  property real vignetteBottom: 0.45

  // Set false to hold the video still, e.g. while the screen is blanked. It
  // also stops on its own whenever the item leaves the screen, which is what
  // keeps a gridful of previews in the explorer from decoding all at once.
  property bool playing: true

  readonly property string videoUrl: lock && lock.videoUrl ? lock.videoUrl : ""
  readonly property bool wants: playing && visible && videoUrl.length > 0 && !failed
  property bool failed: false
  readonly property bool showing: player.hasVideo && player.playbackState === MediaPlayer.PlayingState

  Wallpaper {
    anchors.fill: parent
    lock: wall.lock
    blur: 0
    dim: 0
    vignette: false
  }

  MediaPlayer {
    id: player
    source: wall.videoUrl
    videoOutput: output
    loops: MediaPlayer.Infinite
    onSourceChanged: { wall.failed = false; wall.sync() }
    onErrorOccurred: function(error, errorString) {
      wall.failed = true
      console.warn("lock-explorer: cannot play", wall.videoUrl, errorString)
    }
  }

  VideoOutput {
    id: output
    anchors.fill: parent
    fillMode: VideoOutput.PreserveAspectCrop
    opacity: wall.showing ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
  }

  function sync() {
    if (wants) player.play()
    else player.pause()
  }

  onWantsChanged: sync()
  Component.onCompleted: sync()

  Rectangle {
    anchors.fill: parent
    color: "black"
    opacity: wall.dim
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
