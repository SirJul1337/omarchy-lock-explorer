import QtQuick
import Quickshell.Services.Mpris

// What is playing, for the designer's Now playing and Album art pieces: the
// player that is playing, or else the first one there is (paused).
Item {
  readonly property var players: Mpris.players ? Mpris.players.values : []
  readonly property var player: {
    var first = null
    for (var i = 0; i < players.length; i++) {
      var p = players[i]
      if (!p) continue
      if (p.playbackState === MprisPlaybackState.Playing) return p
      if (!first) first = p
    }
    return first
  }
  readonly property bool hasMedia: player !== null && String(player.trackTitle || "").length > 0
  readonly property bool playing: hasMedia && player.playbackState === MprisPlaybackState.Playing
  readonly property string title: hasMedia ? String(player.trackTitle || "") : ""
  readonly property string artist: hasMedia ? String(player.trackArtist || "") : ""
  readonly property string album: hasMedia ? String(player.trackAlbum || "") : ""
  readonly property string artUrl: hasMedia ? String(player.trackArtUrl || "") : ""
}
