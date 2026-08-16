import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "Designs.js" as Designs

Item {
  id: root

  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null
  property var service: null

  property bool opened: false
  property int selectedIndex: 0
  property bool fullPreview: false
  property string category: "all"

  readonly property var categories: Designs.categories()
  readonly property var designs: Designs.inCategory(category)
  readonly property string pluginId: manifest && manifest.id ? String(manifest.id) : "io.github.sirjul1337.lock-explorer"
  readonly property string activeDesignId: service ? service.designId : Designs.DEFAULT_ID
  readonly property var selectedDesign: designs.length > 0 ? designs[Math.max(0, Math.min(selectedIndex, designs.length - 1))] : null

  readonly property color background: Color.menu.background
  readonly property color foreground: Color.menu.text
  readonly property color muted: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.6)
  readonly property color accent: Color.accent
  readonly property color scrim: Color.menu.scrim
  readonly property var borderSpec: Border.surfaceSpec("menu", "border", Color.menu.border, Math.max(1, Style.space(2)))
  readonly property int cornerRadius: Style.cornerRadius
  readonly property string fontFamily: Style.font.menuFamily

  readonly property int columns: 3
  readonly property int contentMargin: Style.spacing.panelPadding + Style.space(8)
  readonly property int gap: Style.space(20)
  readonly property int captionHeight: Style.space(58)
  readonly property int headerHeight: Style.space(96)
  readonly property int footerHeight: Style.space(40)
  readonly property int borderWidth: Math.max(1, Style.space(2))
  readonly property int cardWidth: Math.min(Style.space(1560), panel.width - Style.gapsOut * 4)
  readonly property int cardHeight: panel.height - Style.gapsOut * 2
  readonly property int cellWidth: Math.floor(grid.width / columns)
  readonly property int thumbWidth: cellWidth - gap
  readonly property int thumbHeight: Math.round(thumbWidth * 9 / 16)

  function open(payloadJson) {
    root.opened = true
    root.fullPreview = false
    root.category = "all"
    var idx = Designs.indexOf(root.activeDesignId)
    root.selectedIndex = idx >= 0 ? idx : 0
    if (root.service) {
      if (typeof root.service.refreshBackground === "function") root.service.refreshBackground()
      if (typeof root.service.refreshFingerprintStatus === "function") root.service.refreshFingerprintStatus()
    }
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
    revealTimer.restart()
  }

  Timer {
    id: revealTimer
    interval: 80
    onTriggered: {
      root.reveal(GridView.Center)
      keyCatcher.forceActiveFocus()
    }
  }

  function close() { root.opened = false }

  function dismiss() {
    root.opened = false
    root.fullPreview = false
    if (root.shell && typeof root.shell.hide === "function") root.shell.hide(root.pluginId)
  }

  function toggle() {
    if (root.opened) root.dismiss()
    else root.open("{}")
  }

  function positionAtSelected(mode) {
    grid.positionViewAtIndex(root.selectedIndex, mode)
    var minY = grid.originY - grid.topMargin
    var maxY = Math.max(minY, grid.originY + grid.contentHeight - grid.height + grid.bottomMargin)
    if (grid.contentY < minY) grid.contentY = minY
    else if (grid.contentY > maxY) grid.contentY = maxY
  }

  function reveal(mode) {
    positionAtSelected(mode)
    Qt.callLater(function() { positionAtSelected(mode) })
  }

  function setCategory(id) {
    if (id === root.category) return
    var current = root.selectedDesign ? root.selectedDesign.id : ""
    root.category = id
    var list = Designs.inCategory(id)
    var keep = -1
    for (var i = 0; i < list.length; i++) if (list[i].id === current) keep = i
    root.selectedIndex = keep >= 0 ? keep : 0
    reveal(GridView.Contain)
  }

  function cycleCategory(delta) {
    var n = categories.length
    var cur = 0
    for (var i = 0; i < n; i++) if (categories[i].id === root.category) cur = i
    setCategory(categories[(cur + delta + n) % n].id)
  }

  function move(delta) {
    var n = designs.length
    if (n === 0) return
    selectedIndex = (selectedIndex + delta + n) % n
    reveal(GridView.Contain)
  }

  function moveRow(delta) {
    var next = selectedIndex + delta * columns
    if (next < 0 || next >= designs.length) return
    selectedIndex = next
    reveal(GridView.Contain)
  }

  function apply() {
    if (!selectedDesign) return
    if (root.service && typeof root.service.setDesign === "function") root.service.setDesign(selectedDesign.id)
    root.dismiss()
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-lock-explorer"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Rectangle { anchors.fill: parent; color: root.scrim }
    MouseArea { anchors.fill: parent; onClicked: root.dismiss() }

    Item {
      id: keyCatcher
      anchors.fill: parent
      focus: true
      Keys.priority: Keys.BeforeItem
      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
          if (root.fullPreview) root.fullPreview = false
          else root.dismiss()
          event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
          root.apply(); event.accepted = true
        } else if (event.key === Qt.Key_Space || event.key === Qt.Key_P) {
          root.fullPreview = !root.fullPreview; event.accepted = true
        } else if (event.key === Qt.Key_Tab) {
          root.cycleCategory(1); event.accepted = true
        } else if (event.key === Qt.Key_Backtab) {
          root.cycleCategory(-1); event.accepted = true
        } else if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
          root.move(-1); event.accepted = true
        } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
          root.move(1); event.accepted = true
        } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
          if (root.fullPreview) root.move(-1); else root.moveRow(-1)
          event.accepted = true
        } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
          if (root.fullPreview) root.move(1); else root.moveRow(1)
          event.accepted = true
        } else if (event.key === Qt.Key_Home) {
          root.selectedIndex = 0; root.reveal(GridView.Beginning); event.accepted = true
        } else if (event.key === Qt.Key_End) {
          root.selectedIndex = Math.max(0, root.designs.length - 1); root.reveal(GridView.End); event.accepted = true
        } else if (event.key === Qt.Key_PageDown) {
          grid.contentY = Math.min(grid.contentHeight - grid.height, grid.contentY + grid.height); event.accepted = true
        } else if (event.key === Qt.Key_PageUp) {
          grid.contentY = Math.max(0, grid.contentY - grid.height); event.accepted = true
        }
      }
    }

    BorderSurface {
      id: card
      visible: !root.fullPreview
      width: root.cardWidth
      height: root.cardHeight
      radius: root.cornerRadius
      anchors.centerIn: parent
      color: root.background
      borderSpec: root.borderSpec
      padding: root.contentMargin

      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: card.contentTopInset
        anchors.leftMargin: card.contentLeftInset
        anchors.rightMargin: card.contentRightInset
        height: root.headerHeight

        Column {
          anchors.left: parent.left
          anchors.top: parent.top
          spacing: 2
          Text {
            text: "Lock Screen Explorer"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.display
            font.weight: Font.DemiBold
          }
          Text {
            text: root.designs.length + (root.category === "all" ? " designs" : " of " + Designs.all().length + " designs")
            color: root.muted
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
        }

        Rectangle {
          anchors.right: parent.right
          anchors.top: parent.top
          width: activeLabel.implicitWidth + Style.space(20); height: Style.space(28); radius: height / 2
          color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.18)
          border.width: 1; border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.5)
          Text {
            id: activeLabel
            anchors.centerIn: parent
            text: "Active: " + (Designs.byId(root.activeDesignId) ? Designs.byId(root.activeDesignId).name : root.activeDesignId)
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
        }

        Row {
          anchors.left: parent.left
          anchors.bottom: parent.bottom
          anchors.bottomMargin: Style.space(10)
          spacing: Style.space(8)
          Repeater {
            model: root.categories
            Rectangle {
              id: chip
              required property var modelData
              readonly property bool current: modelData.id === root.category
              width: chipLabel.implicitWidth + Style.space(24)
              height: Style.space(30)
              radius: height / 2
              color: current ? root.accent : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, chipArea.containsMouse ? 0.12 : 0.06)
              border.width: 1
              border.color: current ? root.accent : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.15)
              Behavior on color { ColorAnimation { duration: 100 } }
              Text {
                id: chipLabel
                anchors.centerIn: parent
                text: chip.modelData.name
                color: chip.current ? Color.background : root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                font.weight: chip.current ? Font.DemiBold : Font.Normal
              }
              MouseArea {
                id: chipArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.setCategory(chip.modelData.id)
              }
            }
          }
        }
      }

      GridView {
        id: grid
        anchors.top: header.bottom
        anchors.bottom: footer.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: card.contentLeftInset
        anchors.rightMargin: card.contentRightInset - Style.space(4)
        anchors.bottomMargin: Style.space(8)
        clip: true
        model: root.designs
        cellWidth: root.cellWidth
        cellHeight: root.thumbHeight + root.captionHeight + root.gap
        topMargin: Style.space(4)
        cacheBuffer: cellHeight
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 4000
        maximumFlickVelocity: 3000

        MouseArea {
          anchors.fill: parent
          z: -1
          onWheel: function(wheel) {
            var next = grid.contentY - wheel.angleDelta.y * 1.2
            grid.contentY = Math.max(0, Math.min(Math.max(0, grid.contentHeight - grid.height), next))
          }
        }

        delegate: Item {
          id: cell
          required property var modelData
          required property int index
          readonly property bool selected: index === root.selectedIndex
          readonly property bool active: modelData.id === root.activeDesignId
          width: grid.cellWidth
          height: grid.cellHeight

          Rectangle {
            id: frame
            width: root.thumbWidth
            height: root.thumbHeight
            radius: Math.max(6, root.cornerRadius)
            color: Color.background
            border.width: cell.selected ? 3 : 1
            border.color: cell.selected ? root.accent : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.18)
            clip: true
            Behavior on border.color { ColorAnimation { duration: 120 } }

            Item {
              anchors.fill: parent
              anchors.margins: frame.border.width
              clip: true
              Item {
                width: panel.width
                height: panel.height
                scale: (frame.width - frame.border.width * 2) / panel.width
                transformOrigin: Item.TopLeft
                LockHost {
                  anchors.fill: parent
                  designId: cell.modelData.id
                  backgroundPath: root.service ? root.service.backgroundPath : ""
                  backgroundVersion: root.service ? root.service.backgroundVersion : 0
                  fingerprintConfigured: root.service ? root.service.fingerprintConfigured : false
                  inputEnabled: false
                  loadBackground: root.opened
                  passwordText: "omarchy"
                }
              }
            }

            Rectangle {
              anchors.left: parent.left; anchors.top: parent.top; anchors.margins: Style.space(10)
              width: Style.space(24); height: Style.space(24); radius: 5
              color: Qt.rgba(0, 0, 0, 0.55)
              Text {
                anchors.centerIn: parent
                text: (cell.index + 1)
                color: "#ffffff"
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }
            }

            Rectangle {
              visible: cell.active
              anchors.right: parent.right; anchors.top: parent.top; anchors.margins: Style.space(10)
              width: activeText.implicitWidth + Style.space(14); height: Style.space(24); radius: height / 2
              color: root.accent
              Text {
                id: activeText
                anchors.centerIn: parent
                text: "󰄬 Active"
                color: Color.background
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }
            }

            MouseArea {
              anchors.fill: parent
              onClicked: root.selectedIndex = cell.index
              onDoubleClicked: { root.selectedIndex = cell.index; root.apply() }
            }
          }

          Column {
            anchors.top: frame.bottom
            anchors.topMargin: Style.space(8)
            width: root.thumbWidth
            spacing: 2
            Row {
              spacing: Style.space(8)
              Text {
                text: cell.modelData.name
                color: cell.selected ? root.foreground : root.muted
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
                font.weight: cell.selected ? Font.DemiBold : Font.Normal
              }
              Row {
                spacing: Style.space(4)
                anchors.verticalCenter: parent.verticalCenter
                Repeater {
                  model: cell.modelData.tags || []
                  Rectangle {
                    required property string modelData
                    width: tagLabel.implicitWidth + Style.space(10)
                    height: Style.space(18)
                    radius: 4
                    color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)
                    Text {
                      id: tagLabel
                      anchors.centerIn: parent
                      text: {
                        var cats = Designs.categories()
                        for (var i = 0; i < cats.length; i++) if (cats[i].id === parent.modelData) return cats[i].name
                        return parent.modelData
                      }
                      color: root.muted
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                    }
                  }
                }
              }
            }
            Text {
              width: parent.width
              text: cell.modelData.description
              color: root.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
              maximumLineCount: 1
            }
          }
        }
      }

      Rectangle {
        anchors.top: grid.top
        anchors.bottom: grid.bottom
        anchors.right: parent.right
        anchors.rightMargin: card.contentRightInset - Style.space(4)
        width: 4
        radius: 2
        visible: grid.contentHeight > grid.height
        color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)
        Rectangle {
          width: parent.width
          radius: 2
          color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.35)
          height: Math.max(24, parent.height * grid.height / Math.max(1, grid.contentHeight))
          y: (parent.height - height) * (grid.contentY / Math.max(1, grid.contentHeight - grid.height))
        }
      }

      Item {
        id: footer
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset
        anchors.rightMargin: card.contentRightInset
        height: root.footerHeight
        Text {
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          text: "Arrows: browse   Tab: category   Space: preview   Enter: select   Esc: close"
          color: root.muted
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
        }
      }
    }

    Item {
      anchors.fill: parent
      visible: root.fullPreview

      LockHost {
        anchors.fill: parent
        designId: root.selectedDesign ? root.selectedDesign.id : Designs.DEFAULT_ID
        backgroundPath: root.service ? root.service.backgroundPath : ""
        backgroundVersion: root.service ? root.service.backgroundVersion : 0
        fingerprintConfigured: root.service ? root.service.fingerprintConfigured : false
        inputEnabled: false
        loadBackground: root.opened && root.fullPreview
        passwordText: ""
      }

      MouseArea { anchors.fill: parent; onClicked: root.fullPreview = false }

      Rectangle {
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: Style.space(20)
        width: hud.implicitWidth + Style.space(32)
        height: hud.implicitHeight + Style.space(20)
        radius: height / 2
        color: Qt.rgba(root.background.r, root.background.g, root.background.b, 0.85)
        border.width: 1
        border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.2)
        Row {
          id: hud
          anchors.centerIn: parent
          spacing: Style.space(18)
          Text {
            text: (root.selectedIndex + 1) + "/" + root.designs.length + "   " + (root.selectedDesign ? root.selectedDesign.name : "")
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
            font.weight: Font.DemiBold
          }
          Text {
            text: "Arrows: next   Enter: select   Esc: back"
            color: root.muted
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            anchors.verticalCenter: parent.verticalCenter
          }
        }
      }
    }
  }
}
