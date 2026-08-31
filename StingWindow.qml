import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Wayland

// The unlock clip. It sits over the unlocked desktop, never over the session
// lock, so a video that will not decode costs a black screen for a moment and
// nothing more. Four ways out: a key, a click, the end of the clip, and a
// failsafe timer that does not care what the player thinks.
//
// This window lives in its own file because it is the only part of the
// service that needs QtMultimedia, which stock Omarchy does not install.
// Service.qml loads it through a Loader: without qt6-multimedia only this
// window goes missing, the service itself still comes up and keeps the
// `lock` IPC target.
PanelWindow {
  id: window

  // The service root (Service.qml), set by its Loader.
  property var lock: null

  visible: lock ? lock.stingPlaying : false
  anchors { top: true; bottom: true; left: true; right: true }
  color: "black"
  WlrLayershell.namespace: "omarchy-lock-explorer-sting"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: window.visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
  exclusionMode: ExclusionMode.Ignore

  function endSting() {
    if (window.lock) window.lock.endSting()
  }

  MediaPlayer {
    id: stingPlayer
    source: window.lock ? window.lock.stingUrl : ""
    videoOutput: stingOutput
    playbackRate: window.lock && window.lock.clipSpeed > 0 ? window.lock.clipSpeed : 1
    audioOutput: AudioOutput {
      muted: !window.lock || window.lock.stingVolume <= 0
      volume: window.lock ? window.lock.stingVolume / 100 : 0
    }
    onMediaStatusChanged: if (mediaStatus === MediaPlayer.EndOfMedia) stingFade.start()
    onErrorOccurred: function(error, errorString) {
      console.warn("lock-explorer: cannot play unlock clip", source, errorString)
      window.endSting()
    }
  }

  Item {
    id: stingStage
    anchors.fill: parent
    focus: true
    opacity: 1

    VideoOutput {
      id: stingOutput
      anchors.fill: parent
      fillMode: VideoOutput.PreserveAspectCrop
    }

    Keys.onPressed: function(event) { window.endSting(); event.accepted = true }
    MouseArea { anchors.fill: parent; onClicked: window.endSting() }
  }

  NumberAnimation {
    id: stingFade
    target: stingStage
    property: "opacity"
    to: 0
    duration: 450
    easing.type: Easing.OutCubic
    onFinished: window.endSting()
  }

  // Whatever the clip is doing, it is gone by the time this fires.
  Timer {
    id: stingFailsafe
    interval: 20000
    onTriggered: window.endSting()
  }

  Connections {
    target: window.lock
    function onStingPlayingChanged() {
      if (window.lock.stingPlaying) {
        stingFade.stop()
        stingStage.opacity = 1
        // stop first: position is read only, and a stopped player replays
        // from the beginning.
        stingPlayer.stop()
        stingPlayer.play()
        stingFailsafe.restart()
        stingStage.forceActiveFocus()
      } else {
        stingFailsafe.stop()
        stingFade.stop()
        stingPlayer.stop()
      }
    }
  }
}
