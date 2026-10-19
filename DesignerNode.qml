import QtQuick
import qs.Commons
import qs.Commons as Commons
import "designs"
import "Designer.js" as D

// One node on the designer's canvas: the real DesignerItem, plus the editing
// chrome (outline, drag, resize handles) that never ships in a design file.
//
// Geometry comes from the layout's anchor rule measured against the item's
// live size, so the canvas places things exactly where the generated anchors
// will put them on the lock screen. `node` is a LayoutNode, so every binding
// below repaints on its own when the piece is moved or restyled.
Item {
  id: nodeRoot

  property var stage: null
  property LayoutNode node: null

  readonly property bool fill: node ? D.isFill(node) : false
  readonly property bool selected: (stage && node) ? stage.selection.indexOf(node.nodeId) !== -1 : false
  readonly property bool editing: stage ? stage.editing : false
  // Canvas scale, so the chrome keeps a constant size on screen.
  readonly property real vs: (stage && stage.viewScale > 0) ? stage.viewScale : 1
  readonly property real hair: 1 / vs
  readonly property real grip: 9 / vs

  x: (fill || !node || !parent) ? 0 : D.xFor(node, width, parent.width)
  y: (fill || !node || !parent) ? 0 : D.yFor(node, height, parent.height)
  width: fill && parent ? parent.width : inner.width
  height: fill && parent ? parent.height : inner.height

  DesignerItem {
    id: inner
    lock: nodeRoot.stage
    kind: nodeRoot.node ? nodeRoot.node.kind : "label"
    fillParent: nodeRoot.fill
    fixedWidth: nodeRoot.node ? nodeRoot.node.w : 0
    fixedHeight: nodeRoot.node ? nodeRoot.node.h : 0
    spec: nodeRoot.node ? nodeRoot.node.spec : ({})
    customQml: (nodeRoot.node && nodeRoot.node.kind === "custom") ? String(nodeRoot.node.spec.qml || "") : ""
  }

  // An empty piece (a label with no text, a picture with no file) would be
  // impossible to grab, so give it a footprint while editing.
  Rectangle {
    anchors.centerIn: parent
    visible: nodeRoot.editing && !nodeRoot.fill && (nodeRoot.width < 8 || nodeRoot.height < 8)
    width: 80
    height: 30
    color: Qt.rgba(1, 1, 1, 0.06)
    border.width: nodeRoot.hair
    border.color: Qt.rgba(1, 1, 1, 0.3)
  }

  Rectangle {
    anchors.fill: parent
    visible: nodeRoot.editing && (nodeRoot.selected || hoverArea.containsMouse)
    color: "transparent"
    border.width: nodeRoot.selected ? 2 * nodeRoot.hair : nodeRoot.hair
    border.color: nodeRoot.selected ? Commons.Color.accent : Qt.rgba(1, 1, 1, 0.45)
  }

  MouseArea {
    id: hoverArea
    anchors.fill: parent
    // The full-screen backgrounds stay out of the way: a click that lands on
    // one is a click on empty canvas, and the layer list is how they are
    // picked. Otherwise nothing else could ever be deselected.
    enabled: nodeRoot.editing && !nodeRoot.fill
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton

    property real pressX: 0
    property real pressY: 0
    property real startX: 0
    property real startY: 0
    property bool moving: false

    onPressed: function(mouse) {
      if (!nodeRoot.node || !nodeRoot.stage) return
      nodeRoot.stage.nodePressed(nodeRoot.node.nodeId, (mouse.modifiers & Qt.ControlModifier) !== 0)
      var p = mapToItem(nodeRoot.parent, mouse.x, mouse.y)
      pressX = p.x
      pressY = p.y
      startX = nodeRoot.x
      startY = nodeRoot.y
      moving = false
    }
    onPositionChanged: function(mouse) {
      if (!pressed || !nodeRoot.node || !nodeRoot.stage) return
      var p = mapToItem(nodeRoot.parent, mouse.x, mouse.y)
      var ddx = p.x - pressX
      var ddy = p.y - pressY
      // A couple of pixels of slop, so a click does not nudge anything.
      if (!moving && Math.abs(ddx) < 3 && Math.abs(ddy) < 3) return
      moving = true
      nodeRoot.stage.nodeDragged(nodeRoot.node.nodeId, startX + ddx, startY + ddy)
    }
    onReleased: {
      if (nodeRoot.stage) nodeRoot.stage.nodeDragEnded()
      moving = false
    }
  }

  // Resize handles: the right edge, the bottom edge and the corner. The
  // top-left stays put, whatever the anchor is.
  Repeater {
    model: (nodeRoot.editing && nodeRoot.selected && nodeRoot.node && D.isSized(nodeRoot.node))
      ? ["right", "bottom", "corner"] : []

    Rectangle {
      id: handle
      required property string modelData
      readonly property bool horizontal: modelData !== "bottom"
      readonly property bool vertical: modelData !== "right"
      readonly property bool square: nodeRoot.node ? D.isSquare(nodeRoot.node) : false
      visible: !(square && modelData !== "corner")
      width: nodeRoot.grip
      height: nodeRoot.grip
      radius: nodeRoot.hair
      color: Commons.Color.accent
      border.width: nodeRoot.hair
      border.color: Qt.rgba(0, 0, 0, 0.6)
      x: horizontal ? nodeRoot.width - width / 2 : (nodeRoot.width - width) / 2
      y: vertical ? nodeRoot.height - height / 2 : (nodeRoot.height - height) / 2

      MouseArea {
        anchors.fill: parent
        anchors.margins: -nodeRoot.grip / 2
        property real pressX: 0
        property real pressY: 0
        property real startW: 0
        property real startH: 0
        onPressed: function(mouse) {
          var p = mapToItem(nodeRoot.parent, mouse.x, mouse.y)
          pressX = p.x
          pressY = p.y
          startW = nodeRoot.width
          startH = nodeRoot.height
        }
        onPositionChanged: function(mouse) {
          if (!pressed || !nodeRoot.node || !nodeRoot.stage) return
          var p = mapToItem(nodeRoot.parent, mouse.x, mouse.y)
          var w = handle.horizontal ? startW + (p.x - pressX) : startW
          var h = handle.vertical ? startH + (p.y - pressY) : startH
          if (handle.square) { w = Math.max(w, h); h = w }
          nodeRoot.stage.nodeResized(nodeRoot.node.nodeId, Math.max(4, Math.round(w)), Math.max(1, Math.round(h)))
        }
        onReleased: if (nodeRoot.stage) nodeRoot.stage.nodeDragEnded()
      }
    }
  }
}
