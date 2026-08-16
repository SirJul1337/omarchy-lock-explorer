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

  readonly property var designs: Designs.all()
  readonly property string pluginId: manifest && manifest.id ? String(manifest.id) : "io.github.sirjul1337.lock-explorer"
  readonly property string activeDesignId: service ? service.designId : Designs.DEFAULT_ID
  readonly property var selectedDesign: designs[Math.max(0, Math.min(selectedIndex, designs.length - 1))]

  readonly property color background: Color.menu.background
  readonly property color foreground: Color.menu.text
  readonly property color muted: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.6)
  readonly property color accent: Color.accent
  readonly property color scrim: Color.menu.scrim
  readonly property var borderSpec: Border.surfaceSpec("menu", "border", Color.menu.border, Math.max(1, Style.space(2)))
  readonly property int cornerRadius: Style.cornerRadius
  readonly property string fontFamily: Style.font.menuFamily

  readonly property int columns: 3
  readonly property int rows: Math.ceil(designs.length / columns)
  readonly property int contentMargin: Style.spacing.panelPadding + Style.space(8)
  readonly property int gap: Style.space(18)
  readonly property int cardWidth: Math.min(Style.space(1240), panel.width - Style.gapsOut * 4)
  readonly property int thumbWidth: Math.floor((cardWidth - contentMargin * 2 - gap * (columns - 1)) / columns)
  readonly property int thumbHeight: Math.round(thumbWidth * 9 / 16)
  readonly property int captionHeight: Style.space(56)
  readonly property int headerHeight: Style.space(64)
  readonly property int footerHeight: Style.space(40)
  readonly property int cardHeight: headerHeight + rows * (thumbHeight + captionHeight) + (rows - 1) * gap + footerHeight + contentMargin * 2 + Math.max(1, Style.space(2)) * 2

  function open(payloadJson) {
    root.opened = true
    root.fullPreview = false
    var idx = Designs.indexOf(root.activeDesignId)
    root.selectedIndex = idx >= 0 ? idx : 0
    if (root.service) {
      if (typeof root.service.refreshBackground === "function") root.service.refreshBackground()
      if (typeof root.service.refreshFingerprintStatus === "function") root.service.refreshFingerprintStatus()
    }
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
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

  function move(delta) {
    var n = designs.length
    if (n === 0) return
    selectedIndex = (selectedIndex + delta + n) % n
  }

  function moveRow(delta) {
    var next = selectedIndex + delta * columns
    if (next < 0 || next >= designs.length) return
    selectedIndex = next
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
        } else if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
          root.move(-1); event.accepted = true
        } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L || event.key === Qt.Key_Tab) {
          root.move(1); event.accepted = true
        } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
          if (root.fullPreview) root.move(-1); else root.moveRow(-1)
          event.accepted = true
        } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
          if (root.fullPreview) root.move(1); else root.moveRow(1)
          event.accepted = true
        } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
          var i = event.key - Qt.Key_1
          if (i < root.designs.length) root.selectedIndex = i
          event.accepted = true
        }
      }
    }

    BorderSurface {
      id: card
      visible: !root.fullPreview
      width: root.cardWidth
      height: Math.min(root.cardHeight, panel.height - Style.gapsOut * 2)
      radius: root.cornerRadius
      anchors.centerIn: parent
      color: root.background
      borderSpec: root.borderSpec
      padding: root.contentMargin

      MouseArea { anchors.fill: parent; onClicked: {} }

      Column {
        id: cardContent
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset
        anchors.rightMargin: card.contentRightInset
        spacing: 0

        Item {
          width: parent.width
          height: root.headerHeight
          Column {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Text {
              text: "Lock Screen Explorer"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
              font.weight: Font.DemiBold
            }
            Text {
              text: root.designs.length + " designs"
              color: root.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
          }
          Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(6)
            Rectangle {
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
          }
        }

        Grid {
          id: grid
          columns: root.columns
          columnSpacing: root.gap
          rowSpacing: root.gap

          Repeater {
            model: root.designs
            delegate: Item {
              id: cell
              required property var modelData
              required property int index
              readonly property bool selected: index === root.selectedIndex
              readonly property bool active: modelData.id === root.activeDesignId
              width: root.thumbWidth
              height: root.thumbHeight + root.captionHeight

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
                  anchors.fill: parent
                  radius: frame.radius
                  color: "transparent"
                  border.width: 1
                  border.color: cell.selected ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.35) : "transparent"
                  anchors.margins: -3
                }

                Rectangle {
                  anchors.left: parent.left; anchors.top: parent.top; anchors.margins: Style.space(8)
                  width: Style.space(22); height: Style.space(22); radius: 4
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
                  anchors.right: parent.right; anchors.top: parent.top; anchors.margins: Style.space(8)
                  width: activeText.implicitWidth + Style.space(14); height: Style.space(22); radius: height / 2
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
                  hoverEnabled: true
                  onEntered: root.selectedIndex = cell.index
                  onClicked: root.selectedIndex = cell.index
                  onDoubleClicked: { root.selectedIndex = cell.index; root.apply() }
                }
              }

              Column {
                anchors.top: frame.bottom
                anchors.topMargin: Style.space(8)
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 2
                Text {
                  text: cell.modelData.name
                  color: cell.selected ? root.foreground : root.muted
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.title
                  font.weight: cell.selected ? Font.DemiBold : Font.Normal
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
        }

        Item {
          width: parent.width
          height: root.footerHeight
          Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "Arrows: browse   Space: preview   Enter: select   Esc: close"
            color: root.muted
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
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
