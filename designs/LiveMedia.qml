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
  // Whatever the player says, capped: it is shown on the lock screen.
  readonly property string title: hasMedia ? String(player.trackTitle || "").substring(0, 200) : ""
  readonly property string artist: hasMedia ? String(player.trackArtist || "").substring(0, 200) : ""
  readonly property string album: hasMedia ? String(player.trackAlbum || "").substring(0, 200) : ""
  // Cover art comes from whichever program on the session bus claims to be a
  // player: a local file or an https URL only, never another scheme.
  readonly property string artUrl: {
    var u = hasMedia ? String(player.trackArtUrl || "") : ""
    return /^(file:\/\/\/|https:\/\/)/.test(u) ? u : ""
  }
}
