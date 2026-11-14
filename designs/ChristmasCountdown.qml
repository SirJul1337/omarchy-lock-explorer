import QtQuick
import qs.Commons
import qs.Commons as Commons

// The Christmas designs' line under the date: the days left until the 25th
// through November and December, Merry Christmas from the 24th to the 26th,
// and nothing the rest of the year. Hidden in boot snapshots, which are drawn
// once and shown for days.
Text {
  id: line

  property var lock: null

  readonly property string season: {
    if (!lock || lock.snapshotMode) return ""
    var day = lock.now
    var m = day.getMonth(), d = day.getDate()
    if (m === 11 && d >= 24 && d <= 26) return lock.tr("Merry Christmas")
    // Midnight to midnight, rounded, so a daylight saving change in between
    // does not drop a day.
    var left = Math.round((new Date(day.getFullYear(), 11, 25) - new Date(day.getFullYear(), m, d)) / 86400000)
    if (left < 1 || left > 61) return ""
    return left === 1 ? lock.tr("1 day until Christmas") : lock.tr("%1 days until Christmas").arg(left)
  }

  text: season
  visible: season.length > 0
  textFormat: Text.PlainText
  font.family: Style.font.family
  font.pixelSize: Style.font.bodySmall
  font.letterSpacing: 2
}
