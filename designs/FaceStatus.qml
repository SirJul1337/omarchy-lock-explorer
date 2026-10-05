import QtQuick
import qs.Commons

// A layout item, not a floating panel. Each design reserves its own space.
Item {
  id: status
  required property var lock
  property bool centered: true
  property int pixelSize: 13
  property bool compact: false
  readonly property bool available: lock && lock.faceConfigured && !lock.snapshotMode
    && !lock.authenticatingPassword && !lock.errorState && !lock.fido2Active
  visible: available
  implicitHeight: compact ? 22 : 38
  height: visible ? implicitHeight : 0
  implicitWidth: 320

  Row {
    id: content
    x: status.centered ? Math.max(0, (status.width - width) / 2) : 0
    width: Math.min(status.width, mark.implicitWidth + 12 + labels.implicitWidth)
    spacing: 12

    Text {
      id: mark
      text: status.lock.faceRecognized ? "✓" : "☺"
      color: status.lock.faceRecognized ? Color.lock.borderActive : Color.lock.text
      font.family: Style.font.family
      font.pixelSize: status.compact ? status.pixelSize : status.pixelSize + 9
      opacity: status.lock.faceRecognized ? 1 : 0.65
      SequentialAnimation on opacity {
        running: status.visible && status.lock.faceAuthenticating && status.lock.screenAwake && !status.lock.motionReduced
        loops: Animation.Infinite
        NumberAnimation { to: 0.35; duration: 650 }
        NumberAnimation { to: 0.9; duration: 650 }
        onRunningChanged: if (!running) mark.opacity = status.lock.faceRecognized ? 1 : 0.65
      }
    }

    Column {
      id: labels
      width: Math.max(0, content.width - mark.width - content.spacing)
      implicitWidth: Math.max(title.implicitWidth, hint.implicitWidth)
      spacing: 4
      Text {
        id: title
        width: parent.width
        text: status.compact ? status.lock.faceStatusHint
          : status.lock.faceRecognized ? status.lock.tr("Face recognized")
          : status.lock.faceAuthenticating ? status.lock.tr("Recognizing face…") : status.lock.tr("Face recognition")
        textFormat: Text.PlainText
        color: status.lock.faceRecognized ? Color.lock.borderActive : Color.lock.text
        font.family: Style.font.family
        font.pixelSize: status.pixelSize
        opacity: status.lock.faceRecognized ? 1 : 0.8
        elide: Text.ElideRight
      }
      Text {
        id: hint
        width: parent.width
        visible: !status.compact
        text: status.lock.faceStatusHint
        textFormat: Text.PlainText
        color: Color.lock.text
        font.family: Style.font.family
        font.pixelSize: Math.max(10, status.pixelSize - 2)
        opacity: 0.55
        elide: Text.ElideRight
      }
    }
  }
}
