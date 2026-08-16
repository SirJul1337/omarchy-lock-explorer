import QtQuick
import qs.Commons

DesignBase {
  id: lock
  inputItem: field.input

  readonly property int lineWidth: 640
  readonly property real dayFraction: (now.getHours() * 3600 + now.getMinutes() * 60 + now.getSeconds()) / 86400

  Wallpaper { anchors.fill: parent; lock: lock; blur: 0.85; dim: 0.12 }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: { lock.wakeRequested(); lock.forcePasswordFocus() }
    onPositionChanged: lock.wakeRequested()
  }

  Column {
    anchors.centerIn: parent
    spacing: 28

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: Qt.formatTime(lock.now, "HH:mm")
      color: Color.lock.text
      font.family: Style.font.family
      font.pixelSize: Math.round(Style.font.baseSize * 9)
      font.weight: Font.DemiBold
      font.letterSpacing: -2
    }

    Item {
      anchors.horizontalCenter: parent.horizontalCenter
      width: lock.lineWidth
      height: 40

      Rectangle {
        id: track
        anchors.top: parent.top
        width: parent.width
        height: 6
        radius: 3
        color: lock.withAlpha(Color.lock.text, 0.2)
        Rectangle {
          width: parent.width * lock.dayFraction
          height: parent.height
          radius: 3
          color: Color.lock.borderActive
        }
        Rectangle {
          x: parent.width * lock.dayFraction - 7
          y: -4
          width: 14; height: 14; radius: 7
          color: Color.lock.text
          border.width: 3
          border.color: Color.lock.borderActive
        }
      }

      Row {
        anchors.top: track.bottom
        anchors.topMargin: 8
        Repeater {
          model: ["00", "06", "12", "18"]
          Text {
            required property string modelData
            width: lock.lineWidth / 4
            text: modelData
            color: lock.withAlpha(Color.lock.text, 0.5)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }
        }
      }
      Text {
        anchors.top: track.bottom
        anchors.topMargin: 8
        anchors.right: parent.right
        text: "24"
        color: lock.withAlpha(Color.lock.text, 0.5)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: Qt.formatDate(lock.now, "dddd, d MMMM") + "  ·  " + Math.round(lock.dayFraction * 100) + "% of the day"
      color: lock.withAlpha(Color.lock.text, 0.7)
      font.family: Style.font.family
      font.pixelSize: Style.font.subtitle
      font.letterSpacing: 1
    }

    Item { width: 1; height: 4 }

    PasswordField {
      id: field
      lock: lock
      anchors.horizontalCenter: parent.horizontalCenter
      width: 380
      height: 54
      placeholder: lock.userName
    }
  }
}
