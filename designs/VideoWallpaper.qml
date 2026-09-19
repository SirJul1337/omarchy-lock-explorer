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
  readonly property bool showing: playerLoader.item ? playerLoader.item.showing : false

  Wallpaper {
    anchors.fill: parent
    lock: wall.lock
    blur: 0
    dim: 0
    vignette: false
  }

  // The player is built only while something actually shows this item: a
  // MediaPlayer makes FFmpeg enumerate its hardware decoders, which opens the
  // NVIDIA device nodes on a hybrid laptop and keeps the dGPU awake for as
  // long as it lives. The explorer preview and the lock surface keep their
  // design loaded in windows that are not mapped, where items still report
  // visible, so the window has to be checked too.
  readonly property bool mapped: visible && Window.window !== null && Window.window.visible

  Loader {
    id: playerLoader
    anchors.fill: parent
    active: wall.mapped && wall.videoUrl.length > 0 && !wall.failed
    sourceComponent: Item {
      readonly property bool showing: player.hasVideo && player.playbackState === MediaPlayer.PlayingState

      function sync() {
        if (wall.wants) player.play()
        else player.pause()
      }

      MediaPlayer {
        id: player
        source: wall.videoUrl
        videoOutput: output
        loops: MediaPlayer.Infinite
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

      Component.onCompleted: sync()
    }
  }

  onVideoUrlChanged: { failed = false; sync() }

  function sync() {
    if (playerLoader.item) playerLoader.item.sync()
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
