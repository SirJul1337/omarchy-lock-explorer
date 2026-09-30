import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "Designs.js" as Designs

// The side panel: the selected design drawn live on top, then search and the
// designs as a list. It is what `omarchy-shell lock explore` opens first
// (Settings > System > Opens as), and everything else -- settings, the boot
// screen, the designer -- is one button away in the full explorer.
//
// It draws from the explorer it sits in: the same tab, search text and
// selection, so opening the full explorer lands on the design that was
// selected here.
BorderSurface {
  id: side

  property var explorer: null
  // The screen a lock screen is laid out for; previews scale down from it.
  property real screenWidth: 1920
  property real screenHeight: 1080

  readonly property var service: explorer ? explorer.service : null
  readonly property color fg: explorer.foreground
  readonly property bool shown: explorer.opened && explorer.sideView
  readonly property real offDistance: width + Style.gapsOut * 2
  property real slide: shown ? 0 : offDistance
  Behavior on slide {
    NumberAnimation { duration: side.explorer.motionReduced ? 0 : 220; easing.type: Easing.OutCubic }
  }
  transform: Translate { x: side.slide }

  // Still on screen for a moment after the full explorer took over, on its
  // way out to the right.
  visible: !explorer.fullPreview && !explorer.editing && !explorer.designing
           && (explorer.sideView || slide < offDistance - 1)

  width: Style.space(380) + contentLeftInset + contentRightInset
  radius: explorer.cornerRadius
  color: explorer.background
  borderSpec: explorer.borderSpec
  padding: Style.space(16)

  readonly property int rowHeight: Style.space(76)
  readonly property int rowThumbWidth: Style.space(112)
  readonly property int rowThumbHeight: Math.round(rowThumbWidth * 9 / 16)
  readonly property var tabs: [
    { id: "favorites", name: "Favorites" },
    { id: "styling", name: "Styling" },
    { id: "animation", name: "Animation" }
  ]
  readonly property bool filtering: explorer.searchText.trim().length > 0

  function reveal() {
    list.positionViewAtIndex(explorer.selectedIndex, ListView.Contain)
  }

  function page(direction) {
    var n = explorer.designs.length
    if (n === 0) return
    var step = Math.max(1, Math.floor(list.height / rowHeight) - 1)
    explorer.selectedIndex = Math.max(0, Math.min(n - 1, explorer.selectedIndex + direction * step))
    reveal()
  }

  function focusSearch() {
    Qt.callLater(function() { searchInput.forceActiveFocus(); searchInput.selectAll() })
  }

  // Row previews start one after another from the top of the list, the way
  // the grid's do, instead of every lock screen building at once.
  property int slots: 0
  readonly property int topRow: Math.max(0, Math.floor(list.contentY / rowHeight))
  onTopRowChanged: slots = 0
  onShownChanged: if (shown) slots = 0
  Timer {
    interval: 60
    repeat: true
    running: side.shown && side.slots < 24
    onTriggered: side.slots += 1
  }

  component PanelButton: Rectangle {
    id: button
    property string label: ""
    property bool primary: false
    signal clicked()
    height: Style.space(32)
    radius: side.explorer.cornerRadius
    color: primary ? Qt.rgba(side.explorer.accent.r, side.explorer.accent.g, side.explorer.accent.b, buttonArea.containsMouse ? 1.0 : 0.88)
                   : Qt.rgba(side.fg.r, side.fg.g, side.fg.b, buttonArea.containsMouse ? 0.12 : 0.05)
    border.width: primary ? 0 : 1
    border.color: Qt.rgba(side.fg.r, side.fg.g, side.fg.b, 0.2)
    Behavior on color { ColorAnimation { duration: 100 } }
    Text {
      anchors.centerIn: parent
      width: Math.min(implicitWidth, parent.width - Style.space(12))
      elide: Text.ElideRight
      text: button.label
      textFormat: Text.PlainText
      color: button.primary ? Color.background : side.fg
      font.family: side.explorer.fontFamily
      font.pixelSize: Style.font.bodySmall
      font.weight: button.primary ? Font.DemiBold : Font.Normal
    }
    MouseArea {
      id: buttonArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: button.clicked()
    }
  }

  // Clicks on the panel stay on the panel; the window behind closes on one.
  MouseArea { anchors.fill: parent; onClicked: {} }

  Item {
    id: body
    anchors.fill: parent
    anchors.topMargin: side.contentTopInset
    anchors.bottomMargin: side.contentBottomInset
    anchors.leftMargin: side.contentLeftInset
    anchors.rightMargin: side.contentRightInset

    Column {
      id: head
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      spacing: Style.space(10)

      Row {
        spacing: Style.space(8)
        Text {
          text: "::"
          color: side.explorer.accent
          font.family: side.explorer.fontFamily
          font.pixelSize: Style.font.title
          font.weight: Font.Bold
        }
        Text {
          text: side.explorer.tr("LOCK SCREEN")
          color: side.fg
          font.family: side.explorer.fontFamily
          font.pixelSize: Style.font.title
          font.weight: Font.Bold
          font.letterSpacing: 2
        }
      }

      // Which design the picture below is, and whether it is the one in use.
      Item {
        width: parent.width
        height: shownName.implicitHeight
        Text {
          id: shownName
          anchors.left: parent.left
          anchors.right: shownState.left
          anchors.rightMargin: Style.space(8)
          elide: Text.ElideRight
          text: (side.explorer.selectedDesign ? side.explorer.selectedDesign.name : "").toUpperCase()
          textFormat: Text.PlainText
          color: side.explorer.muted
          font.family: side.explorer.fontFamily
          font.pixelSize: Style.font.caption
          font.letterSpacing: 2
        }
        Text {
          id: shownState
          anchors.right: parent.right
          readonly property bool active: !!side.explorer.selectedDesign && side.explorer.selectedDesign.id === side.explorer.activeDesignId
          text: side.explorer.selectionError.length > 0 ? side.explorer.selectionError
                : "● " + side.explorer.tr(active ? "Active" : "Live")
          textFormat: Text.PlainText
          color: side.explorer.selectionError.length > 0 ? side.explorer.danger
                 : (active ? side.explorer.accent : side.explorer.muted)
          font.family: side.explorer.fontFamily
          font.pixelSize: Style.font.caption
        }
      }

      // The selected design, drawn live and scaled down from the full screen.
      Rectangle {
        id: previewFrame
        width: parent.width
        height: Math.round(width * 9 / 16)
        radius: side.explorer.cornerRadius
        color: Color.background
        border.width: 1
        border.color: Qt.rgba(side.fg.r, side.fg.g, side.fg.b, 0.2)
        clip: true

        Item {
          x: 1
          y: 1
          width: side.screenWidth
          height: side.screenHeight
          scale: (previewFrame.width - 2) / side.screenWidth
          transformOrigin: Item.TopLeft
          enabled: false   // never let the preview's input steal keyboard focus
          LockHost {
            anchors.fill: parent
            designId: side.explorer.selectedDesign ? side.explorer.selectedDesign.id : side.explorer.activeDesignId
            revision: side.service ? side.service.designsRevision : 0
            twelveHour: side.explorer.twelveHour
            wallpaperBlur: side.explorer.wallpaperBlurValue
            wallpaperDim: side.explorer.wallpaperDimShift
            uiScale: side.explorer.uiScale
            holdStill: side.explorer.motionReduced
            language: side.explorer.lockLanguage
            fullName: side.explorer.accountName
            showLayoutBadge: side.explorer.showLayoutBadge
            showCapsBadge: side.explorer.showCapsBadge
            allowPasswordToggle: side.explorer.allowPasswordToggle
            showAuthIcons: side.explorer.showAuthIcons
            backgroundPath: side.service ? side.service.backgroundPath : ""
            backgroundVersion: side.service ? side.service.backgroundVersion : 0
            avatarPath: side.service ? side.service.avatarPath : ""
            avatarVersion: side.service ? side.service.avatarVersion : 0
            inputEnabled: false
            loadBackground: side.shown
            passwordText: "omarchy"
            videoPath: side.service ? side.service.videoPath : ""
            videoPlaying: side.shown
          }
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: side.explorer.fullPreview = true
        }
      }

      Row {
        width: parent.width
        spacing: Style.space(8)
        PanelButton {
          width: (parent.width - parent.spacing) / 2
          label: side.explorer.tr("Lock now")
          onClicked: side.explorer.lockNow()
        }
        PanelButton {
          width: (parent.width - parent.spacing) / 2
          label: side.explorer.tr("Preview") + " · Space"
          onClicked: side.explorer.fullPreview = true
        }
      }

      // Something is missing from the install: one line, and the way to it.
      Text {
        visible: side.explorer.healthIssues.length > 0
        width: parent.width
        wrapMode: Text.WordWrap
        text: side.explorer.tr("Something here keeps part of the plugin from working.") + " ›"
        textFormat: Text.PlainText
        color: side.explorer.danger
        font.family: side.explorer.fontFamily
        font.pixelSize: Style.font.caption
        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: side.explorer.openFull("settings")
        }
      }

      Rectangle {
        width: parent.width
        height: 1
        color: Qt.rgba(side.fg.r, side.fg.g, side.fg.b, 0.15)
      }

      // Search over every design, whichever tab is picked. The list keys stay
      // the list's: the field only takes the keyboard while it has focus.
      Rectangle {
        width: parent.width
        height: Style.space(30)
        radius: side.explorer.cornerRadius
        color: Qt.rgba(side.fg.r, side.fg.g, side.fg.b, side.explorer.searching ? 0.12 : 0.07)
        border.width: 1
        border.color: side.explorer.searching ? side.explorer.accent : Qt.rgba(side.fg.r, side.fg.g, side.fg.b, 0.15)

        TextInput {
          id: searchInput
          anchors.left: parent.left
          anchors.right: searchHint.left
          anchors.leftMargin: Style.space(10)
          anchors.rightMargin: Style.space(6)
          anchors.verticalCenter: parent.verticalCenter
          clip: true
          text: side.explorer.searchText
          color: side.fg
          selectionColor: side.explorer.accent
          selectedTextColor: Color.background
          font.family: side.explorer.fontFamily
          font.pixelSize: Style.font.bodySmall
          onTextEdited: side.explorer.searchText = text
          onActiveFocusChanged: if (side.shown) side.explorer.searching = activeFocus
          Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
              if (side.explorer.searchText.length > 0) side.explorer.searchText = ""
              else side.explorer.leaveSearch()
              event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                       || event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
              side.explorer.leaveSearch()
              event.accepted = true
            }
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: side.explorer.searchText.length === 0
            text: side.explorer.tr("Search designs")
            color: side.explorer.muted
            font: searchInput.font
          }
        }

        Text {
          id: searchHint
          anchors.right: parent.right
          anchors.rightMargin: Style.space(10)
          anchors.verticalCenter: parent.verticalCenter
          text: side.explorer.searchText.length > 0 ? "✕" : "/"
          color: searchClear.containsMouse ? side.fg : side.explorer.muted
          font.family: side.explorer.fontFamily
          font.pixelSize: Style.font.bodySmall
          MouseArea {
            id: searchClear
            anchors.fill: parent
            anchors.margins: -Style.space(4)
            hoverEnabled: true
            onClicked: { if (side.explorer.searchText.length > 0) side.explorer.searchText = ""; else side.explorer.focusSearch() }
          }
        }

        MouseArea {
          anchors.fill: parent
          anchors.rightMargin: searchHint.width + Style.space(14)
          z: -1
          onClicked: side.explorer.focusSearch()
        }
      }

      Row {
        spacing: Style.space(16)
        opacity: side.filtering ? 0.45 : 1
        Repeater {
          model: side.tabs
          Item {
            id: tab
            required property var modelData
            readonly property bool current: modelData.id === side.explorer.mainTab && !side.filtering
            width: tabLabel.implicitWidth
            height: tabLabel.implicitHeight + Style.space(6)
            Text {
              id: tabLabel
              text: side.explorer.tr(tab.modelData.name).toUpperCase()
              textFormat: Text.PlainText
              color: tab.current ? side.fg : side.explorer.muted
              font.family: side.explorer.fontFamily
              font.pixelSize: Style.font.caption
              font.weight: tab.current ? Font.Bold : Font.Normal
              font.letterSpacing: 1
            }
            Rectangle {
              anchors.bottom: parent.bottom
              width: parent.width
              height: Math.max(2, Style.space(2))
              color: tab.current ? side.explorer.accent : "transparent"
            }
            MouseArea {
              anchors.fill: parent
              anchors.margins: -Style.space(4)
              cursorShape: Qt.PointingHandCursor
              onClicked: { side.explorer.searchText = ""; side.explorer.mainTab = tab.modelData.id }
            }
          }
        }
      }
    }

    // What an empty list means: nothing starred yet, or no match.
    Text {
      visible: side.explorer.designs.length === 0
      anchors.top: list.top
      anchors.topMargin: Style.space(24)
      anchors.left: list.left
      anchors.right: list.right
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.WordWrap
      textFormat: Text.PlainText
      text: side.filtering
            ? side.explorer.tr("No design matches “%1”. Esc clears the search.").arg(side.explorer.searchText.trim())
            : side.explorer.tr("Nothing starred yet. Press F on a design, or click the star on its card, to keep it here.")
      color: side.explorer.muted
      font.family: side.explorer.fontFamily
      font.pixelSize: Style.font.bodySmall
    }

    ListView {
      id: list
      anchors.top: head.bottom
      anchors.topMargin: Style.space(8)
      anchors.bottom: fullButton.top
      anchors.bottomMargin: Style.space(10)
      anchors.left: parent.left
      anchors.right: parent.right
      clip: true
      model: side.explorer.designs
      cacheBuffer: side.rowHeight * 2
      boundsBehavior: Flickable.StopAtBounds
      flickDeceleration: 4000
      maximumFlickVelocity: 3000

      delegate: Rectangle {
        id: row
        required property var modelData
        required property int index
        readonly property bool selected: index === side.explorer.selectedIndex
        readonly property bool active: modelData.id === side.explorer.activeDesignId
        readonly property bool starred: side.explorer.isFavorite(modelData.id)
        width: list.width
        height: side.rowHeight
        color: selected ? Qt.rgba(side.fg.r, side.fg.g, side.fg.b, 0.08)
                        : Qt.rgba(side.fg.r, side.fg.g, side.fg.b, rowArea.containsMouse ? 0.04 : 0.0)

        // Its turn to build: see slots. Once started it stays built.
        readonly property int rank: index - side.topRow
        readonly property bool mayLoad: side.shown && rank >= 0 && rank < side.slots
        property bool wanted: false
        onMayLoadChanged: if (mayLoad) wanted = true
        Component.onCompleted: if (mayLoad) wanted = true

        // The grid's picture of this design, when it has taken one, shows
        // until the live one has had a moment to draw.
        readonly property string cachedThumb: side.explorer.thumbFor(modelData.id)
        readonly property bool designUp: thumbLoader.status === Loader.Ready && !!thumbLoader.item
        property bool liveShown: false
        onDesignUpChanged: if (designUp) liveTimer.restart()
        Timer { id: liveTimer; interval: row.cachedThumb.length > 0 ? 700 : 150; onTriggered: row.liveShown = true }

        Rectangle {
          anchors.left: parent.left
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          width: Math.max(2, Style.space(2))
          color: row.selected ? side.explorer.accent : "transparent"
        }

        MouseArea {
          id: rowArea
          anchors.fill: parent
          hoverEnabled: true
          onClicked: side.explorer.selectedIndex = row.index
          onDoubleClicked: { side.explorer.selectedIndex = row.index; side.explorer.useSelected() }
        }

        Rectangle {
          id: thumbFrame
          anchors.left: parent.left
          anchors.leftMargin: Style.space(8)
          anchors.verticalCenter: parent.verticalCenter
          width: side.rowThumbWidth
          height: side.rowThumbHeight
          radius: side.explorer.cornerRadius
          color: Color.background
          border.width: 1
          border.color: row.active ? side.explorer.accent : Qt.rgba(side.fg.r, side.fg.g, side.fg.b, 0.18)
          clip: true

          Image {
            anchors.fill: parent
            anchors.margins: 1
            visible: source != "" && !(row.liveShown && row.designUp)
            source: row.cachedThumb
            cache: false
            smooth: true
          }
          Item {
            x: 1
            y: 1
            width: side.screenWidth
            height: side.screenHeight
            scale: (thumbFrame.width - 2) / side.screenWidth
            transformOrigin: Item.TopLeft
            enabled: false
            opacity: row.liveShown ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 180 } }
            Loader {
              id: thumbLoader
              anchors.fill: parent
              asynchronous: true
              active: row.wanted
              sourceComponent: LockHost {
                stillTextureSize: Qt.size(side.rowThumbWidth, side.rowThumbHeight)
                designId: row.modelData.id
                revision: side.service ? side.service.designsRevision : 0
                twelveHour: side.explorer.twelveHour
                wallpaperBlur: side.explorer.wallpaperBlurValue
                wallpaperDim: side.explorer.wallpaperDimShift
                uiScale: side.explorer.uiScale
                // A row is too small for motion to read; a still is enough.
                holdStill: true
                language: side.explorer.lockLanguage
                fullName: side.explorer.accountName
                showLayoutBadge: side.explorer.showLayoutBadge
                showCapsBadge: side.explorer.showCapsBadge
                allowPasswordToggle: side.explorer.allowPasswordToggle
                showAuthIcons: side.explorer.showAuthIcons
                backgroundPath: side.service ? side.service.backgroundPath : ""
                backgroundVersion: side.service ? side.service.backgroundVersion : 0
                avatarPath: side.service ? side.service.avatarPath : ""
                avatarVersion: side.service ? side.service.avatarVersion : 0
                inputEnabled: false
                loadBackground: side.shown
                passwordText: "omarchy"
                videoPath: side.service ? side.service.videoPath : ""
                videoPlaying: false
              }
            }
          }
        }

        Column {
          anchors.left: thumbFrame.right
          anchors.leftMargin: Style.space(12)
          anchors.right: star.left
          anchors.rightMargin: Style.space(6)
          anchors.verticalCenter: parent.verticalCenter
          spacing: 3
          Text {
            width: parent.width
            elide: Text.ElideRight
            text: row.modelData.name
            textFormat: Text.PlainText
            color: row.selected ? side.fg : side.explorer.muted
            font.family: side.explorer.fontFamily
            font.pixelSize: Style.font.title
            font.weight: row.selected ? Font.DemiBold : Font.Normal
          }
          Text {
            width: parent.width
            elide: Text.ElideRight
            text: row.active ? "󰄬 " + side.explorer.tr("Active")
                  : (row.selected ? side.explorer.tr("Use") + "  ⏎" : (row.modelData.description || ""))
            textFormat: Text.PlainText
            color: row.active ? side.explorer.accent : side.explorer.muted
            font.family: side.explorer.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
        }

        Text {
          id: star
          anchors.right: parent.right
          anchors.rightMargin: Style.space(10)
          anchors.verticalCenter: parent.verticalCenter
          visible: row.starred || row.selected || rowArea.containsMouse
          text: row.starred ? "★" : "☆"
          color: row.starred ? side.explorer.accent : side.explorer.muted
          font.family: side.explorer.fontFamily
          font.pixelSize: Style.font.title
          MouseArea {
            anchors.fill: parent
            anchors.margins: -Style.space(6)
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              side.explorer.selectedIndex = row.index
              if (side.service && typeof side.service.toggleFavorite === "function") side.service.toggleFavorite(row.modelData.id)
            }
          }
        }
      }
    }

    // Above the list for the same reason as over the grid: the rows' own
    // mouse areas eat wheel events before the list sees them.
    MouseArea {
      anchors.fill: list
      acceptedButtons: Qt.NoButton
      onWheel: function(wheel) {
        var dy = wheel.pixelDelta.y !== 0 ? wheel.pixelDelta.y : wheel.angleDelta.y * 1.2
        var next = list.contentY - dy
        list.contentY = Math.max(0, Math.min(Math.max(0, list.contentHeight - list.height), next))
      }
    }

    Rectangle {
      anchors.top: list.top
      anchors.bottom: list.bottom
      anchors.left: list.right
      anchors.leftMargin: Style.space(4)
      width: 4
      radius: 2
      visible: list.contentHeight > list.height
      color: Qt.rgba(side.fg.r, side.fg.g, side.fg.b, 0.08)
      Rectangle {
        width: parent.width
        radius: 2
        color: Qt.rgba(side.fg.r, side.fg.g, side.fg.b, 0.35)
        height: Math.max(24, parent.height * list.height / Math.max(1, list.contentHeight))
        y: (parent.height - height) * (list.contentY / Math.max(1, list.contentHeight - list.height))
      }
    }

    PanelButton {
      id: fullButton
      anchors.bottom: parent.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      primary: true
      label: side.explorer.tr("Open full explorer") + " · O"
      onClicked: side.explorer.openFull("")
    }
  }
}
