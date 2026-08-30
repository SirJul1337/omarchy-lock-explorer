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
  readonly property bool ready: player.hasVideo && player.error === MediaPlayer.NoError

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
      console.warn("lock-explorer: cannot play", still.clipUrl, errorString)
      still.finish()
    }
  }

  VideoOutput {
    id: output
    anchors.fill: parent
    fillMode: VideoOutput.PreserveAspectCrop
    visible: still.ready
  }

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
        player.play()
      } else {
        // Back to the first frame for the next lock.
        player.stop()
        player.pause()
      }
    }
  }
}
