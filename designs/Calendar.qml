import QtQuick
import qs.Commons

DesignBase {
  id: lock
  inputItem: field.input

  readonly property int cell: 40
  readonly property var monthDays: buildMonth(now)

  function buildMonth(d) {
    var first = new Date(d.getFullYear(), d.getMonth(), 1)
    var offset = (first.getDay() + 6) % 7
    var count = new Date(d.getFullYear(), d.getMonth() + 1, 0).getDate()
    var out = []
    for (var i = 0; i < offset; i++) out.push(0)
    for (var day = 1; day <= count; day++) out.push(day)
    while (out.length % 7 !== 0) out.push(0)
    return out
  }

  Wallpaper { anchors.fill: parent; lock: lock; blur: 0.8; dim: 0.15 }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: { lock.wakeRequested(); lock.forcePasswordFocus() }
    onPositionChanged: lock.wakeRequested()
  }

  Row {
    anchors.centerIn: parent
    spacing: 80

    Rectangle {
      width: calCol.implicitWidth + 48
      height: calCol.implicitHeight + 40
      radius: 18
      color: lock.withAlpha(Color.lock.background, 0.75)
      border.width: 1
      border.color: lock.withAlpha(Color.lock.text, 0.12)
      anchors.verticalCenter: parent.verticalCenter

      Column {
        id: calCol
        anchors.centerIn: parent
        spacing: 10

        Text {
          text: Qt.formatDate(lock.now, "MMMM yyyy")
          color: Color.lock.text
          font.family: Style.font.family
          font.pixelSize: Style.font.heading
          font.weight: Font.DemiBold
        }

        Row {
          Repeater {
            model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
            Text {
              required property string modelData
              width: lock.cell
              horizontalAlignment: Text.AlignHCenter
              text: modelData
              color: lock.withAlpha(Color.lock.text, 0.5)
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }
          }
        }

        Grid {
          columns: 7
          Repeater {
            model: lock.monthDays
            Item {
              required property int modelData
              width: lock.cell
              height: lock.cell
              Rectangle {
                anchors.centerIn: parent
                width: 32; height: 32; radius: 16
                visible: parent.modelData === lock.now.getDate()
                color: Color.lock.borderActive
              }
              Text {
                anchors.centerIn: parent
                text: parent.modelData > 0 ? parent.modelData : ""
                color: parent.modelData === lock.now.getDate() ? Color.background : Color.lock.text
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                font.weight: parent.modelData === lock.now.getDate() ? Font.Bold : Font.Normal
              }
            }
          }
        }
      }
    }

    Column {
      anchors.verticalCenter: parent.verticalCenter
      spacing: 20
      Text {
        text: Qt.formatTime(lock.now, "HH:mm")
        color: Color.lock.text
        font.family: Style.font.family
        font.pixelSize: Math.round(Style.font.baseSize * 8)
        font.weight: Font.DemiBold
        font.letterSpacing: -2
      }
      Text {
        text: Qt.formatDate(lock.now, "dddd")
        color: lock.withAlpha(Color.lock.text, 0.75)
        font.family: Style.font.family
        font.pixelSize: Style.font.display
      }
      Item { width: 1; height: 8 }
      PasswordField {
        id: field
        lock: lock
        width: 360
        height: 54
        textAlignment: TextInput.AlignLeft
        placeholder: lock.greeting() + ", " + lock.userName
      }
      Text {
        text: lock.fingerprintConfigured ? "󰆠  Touch sensor or press Enter" : "Press Enter to unlock"
        color: lock.withAlpha(Color.lock.text, 0.5)
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
      }
    }
  }
}
