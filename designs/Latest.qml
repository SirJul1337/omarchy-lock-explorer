import QtQuick
import QtQuick.Effects
import qs.Commons

// The account that was last here is the one on screen. Everyone else stays
// folded away behind a single control, and is chosen by clicking -- there is no
// list to read and no keyboard incantation to know.
DesignBase {
  id: lock
  inputItem: field.input

  // The switcher is the only thing on this design that opens, so it owns the
  // one bit of state.
  property bool expanded: false

  readonly property int cardWidth: 400
  readonly property string shownName: lock.selectedName
  readonly property string shownInitial: lock.switchingAway
    ? lock.otherUsers[lock.selectedUser].initial
    : lock.userInitial
  readonly property string shownAvatar: lock.switchingAway
    ? lock.avatarUrlFor(lock.selectedName)
    : lock.avatarUrl

  Wallpaper {
    anchors.fill: parent
    lock: lock
    blur: 0.55
    dim: 0.18
    vignetteTop: 0.30
    vignetteMiddle: 0.05
    vignetteBottom: 0.55
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    // Clicking the wallpaper is how you back out of the switcher, which keeps
    // Esc free for clearing the password.
    onClicked: {
      lock.expanded = false
      lock.wakeRequested()
      lock.forcePasswordFocus()
    }
    onPositionChanged: lock.wakeRequested()
  }

  Column {
    id: stack
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
    anchors.verticalCenterOffset: -Math.round(parent.height * 0.04)
    spacing: 0

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: lock.clock("HH:mm")
      color: Color.lock.text
      font.family: Style.font.family
      font.pixelSize: Math.round(Style.font.baseSize * 9)
      font.weight: Font.DemiBold
      font.letterSpacing: -2
      layer.enabled: true
      layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Qt.rgba(0, 0, 0, 0.6); shadowBlur: 1.0; shadowVerticalOffset: 2 }
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      topPadding: 2
      text: Qt.formatDate(lock.now, "dddd, d MMMM")
      color: lock.withAlpha(Color.lock.text, 0.85)
      font.family: Style.font.family
      font.pixelSize: Style.font.display
      layer.enabled: true
      layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Qt.rgba(0, 0, 0, 0.6); shadowBlur: 0.9; shadowVerticalOffset: 1 }
    }

    Item { width: 1; height: 44 }

    // Whoever is on deck: the session owner, or the account just clicked.
    Avatar {
      id: face
      anchors.horizontalCenter: parent.horizontalCenter
      lock: lock
      source: lock.shownAvatar
      initial: lock.shownInitial
      width: 104
      fontSize: Math.round(Style.font.baseSize * 3.6)
      borderWidth: 3
      borderColor: lock.switchingAway ? Color.lock.borderActive : lock.withAlpha(Color.lock.text, 0.26)
      shadow: true
      Behavior on borderColor { ColorAnimation { duration: 160 } }
    }

    Item { width: 1; height: 18 }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: lock.shownName
      color: Color.lock.text
      font.family: Style.font.family
      font.pixelSize: Style.font.displayLarge
      font.weight: Font.DemiBold
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      topPadding: 4
      opacity: lock.snapshotMode ? 0 : 1
      text: lock.errorState ? lock.failureMessage
        : (lock.authenticatingPassword ? "Checking…"
        : (lock.switchingAway ? "Switching to " + lock.shownName : lock.greeting()))
      textFormat: Text.PlainText
      color: lock.errorState ? Color.lock.textError : lock.withAlpha(Color.lock.text, 0.70)
      font.family: Style.font.family
      font.pixelSize: Style.font.subtitle
    }

    Item { width: 1; height: 26 }

    PasswordField {
      id: field
      anchors.horizontalCenter: parent.horizontalCenter
      lock: lock
      width: lock.cardWidth
      height: 60
      placeholder: lock.switchingAway ? "Password for " + lock.shownName : "Enter password"
    }

    Item { width: 1; height: 22 }

    // The switcher, closed. One control, and it only exists when there is
    // somebody else to switch to.
    Item {
      id: switcher
      anchors.horizontalCenter: parent.horizontalCenter
      visible: lock.hasOtherUsers && !lock.snapshotMode
      width: lock.cardWidth
      height: lock.expanded ? 0 : 48
      opacity: lock.expanded ? 0 : 1
      clip: true
      Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
      Behavior on opacity { NumberAnimation { duration: 140 } }

      Rectangle {
        anchors.fill: parent
        anchors.bottomMargin: 0
        radius: Math.max(Style.cornerRadius, 12)
        color: closeHover.containsMouse ? lock.withAlpha(Color.lock.text, 0.14)
                                        : lock.withAlpha(Color.lock.text, 0.08)
        border.width: 1
        border.color: lock.withAlpha(Color.lock.text, 0.18)
        Behavior on color { ColorAnimation { duration: 120 } }

        Row {
          anchors.centerIn: parent
          spacing: 12

          // A peek at who else is here -- faces, not a list of names.
          Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: -10
            Repeater {
              model: Math.min(lock.otherUsers.length, 4)
              Avatar {
                required property int index
                lock: lock
                source: lock.avatarUrlFor(lock.otherUsers[index].name)
                initial: lock.otherUsers[index].initial
                width: 26
                fontSize: Style.font.bodySmall
                borderWidth: 2
                borderColor: Color.lock.background
                shadow: false
              }
            }
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: lock.otherUsers.length === 1 ? "Someone else" : "Someone else?"
            color: lock.withAlpha(Color.lock.text, 0.80)
            font.family: Style.font.family
            font.pixelSize: Style.font.body
          }
        }

        MouseArea {
          id: closeHover
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: lock.expanded = true
        }
      }
    }

    // The switcher, open. Each account is a click target the size of a button,
    // not a row in a menu.
    Item {
      id: choices
      anchors.horizontalCenter: parent.horizontalCenter
      visible: lock.hasOtherUsers && !lock.snapshotMode
      width: lock.cardWidth
      height: lock.expanded ? choiceColumn.implicitHeight : 0
      opacity: lock.expanded ? 1 : 0
      clip: true
      Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
      Behavior on opacity { NumberAnimation { duration: 160 } }

      Column {
        id: choiceColumn
        width: parent.width
        spacing: 8

        Repeater {
          model: lock.otherUsers.length

          Rectangle {
            required property int index
            readonly property bool chosen: lock.selectedUser === index

            width: choiceColumn.width
            height: 62
            radius: Math.max(Style.cornerRadius, 12)
            color: chosen ? lock.withAlpha(Color.lock.borderActive, 0.18)
                 : (rowHover.containsMouse ? lock.withAlpha(Color.lock.text, 0.14)
                                           : lock.withAlpha(Color.lock.text, 0.07))
            border.width: chosen ? 2 : 1
            border.color: chosen ? Color.lock.borderActive : lock.withAlpha(Color.lock.text, 0.16)
            Behavior on color { ColorAnimation { duration: 120 } }

            Row {
              anchors.left: parent.left
              anchors.leftMargin: 14
              anchors.verticalCenter: parent.verticalCenter
              spacing: 14

              Avatar {
                anchors.verticalCenter: parent.verticalCenter
                lock: lock
                source: lock.avatarUrlFor(lock.otherUsers[index].name)
                initial: lock.otherUsers[index].initial
                width: 38
                fontSize: Style.font.title
                shadow: false
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: lock.otherUsers[index].realName
                color: Color.lock.text
                font.family: Style.font.family
                font.pixelSize: Style.font.title
                font.weight: Font.DemiBold
              }
            }

            MouseArea {
              id: rowHover
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              // Clicking picks the account and folds the switcher away again, so
              // the screen returns to one face and one box.
              onClicked: {
                lock.selectUser(index)
                lock.expanded = false
                lock.clearPassword()
                lock.forcePasswordFocus()
              }
            }
          }
        }

        // Back to the account this screen actually belongs to.
        Rectangle {
          width: choiceColumn.width
          height: 44
          radius: Math.max(Style.cornerRadius, 12)
          color: backHover.containsMouse ? lock.withAlpha(Color.lock.text, 0.12) : "transparent"
          border.width: 1
          border.color: lock.withAlpha(Color.lock.text, 0.14)
          Behavior on color { ColorAnimation { duration: 120 } }

          Text {
            anchors.centerIn: parent
            text: "Back to " + lock.userName
            color: lock.withAlpha(Color.lock.text, 0.72)
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
          }

          MouseArea {
            id: backHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              lock.selectUser(-1)
              lock.expanded = false
              lock.clearPassword()
              lock.forcePasswordFocus()
            }
          }
        }
      }
    }
  }

  // Says what a switch actually does, and only while one is pending.
  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 36
    opacity: lock.switchingAway && !lock.snapshotMode ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 160 } }
    text: "󰌾  Your session stays locked"
    color: lock.withAlpha(Color.lock.text, 0.60)
    font.family: Style.font.family
    font.pixelSize: Style.font.bodySmall
    font.letterSpacing: 1
  }
}
