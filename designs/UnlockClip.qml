import QtQuick
import QtMultimedia
import qs.Commons

// The first frame of a clip, standing still behind the sign-in. When the
// password checks out the service raises unlockPlayback instead of dropping
// the lock, the clip plays through -- the lightning strikes, the logo lands --
// and unlockFinished() hands the screen back. Muted: a lock screen has no
// business making noise. ClipDesign is the usual way to use it.
Item {
  id: still

  property var lock: null
  property string clip: ""
  readonly property string clipUrl: {
    if (clip.length === 0) return ""
    var encoded = String(clip).split("/").map(encodeURIComponent).join("/")
    return "file://" + encoded
  }
  // True once the clip has been tried and will not play, which is what the
  // "missing file" line in ClipDesign watches.
  property bool failed: false
  readonly property bool ready: playerLoader.item ? playerLoader.item.ready : false
  // Constructing a MediaPlayer makes FFmpeg enumerate its hardware decoders,
  // which opens the NVIDIA device nodes on a hybrid laptop and keeps the dGPU
  // awake for as long as the player lives. The preview and the lock surface
  // keep their design loaded in windows that are not mapped, where items still
  // report visible, so the window has to be checked too.
  readonly property bool mapped: visible && Window.window !== null && Window.window.visible

  Loader {
    id: playerLoader
    anchors.fill: parent
    active: still.mapped && still.clipUrl.length > 0 && !still.failed
    sourceComponent: Item {
      readonly property bool ready: player.hasVideo && player.error === MediaPlayer.NoError

      function play() { player.play() }
      function rewind() {
        // Back to the first frame for the next lock.
        player.stop()
        player.pause()
      }

      MediaPlayer {
        id: player
        source: still.clipUrl
        videoOutput: output
        playbackRate: still.lock && still.lock.clipSpeed > 0 ? still.lock.clipSpeed : 1
        audioOutput: AudioOutput { muted: true }
        onMediaStatusChanged: {
          // Pausing a freshly loaded player decodes and shows the first frame.
          if (mediaStatus === MediaPlayer.LoadedMedia && !(still.lock && still.lock.unlockPlayback)) player.pause()
          else if (mediaStatus === MediaPlayer.EndOfMedia) still.finish()
        }
        onErrorOccurred: function(error, errorString) {
          still.failed = true
          console.warn("lock-explorer: cannot play", still.clipUrl, errorString)
          still.finish()
        }
      }

      VideoOutput {
        id: output
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
        visible: ready
      }

      // The unlock can start before this exists: a design picked while the
      // clip plays, or a window mapped mid-playback.
      Component.onCompleted: if (still.lock && still.lock.unlockPlayback) player.play()
    }
  }

  onClipUrlChanged: failed = false

  function finish() {
    if (lock && lock.unlockPlayback) lock.unlockFinished()
  }

  Connections {
    target: still.lock
    function onUnlockPlaybackChanged() {
      if (still.lock.unlockPlayback) {
        // A clip that cannot play hands the screen back at once rather than
        // sitting on the service's failsafe.
        if (!still.ready) { still.lock.unlockFinished(); return }
        playerLoader.item.play()
      } else if (playerLoader.item) {
        playerLoader.item.rewind()
      }
    }
  }
}
