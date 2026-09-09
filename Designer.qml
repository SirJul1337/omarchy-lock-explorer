import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "designs"
import "Designer.js" as D

// The visual designer: a palette of pieces on the left, the lock screen at
// its real size in the middle, and the settings for whatever is selected on
// the right.
//
// The layout is a list of LayoutNode objects; the canvas renders it through
// the same DesignerItem the generated file uses, so the canvas is the lock
// screen, not a drawing of it. Saving writes the QML, with the layout itself
// on one comment line for the next time it is opened.
Item {
  id: designer

  property var service: null
  property var design: null
  property string pluginId: "io.github.sirjul1337.lock-explorer"
  property color background: Color.menu.background
  property color foreground: Color.menu.text
  property color accent: Color.accent
  property string fontFamily: Style.font.menuFamily
  property real screenWidth: 1920
  property real screenHeight: 1080

  readonly property color muted: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.55)
  readonly property color line: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.14)
  readonly property color well: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.05)

  readonly property string path: design && design.path
    ? decodeURIComponent(String(design.path).replace(/^file:\/\//, "")) : ""

  // The layout, as LayoutNode objects. `nodes` is reassigned (a fresh array)
  // whenever pieces are added, removed or restacked; editing one needs no
  // announcement, the canvas is bound to its properties.
  property var nodes: []
  property string docName: D.DEFAULT_NAME
  property var selection: []
  property bool dirty: false
  property bool confirmDiscard: false
  property string status: ""
  property string loadError: ""
  property var undoStack: []
  property var redoStack: []
  property string undoTag: ""
  property var guides: []
  // Set while the file dialog is up, so the picked path lands in the right
  // place when the explorer comes back.
  property string pendingFileKey: ""
  property bool namingComponent: false
  property string hoverHint: ""

  readonly property var primary: selection.length === 0 ? null : nodeById(selection[selection.length - 1])
  readonly property var primaryKind: primary ? D.kind(primary.kind) : null
  readonly property var componentList: service ? service.components : []

  signal closeRequested()
  signal openCodeRequested(string path)
  signal useRequested()
  signal pickFileRequested()

  Component {
    id: nodeComponent
    LayoutNode {}
  }

  function makeNode(plain) {
    return nodeComponent.createObject(designer, {
      nodeId: plain.id, kind: plain.kind, anchor: plain.anchor,
      dx: plain.dx, dy: plain.dy, w: plain.w, h: plain.h, spec: plain.spec
    })
  }

  function currentDoc() { return D.docOf(designer.nodes, designer.docName) }

  function newNodeId() { return D.nextIdFrom(D.idsOf(designer.nodes)) }

  // -------------------------------------------------------------- the file

  FileView {
    id: file
    path: designer.path
    watchChanges: false
    atomicWrites: true
    printErrors: false
    onSaved: {
      designer.status = "Saved " + Qt.formatTime(new Date(), "HH:mm:ss")
      designer.dirty = false
      if (designer.service && typeof designer.service.reloadDesigns === "function")
        designer.service.reloadDesigns()
    }
    onSaveFailed: function(error) { designer.status = "Save failed: " + error }
    onLoadFailed: designer.loadError = "Cannot read " + designer.path
    onLoaded: designer.adopt(file.text())
  }

  onPathChanged: if (path.length > 0) load()

  // Take the keyboard as soon as the designer is actually on screen. Asking
  // for it when the explorer switches views is too early — the card is not
  // laid out yet, the focus attempt is dropped, and every shortcut here stays
  // dead until the first click lands inside.
  onVisibleChanged: if (visible) Qt.callLater(designer.focusCanvas)

  function load() {
    loadError = ""
    status = ""
    file.reload()
  }

  function adopt(text) {
    var parsed = D.parse(text)
    if (!parsed) {
      loadError = "This design was not made in the designer. Open it with the code editor instead."
      return
    }
    loadError = ""
    applyDoc(parsed)
    undoStack = []
    redoStack = []
    dirty = false
    confirmDiscard = false
  }

  function applyDoc(plain) {
    var gone = designer.nodes
    var made = []
    for (var i = 0; i < plain.nodes.length; i++) made.push(makeNode(plain.nodes[i]))
    designer.docName = plain.name
    designer.nodes = made
    designer.selection = []
    // Only once the canvas has let go of them.
    syncNodes()
    for (var j = 0; j < gone.length; j++) gone[j].destroy()
  }

  function save() {
    if (path.length === 0) return
    file.setText(D.generate(currentDoc(), pluginId))
    status = "Saving…"
    confirmDiscard = false
  }

  function requestClose() {
    if (dirty && !confirmDiscard) {
      confirmDiscard = true
      status = "Unsaved changes. Ctrl+S to save, Esc again to discard."
      return
    }
    closeRequested()
  }

  // ------------------------------------------------------------- the model

  function syncNodes() { stage.nodes = designer.nodes.slice() }

  function touch() { dirty = true }

  function indexOfId(id) {
    for (var i = 0; i < designer.nodes.length; i++) if (designer.nodes[i].nodeId === id) return i
    return -1
  }

  function nodeById(id) {
    var i = indexOfId(id)
    return i === -1 ? null : designer.nodes[i]
  }

  // Undo is a stack of whole layouts — small enough to copy, and it cannot
  // drift out of step with the document the way a list of edits can.
  function pushUndo(tag) {
    if (tag !== undefined && tag !== null && tag === undoTag) return
    undoTag = tag === undefined ? "" : tag
    undoStack = undoStack.concat([JSON.stringify(currentDoc())])
    if (undoStack.length > 60) undoStack = undoStack.slice(undoStack.length - 60)
    redoStack = []
  }

  function undo() {
    if (undoStack.length === 0) return
    redoStack = redoStack.concat([JSON.stringify(currentDoc())])
    applyDoc(JSON.parse(undoStack[undoStack.length - 1]))
    undoStack = undoStack.slice(0, undoStack.length - 1)
    undoTag = ""
    dirty = true
  }

  function redo() {
    if (redoStack.length === 0) return
    undoStack = undoStack.concat([JSON.stringify(currentDoc())])
    applyDoc(JSON.parse(redoStack[redoStack.length - 1]))
    redoStack = redoStack.slice(0, redoStack.length - 1)
    undoTag = ""
    dirty = true
  }

  function select(ids) {
    selection = ids
    undoTag = ""
  }

  function nodePressed(id, additive) {
    if (additive) {
      var next = selection.slice()
      var at = next.indexOf(id)
      if (at === -1) next.push(id)
      else next.splice(at, 1)
      select(next)
    } else if (selection.indexOf(id) === -1) {
      select([id])
    }
  }

  // Put a node's top-left corner at x/y by adjusting its offset from
  // whatever it is anchored to.
  function placeAt(index, x, y) {
    var n = designer.nodes[index]
    var r = stage.rectOf(index)
    n.dx = Math.round(D.dxFor(n.anchor, x, r.w, screenWidth))
    n.dy = Math.round(D.dyFor(n.anchor, y, r.h, screenHeight))
  }

  // Edges and centers worth lining up with: the screen's own, and every
  // other node's. Whatever the drag lands within 8px of wins, and the
  // matching line is drawn.
  function snapDrag(index, x, y, w, h) {
    var threshold = 8
    var xs = [{ v: screenWidth / 2, mid: true }, { v: 0 }, { v: screenWidth }]
    var ys = [{ v: screenHeight / 2, mid: true }, { v: 0 }, { v: screenHeight }]
    for (var i = 0; i < designer.nodes.length; i++) {
      if (i === index || D.isFill(designer.nodes[i])) continue
      var r = stage.rectOf(i)
      xs.push({ v: r.x }, { v: r.x + r.w }, { v: r.x + r.w / 2, mid: true })
      ys.push({ v: r.y }, { v: r.y + r.h }, { v: r.y + r.h / 2, mid: true })
    }

    var hits = []
    function best(candidates, pos, size) {
      var bestDelta = null
      var bestLine = null
      var edges = [{ at: pos, mid: false }, { at: pos + size, mid: false }, { at: pos + size / 2, mid: true }]
      for (var c = 0; c < candidates.length; c++) {
        for (var e = 0; e < edges.length; e++) {
          // Centers meet centers and edges meet edges; crossing the two makes
          // everything cling to everything and nothing line up.
          if (!!candidates[c].mid !== edges[e].mid) continue
          var delta = candidates[c].v - edges[e].at
          if (Math.abs(delta) > threshold) continue
          if (bestDelta === null || Math.abs(delta) < Math.abs(bestDelta)) {
            bestDelta = delta
            bestLine = candidates[c].v
          }
        }
      }
      if (bestDelta === null) return { pos: pos, line: null }
      return { pos: pos + bestDelta, line: bestLine }
    }

    var hx = best(xs, x, w)
    var hy = best(ys, y, h)
    if (hx.line !== null) hits.push({ vertical: true, at: hx.line })
    if (hy.line !== null) hits.push({ vertical: false, at: hy.line })
    guides = hits
    return { x: hx.pos, y: hy.pos }
  }

  function nodeDragged(id, x, y) {
    var index = indexOfId(id)
    if (index === -1) return
    var r = stage.rectOf(index)
    var snapped = snapDrag(index, x, y, r.w, r.h)
    var ddx = Math.round(snapped.x - r.x)
    var ddy = Math.round(snapped.y - r.y)
    if (ddx === 0 && ddy === 0) return
    pushUndo("drag")
    // Dragging one of several selected pieces moves the whole selection.
    var ids = (selection.indexOf(id) !== -1 && selection.length > 1) ? selection : [id]
    var rects = []
    var indexes = []
    for (var i = 0; i < ids.length; i++) {
      var at = indexOfId(ids[i])
      if (at === -1 || D.isFill(designer.nodes[at])) continue
      indexes.push(at)
      rects.push(stage.rectOf(at))
    }
    for (var j = 0; j < indexes.length; j++)
      placeAt(indexes[j], rects[j].x + ddx, rects[j].y + ddy)
    touch()
  }

  function nodeResized(id, w, h) {
    var index = indexOfId(id)
    if (index === -1) return
    var n = designer.nodes[index]
    var r = stage.rectOf(index)
    pushUndo("resize")
    n.w = w
    n.h = h
    // Growing from the corner leaves the top-left where it was, whichever
    // edge the piece is anchored to.
    n.dx = Math.round(D.dxFor(n.anchor, r.x, w, screenWidth))
    n.dy = Math.round(D.dyFor(n.anchor, r.y, h, screenHeight))
    touch()
  }

  function dragEnded() {
    guides = []
    undoTag = ""
  }

  // --------------------------------------------------------------- editing

  function addNode(kindId, x, y) {
    var plain = D.newNode(kindId, newNodeId())
    if (!plain) return
    pushUndo()
    var fill = D.isFill(plain)
    if (!fill) plain.anchor = D.anchorAt(x, y, screenWidth, screenHeight)
    var n = makeNode(plain)
    // Backgrounds go underneath everything, which is the only place they
    // make sense.
    designer.nodes = fill ? [n].concat(designer.nodes) : designer.nodes.concat([n])
    syncNodes()
    select([n.nodeId])
    dirty = true
    if (!fill) {
      // The size is only known once it has drawn, so centre it on the drop
      // after the fact.
      var id = n.nodeId
      Qt.callLater(function() {
        var at = designer.indexOfId(id)
        if (at === -1) return
        var r = stage.rectOf(at)
        designer.placeAt(at, x - r.w / 2, y - r.h / 2)
        designer.touch()
      })
    }
    status = D.kindName(kindId) + " added"
  }

  function addComponent(comp, x, y) {
    if (!comp) return
    pushUndo()
    var plain = D.instantiate(D.idsOf(designer.nodes), comp,
                              Math.round(x - (comp.w || 0) / 2), Math.round(y - (comp.h || 0) / 2),
                              screenWidth, screenHeight)
    var made = []
    var ids = []
    for (var i = 0; i < plain.length; i++) {
      made.push(makeNode(plain[i]))
      ids.push(plain[i].id)
    }
    designer.nodes = designer.nodes.concat(made)
    syncNodes()
    select(ids)
    dirty = true
    status = comp.name + " added"
  }

  function removeSelected() {
    if (selection.length === 0) return
    pushUndo()
    var keep = []
    var gone = []
    for (var i = 0; i < designer.nodes.length; i++) {
      if (selection.indexOf(designer.nodes[i].nodeId) === -1) keep.push(designer.nodes[i])
      else gone.push(designer.nodes[i])
    }
    designer.nodes = keep
    syncNodes()
    select([])
    for (var j = 0; j < gone.length; j++) gone[j].destroy()
    dirty = true
  }

  function duplicateSelected() {
    if (selection.length === 0) return
    pushUndo()
    var made = []
    var ids = []
    var taken = D.idsOf(designer.nodes)
    for (var i = 0; i < selection.length; i++) {
      var src = nodeById(selection[i])
      if (!src) continue
      var copy = D.plainNode(src)
      copy.id = D.nextIdFrom(taken)
      taken.push(copy.id)
      copy.dx += 24
      copy.dy += 24
      made.push(makeNode(copy))
      ids.push(copy.id)
    }
    designer.nodes = designer.nodes.concat(made)
    syncNodes()
    select(ids)
    dirty = true
  }

  function nudge(ddx, ddy) {
    if (selection.length === 0) return
    pushUndo("nudge")
    for (var i = 0; i < selection.length; i++) {
      var n = nodeById(selection[i])
      if (!n || D.isFill(n)) continue
      n.dx += ddx
      n.dy += ddy
    }
    touch()
  }

  // Reorder: 1 up one place, -1 down one, 2 to the front, -2 to the back.
  function restack(how) {
    if (selection.length === 0) return
    pushUndo()
    var picked = []
    var rest = []
    for (var i = 0; i < designer.nodes.length; i++)
      (selection.indexOf(designer.nodes[i].nodeId) === -1 ? rest : picked).push(designer.nodes[i])
    if (how === 2) designer.nodes = rest.concat(picked)
    else if (how === -2) designer.nodes = picked.concat(rest)
    else {
      var order = designer.nodes.slice()
      var indexes = []
      for (var j = 0; j < order.length; j++)
        if (selection.indexOf(order[j].nodeId) !== -1) indexes.push(j)
      if (how > 0) indexes.reverse()
      for (var k = 0; k < indexes.length; k++) {
        var from = indexes[k]
        var to = from + (how > 0 ? 1 : -1)
        if (to < 0 || to >= order.length) continue
        if (selection.indexOf(order[to].nodeId) !== -1) continue
        var tmp = order[to]
        order[to] = order[from]
        order[from] = tmp
      }
      designer.nodes = order
    }
    syncNodes()
    dirty = true
  }

  function setProp(key, value) {
    if (selection.length === 0) return
    pushUndo("prop:" + key)
    for (var i = 0; i < selection.length; i++) {
      var n = nodeById(selection[i])
      if (!n) continue
      var kind = D.kind(n.kind)
      if (!kind) continue
      var known = false
      for (var f = 0; f < kind.fields.length; f++) if (kind.fields[f].key === key) known = true
      if (!known) continue
      // A fresh object, so the item's bindings see a new value.
      var spec = {}
      for (var k in n.spec) spec[k] = n.spec[k]
      spec[key] = value
      n.spec = spec
    }
    touch()
  }

  function setGeometry(key, value) {
    if (selection.length === 0) return
    pushUndo("geom:" + key)
    for (var i = 0; i < selection.length; i++) {
      var n = nodeById(selection[i])
      if (!n) continue
      n[key] = Math.round(value)
    }
    touch()
  }

  function setAnchor(anchor) {
    if (selection.length === 0) return
    pushUndo()
    for (var i = 0; i < selection.length; i++) {
      var index = indexOfId(selection[i])
      if (index === -1) continue
      var r = stage.rectOf(index)
      D.reanchor(designer.nodes[index], anchor, r.w, r.h, screenWidth, screenHeight)
    }
    touch()
  }

  // ------------------------------------------------------------ components

  function saveSelectionAsComponent(name) {
    if (selection.length === 0 || !service) return
    var nodes = []
    var rects = []
    for (var i = 0; i < designer.nodes.length; i++) {
      if (selection.indexOf(designer.nodes[i].nodeId) === -1) continue
      // A full-screen background is not a piece you can place, so it never
      // travels inside a component.
      if (D.isFill(designer.nodes[i])) continue
      nodes.push(designer.nodes[i])
      rects.push(stage.rectOf(i))
    }
    if (nodes.length === 0) {
      status = "Backgrounds cannot be saved as a component"
      return
    }
    var comp = D.makeComponent(name, nodes, rects)
    service.saveComponent(D.componentSlug(name), JSON.stringify(comp))
    namingComponent = false
    status = "Saved “" + comp.name + "” to your components"
  }

  function deleteComponent(slug) {
    if (service) service.deleteComponent(slug)
  }

  // ---------------------------------------------------------------- canvas

  readonly property real canvasScale: Math.min(canvasFrame.width / screenWidth, canvasFrame.height / screenHeight)

  function canvasToStage(px, py) {
    return { x: (px - stageWrap.x) / canvasScale, y: (py - stageWrap.y) / canvasScale }
  }

  function focusCanvas() { keys.forceActiveFocus() }

  // Where a piece ended up on screen, in the screen's own coordinates.
  function stageRect(index) { return stage.rectOf(index) }

  function fileFieldPicked(picked) {
    if (pendingFileKey.length === 0 || String(picked || "").length === 0) return
    setProp(pendingFileKey, String(picked))
    pendingFileKey = ""
  }

  // ------------------------------------------------------------------- keys

  Item {
    id: keys
    anchors.fill: parent
    focus: true
    Keys.onPressed: function(event) {
      var stepSize = (event.modifiers & Qt.ShiftModifier) ? 10 : 1
      if (event.key === Qt.Key_Escape) {
        designer.requestClose(); event.accepted = true
      } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_S) {
        designer.save(); event.accepted = true
      } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_Z) {
        if (event.modifiers & Qt.ShiftModifier) designer.redo(); else designer.undo()
        event.accepted = true
      } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_Y) {
        designer.redo(); event.accepted = true
      } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_D) {
        designer.duplicateSelected(); event.accepted = true
      } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_A) {
        var all = []
        for (var i = 0; i < designer.nodes.length; i++) all.push(designer.nodes[i].nodeId)
        designer.select(all); event.accepted = true
      } else if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) {
        designer.removeSelected(); event.accepted = true
      } else if (event.key === Qt.Key_Left) {
        designer.nudge(-stepSize, 0); event.accepted = true
      } else if (event.key === Qt.Key_Right) {
        designer.nudge(stepSize, 0); event.accepted = true
      } else if (event.key === Qt.Key_Up) {
        designer.nudge(0, -stepSize); event.accepted = true
      } else if (event.key === Qt.Key_Down) {
        designer.nudge(0, stepSize); event.accepted = true
      } else if (event.key === Qt.Key_BracketRight) {
        designer.restack(event.modifiers & Qt.ShiftModifier ? 2 : 1); event.accepted = true
      } else if (event.key === Qt.Key_BracketLeft) {
        designer.restack(event.modifiers & Qt.ShiftModifier ? -2 : -1); event.accepted = true
      }
    }
  }

  // ---------------------------------------------------------------- layout

  readonly property int panelW: Style.space(210)
  readonly property int inspectorW: Style.space(270)

  Item {
    id: toolbar
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: Style.space(40)

    Column {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      spacing: 1
      Text {
        text: designer.docName
        textFormat: Text.PlainText
        color: designer.foreground
        font.family: designer.fontFamily
        font.pixelSize: Style.font.title
        font.weight: Font.DemiBold
      }
      Text {
        text: designer.nodes.length + (designer.nodes.length === 1 ? " piece" : " pieces")
          + (designer.dirty ? "  ·  unsaved" : "")
        textFormat: Text.PlainText
        color: designer.dirty ? designer.accent : designer.muted
        font.family: designer.fontFamily
        font.pixelSize: Style.font.caption
      }
    }

    Row {
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(6)

      DesignerButton {
        label: "Undo"
        active: designer.undoStack.length > 0
        foreground: designer.foreground
        accent: designer.accent
        onClicked: designer.undo()
      }
      DesignerButton {
        label: "Redo"
        active: designer.redoStack.length > 0
        foreground: designer.foreground
        accent: designer.accent
        onClicked: designer.redo()
      }
      DesignerButton {
        label: "Edit code"
        foreground: designer.foreground
        accent: designer.accent
        onClicked: designer.openCodeRequested(designer.path)
      }
      DesignerButton {
        label: "Use this design"
        foreground: designer.foreground
        accent: designer.accent
        onClicked: designer.useRequested()
      }
      DesignerButton {
        label: "Save  Ctrl+S"
        primary: designer.dirty
        foreground: designer.foreground
        accent: designer.accent
        onClicked: designer.save()
      }
      DesignerButton {
        label: "Back  Esc"
        foreground: designer.foreground
        accent: designer.accent
        onClicked: designer.requestClose()
      }
    }
  }

  Text {
    id: errorBanner
    anchors.top: toolbar.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    visible: designer.loadError.length > 0
    height: visible ? implicitHeight + Style.space(8) : 0
    verticalAlignment: Text.AlignVCenter
    text: designer.loadError
    textFormat: Text.PlainText
    color: Color.lock.textError
    font.family: designer.fontFamily
    font.pixelSize: Style.font.bodySmall
    wrapMode: Text.Wrap
  }

  // ------------------------------------------------------------- palette

  Rectangle {
    id: palette
    anchors.top: errorBanner.bottom
    anchors.topMargin: Style.space(8)
    anchors.bottom: footer.top
    anchors.bottomMargin: Style.space(8)
    anchors.left: parent.left
    width: designer.panelW
    radius: 6
    color: designer.well
    border.width: 1
    border.color: designer.line
    clip: true

    Flickable {
      anchors.fill: parent
      anchors.margins: Style.space(10)
      contentWidth: width
      contentHeight: paletteColumn.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds

      Column {
        id: paletteColumn
        width: parent.width
        spacing: Style.space(6)

        Text {
          text: "YOUR COMPONENTS"
          color: designer.muted
          font.family: designer.fontFamily
          font.pixelSize: Style.font.caption
          font.letterSpacing: 1
        }

        Text {
          width: parent.width
          visible: designer.componentList.length === 0
          text: "Select a piece (or several with Ctrl) and press “Save as component” to keep it here for every design."
          textFormat: Text.PlainText
          color: Qt.rgba(designer.foreground.r, designer.foreground.g, designer.foreground.b, 0.35)
          font.family: designer.fontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.Wrap
        }

        Repeater {
          model: designer.componentList

          Rectangle {
            id: componentEntry
            required property var modelData
            width: paletteColumn.width
            height: Style.space(54)
            radius: 5
            color: Qt.rgba(designer.foreground.r, designer.foreground.g, designer.foreground.b,
                           componentArea.containsMouse ? 0.14 : 0.06)
            border.width: 1
            border.color: designer.line
            Behavior on color { ColorAnimation { duration: 100 } }

            DesignerThumb {
              anchors.left: parent.left
              anchors.leftMargin: Style.space(6)
              anchors.verticalCenter: parent.verticalCenter
              width: Style.space(56)
              height: Style.space(40)
              lock: stage
              comp: componentEntry.modelData.comp
            }

            Text {
              anchors.left: parent.left
              anchors.leftMargin: Style.space(68)
              anchors.right: parent.right
              anchors.rightMargin: Style.space(22)
              anchors.verticalCenter: parent.verticalCenter
              text: componentEntry.modelData.comp ? componentEntry.modelData.comp.name : componentEntry.modelData.slug
              textFormat: Text.PlainText
              color: designer.foreground
              font.family: designer.fontFamily
              font.pixelSize: Style.font.bodySmall
              elide: Text.ElideRight
            }

            Text {
              anchors.right: parent.right
              anchors.rightMargin: Style.space(7)
              anchors.top: parent.top
              anchors.topMargin: Style.space(5)
              visible: componentArea.containsMouse || removeArea.containsMouse
              text: "✕"
              color: removeArea.containsMouse ? Color.lock.textError : designer.muted
              font.family: designer.fontFamily
              font.pixelSize: Style.font.caption
              MouseArea {
                id: removeArea
                anchors.fill: parent
                anchors.margins: -Style.space(5)
                hoverEnabled: true
                onClicked: designer.deleteComponent(componentEntry.modelData.slug)
              }
            }

            Item {
              id: componentGhost
              parent: dragLayer
              visible: componentArea.dragging
              width: Style.space(120)
              height: Style.space(30)
              Drag.active: componentArea.dragging
              Drag.hotSpot.x: width / 2
              Drag.hotSpot.y: height / 2
              Drag.keys: ["lock-designer-drop"]
              property string payloadKind: ""
              property var payloadComponent: componentEntry.modelData.comp

              Rectangle {
                anchors.fill: parent
                radius: 5
                color: Qt.rgba(designer.accent.r, designer.accent.g, designer.accent.b, 0.85)
                Text {
                  anchors.centerIn: parent
                  text: componentEntry.modelData.comp ? componentEntry.modelData.comp.name : ""
                  textFormat: Text.PlainText
                  color: Color.background
                  font.family: designer.fontFamily
                  font.pixelSize: Style.font.caption
                  font.weight: Font.DemiBold
                }
              }
            }

            MouseArea {
              id: componentArea
              anchors.fill: parent
              anchors.rightMargin: Style.space(20)
              hoverEnabled: true
              // Same as the built-in pieces: the ghost is carried by hand.
              property bool dragging: false
              property real pressX: 0
              property real pressY: 0

              function carry(mouse) {
                var p = mapToItem(dragLayer, mouse.x, mouse.y)
                componentGhost.x = p.x - componentGhost.width / 2
                componentGhost.y = p.y - componentGhost.height / 2
              }

              onPressed: function(mouse) {
                pressX = mouse.x
                pressY = mouse.y
                dragging = false
                carry(mouse)
              }
              onPositionChanged: function(mouse) {
                if (!pressed) return
                if (!dragging && Math.abs(mouse.x - pressX) < 6 && Math.abs(mouse.y - pressY) < 6) return
                dragging = true
                carry(mouse)
              }
              onReleased: {
                if (dragging) {
                  componentGhost.Drag.drop()
                  dragging = false
                } else {
                  designer.addComponent(componentEntry.modelData.comp, designer.screenWidth / 2, designer.screenHeight / 2)
                }
              }
              onCanceled: dragging = false
            }
          }
        }

        Repeater {
          model: D.GROUPS

          Column {
            id: group
            required property string modelData
            readonly property var entries: D.paletteFor(modelData)
            width: paletteColumn.width
            spacing: Style.space(4)
            topPadding: Style.space(6)

            Text {
              text: group.modelData.toUpperCase()
              color: designer.muted
              font.family: designer.fontFamily
              font.pixelSize: Style.font.caption
              font.letterSpacing: 1
            }

            Repeater {
              model: group.entries

              Rectangle {
                id: entry
                required property var modelData
                width: group.width
                height: Style.space(32)
                radius: 5
                color: Qt.rgba(designer.foreground.r, designer.foreground.g, designer.foreground.b,
                               entryArea.containsMouse ? 0.14 : 0.06)
                border.width: 1
                border.color: designer.line
                Behavior on color { ColorAnimation { duration: 100 } }

                Text {
                  anchors.left: parent.left
                  anchors.leftMargin: Style.space(9)
                  anchors.verticalCenter: parent.verticalCenter
                  text: entry.modelData.kind.glyph
                  color: designer.accent
                  font.family: designer.fontFamily
                  font.pixelSize: Style.font.title
                }

                Text {
                  anchors.left: parent.left
                  anchors.leftMargin: Style.space(32)
                  anchors.right: parent.right
                  anchors.rightMargin: Style.space(6)
                  anchors.verticalCenter: parent.verticalCenter
                  text: entry.modelData.kind.name
                  textFormat: Text.PlainText
                  color: designer.foreground
                  font.family: designer.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  elide: Text.ElideRight
                }

                Item {
                  id: entryGhost
                  parent: dragLayer
                  visible: entryArea.dragging
                  width: Style.space(120)
                  height: Style.space(30)
                  Drag.active: entryArea.dragging
                  Drag.hotSpot.x: width / 2
                  Drag.hotSpot.y: height / 2
                  Drag.keys: ["lock-designer-drop"]
                  property string payloadKind: entry.modelData.id
                  property var payloadComponent: null

                  Rectangle {
                    anchors.fill: parent
                    radius: 5
                    color: Qt.rgba(designer.accent.r, designer.accent.g, designer.accent.b, 0.85)
                    Text {
                      anchors.centerIn: parent
                      text: entry.modelData.kind.name
                      textFormat: Text.PlainText
                      color: Color.background
                      font.family: designer.fontFamily
                      font.pixelSize: Style.font.caption
                      font.weight: Font.DemiBold
                    }
                  }
                }

                MouseArea {
                  id: entryArea
                  anchors.fill: parent
                  hoverEnabled: true
                  // The ghost is carried by hand rather than with drag.target:
                  // it lives in the drag layer, outside this Flickable, and
                  // MouseArea's own dragging maps the delta between the two
                  // coordinate systems wrongly — the ghost ends up hundreds of
                  // pixels away and drops onto nothing.
                  property bool dragging: false
                  property real pressX: 0
                  property real pressY: 0

                  function carry(mouse) {
                    var p = mapToItem(dragLayer, mouse.x, mouse.y)
                    entryGhost.x = p.x - entryGhost.width / 2
                    entryGhost.y = p.y - entryGhost.height / 2
                  }

                  onPressed: function(mouse) {
                    pressX = mouse.x
                    pressY = mouse.y
                    dragging = false
                    carry(mouse)
                  }
                  onPositionChanged: function(mouse) {
                    if (!pressed) return
                    if (!dragging && Math.abs(mouse.x - pressX) < 6 && Math.abs(mouse.y - pressY) < 6) return
                    dragging = true
                    carry(mouse)
                  }
                  onReleased: {
                    if (dragging) {
                      entryGhost.Drag.drop()
                      dragging = false
                    } else {
                      designer.addNode(entry.modelData.id, designer.screenWidth / 2, designer.screenHeight / 2)
                    }
                  }
                  onCanceled: dragging = false
                  // What it is, said in the footer where there is room for it.
                  onEntered: designer.hoverHint = entry.modelData.kind.hint
                  onExited: if (designer.hoverHint === entry.modelData.kind.hint) designer.hoverHint = ""
                }
              }
            }
          }
        }
      }
    }
  }

  // ---------------------------------------------------------------- canvas

  Item {
    id: canvasFrame
    anchors.top: errorBanner.bottom
    anchors.topMargin: Style.space(8)
    anchors.bottom: footer.top
    anchors.bottomMargin: Style.space(8)
    anchors.left: palette.right
    anchors.leftMargin: Style.space(10)
    anchors.right: inspector.left
    anchors.rightMargin: Style.space(10)
    clip: true

    // Clicking past everything clears the selection. It sits under the stage,
    // and reaches this far because the pieces that cover the screen — the
    // backgrounds — deliberately take no clicks.
    MouseArea {
      anchors.fill: parent
      onClicked: {
        designer.select([])
        designer.focusCanvas()
      }
    }

    Rectangle {
      x: stageWrap.x
      y: stageWrap.y
      width: designer.screenWidth * designer.canvasScale
      height: designer.screenHeight * designer.canvasScale
      color: "transparent"
      border.width: 1
      border.color: designer.line
      z: 5
    }

    Item {
      id: stageWrap
      width: designer.screenWidth
      height: designer.screenHeight
      scale: designer.canvasScale
      transformOrigin: Item.TopLeft
      x: Math.round((canvasFrame.width - width * scale) / 2)
      y: Math.round((canvasFrame.height - height * scale) / 2)

      DesignerStage {
        id: stage
        anchors.fill: parent
        editing: true
        selection: designer.selection
        viewScale: designer.canvasScale
        backgroundPath: designer.service ? designer.service.backgroundPath : ""
        backgroundVersion: designer.service ? designer.service.backgroundVersion : 0
        avatarPath: designer.service ? designer.service.avatarPath : ""
        avatarVersion: designer.service ? designer.service.avatarVersion : 0
        videoPath: designer.service ? designer.service.videoPath : ""
        fingerprintConfigured: designer.service ? designer.service.fingerprintConfigured : false
        twelveHour: designer.service && designer.service.twelveHour !== undefined ? designer.service.twelveHour : false
        // Something in the box, so the input pieces are visible while arranging.
        passwordText: "omarchy"
        onNodePressed: function(id, additive) {
          designer.nodePressed(id, additive)
          designer.focusCanvas()
        }
        onNodeDragged: function(id, x, y) { designer.nodeDragged(id, x, y) }
        onNodeResized: function(id, w, h) { designer.nodeResized(id, w, h) }
        onNodeDragEnded: designer.dragEnded()
      }

      // Alignment guides, drawn in the screen's own coordinates so they land
      // exactly on the edge they matched.
      Repeater {
        model: designer.guides
        Rectangle {
          required property var modelData
          color: designer.accent
          opacity: 0.8
          width: modelData.vertical ? 1 / designer.canvasScale : stageWrap.width
          height: modelData.vertical ? stageWrap.height : 1 / designer.canvasScale
          x: modelData.vertical ? modelData.at : 0
          y: modelData.vertical ? 0 : modelData.at
        }
      }
    }

    DropArea {
      anchors.fill: parent
      keys: ["lock-designer-drop"]
      onDropped: function(drop) {
        var at = designer.canvasToStage(drop.x, drop.y)
        if (drop.source && drop.source.payloadComponent)
          designer.addComponent(drop.source.payloadComponent, at.x, at.y)
        else if (drop.source && String(drop.source.payloadKind).length > 0)
          designer.addNode(String(drop.source.payloadKind), at.x, at.y)
        designer.focusCanvas()
      }
    }
  }

  // ------------------------------------------------------------- inspector

  Rectangle {
    id: inspector
    anchors.top: errorBanner.bottom
    anchors.topMargin: Style.space(8)
    anchors.bottom: footer.top
    anchors.bottomMargin: Style.space(8)
    anchors.right: parent.right
    width: designer.inspectorW
    radius: 6
    color: designer.well
    border.width: 1
    border.color: designer.line
    clip: true

    Flickable {
      anchors.fill: parent
      anchors.margins: Style.space(10)
      contentWidth: width
      contentHeight: inspectorColumn.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds

      Column {
        id: inspectorColumn
        width: parent.width
        spacing: Style.space(10)

        DesignerField {
          width: parent.width
          label: "DESIGN NAME"
          type: "text"
          value: designer.docName
          foreground: designer.foreground
          accent: designer.accent
          onEdited: function(next) {
            designer.pushUndo("name")
            designer.docName = String(next)
            designer.touch()
          }
          onEscaped: designer.focusCanvas()
        }

        Rectangle { width: parent.width; height: 1; color: designer.line }

        Text {
          width: parent.width
          text: designer.selection.length === 0 ? "NOTHING SELECTED"
            : (designer.selection.length > 1 ? designer.selection.length + " PIECES SELECTED"
               : (designer.primaryKind ? designer.primaryKind.name.toUpperCase() : ""))
          textFormat: Text.PlainText
          color: designer.selection.length === 0 ? designer.muted : designer.accent
          font.family: designer.fontFamily
          font.pixelSize: Style.font.caption
          font.letterSpacing: 1
          font.weight: Font.DemiBold
        }

        Text {
          width: parent.width
          visible: designer.selection.length === 0
          text: "Drag a piece onto the screen, or click one there to change it."
          textFormat: Text.PlainText
          color: Qt.rgba(designer.foreground.r, designer.foreground.g, designer.foreground.b, 0.35)
          font.family: designer.fontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.Wrap
        }

        // ------------------------------------------------------- placement

        Column {
          width: parent.width
          spacing: Style.space(6)
          visible: designer.primary !== null && !D.isFill(designer.primary)

          Text {
            text: "STICKS TO"
            color: designer.muted
            font.family: designer.fontFamily
            font.pixelSize: Style.font.caption
            font.letterSpacing: 1
          }

          Row {
            spacing: Style.space(10)

            // A design has to survive a different screen, so a piece is not
            // parked at an absolute spot: it holds on to a corner, an edge or
            // the middle, and keeps its distance from that.
            Grid {
              columns: 3
              spacing: Style.space(3)
              Repeater {
                model: D.ANCHORS
                Rectangle {
                  required property string modelData
                  readonly property bool current: designer.primary && designer.primary.anchor === modelData
                  width: Style.space(20)
                  height: Style.space(20)
                  radius: 3
                  color: current ? designer.accent
                    : Qt.rgba(designer.foreground.r, designer.foreground.g, designer.foreground.b,
                              anchorArea.containsMouse ? 0.18 : 0.08)
                  border.width: 1
                  border.color: current ? designer.accent : designer.line
                  Rectangle {
                    anchors.centerIn: parent
                    width: Style.space(5)
                    height: width
                    radius: 1
                    color: parent.current ? Color.background : designer.muted
                  }
                  MouseArea {
                    id: anchorArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: designer.setAnchor(parent.modelData)
                  }
                }
              }
            }

            Column {
              spacing: Style.space(4)
              width: inspectorColumn.width - Style.space(84)
              DesignerField {
                width: parent.width
                label: "OFFSET X"
                type: "number"
                minimum: -10000
                maximum: 10000
                step: 1
                value: designer.primary ? designer.primary.dx : 0
                foreground: designer.foreground
                accent: designer.accent
                onEdited: function(next) { designer.setGeometry("dx", next) }
                onEscaped: designer.focusCanvas()
              }
              DesignerField {
                width: parent.width
                label: "OFFSET Y"
                type: "number"
                minimum: -10000
                maximum: 10000
                step: 1
                value: designer.primary ? designer.primary.dy : 0
                foreground: designer.foreground
                accent: designer.accent
                onEdited: function(next) { designer.setGeometry("dy", next) }
                onEscaped: designer.focusCanvas()
              }
            }
          }

          Row {
            spacing: Style.space(8)
            visible: designer.primary !== null && D.isSized(designer.primary)
            DesignerField {
              width: (inspectorColumn.width - Style.space(8)) / 2
              label: "WIDTH"
              type: "number"
              minimum: 0
              maximum: 10000
              step: 1
              value: designer.primary ? designer.primary.w : 0
              foreground: designer.foreground
              accent: designer.accent
              onEdited: function(next) { designer.setGeometry("w", next) }
              onEscaped: designer.focusCanvas()
            }
            DesignerField {
              width: (inspectorColumn.width - Style.space(8)) / 2
              label: "HEIGHT"
              type: "number"
              minimum: 0
              maximum: 10000
              step: 1
              visible: designer.primary ? !D.isSquare(designer.primary) : false
              value: designer.primary ? designer.primary.h : 0
              foreground: designer.foreground
              accent: designer.accent
              onEdited: function(next) { designer.setGeometry("h", next) }
              onEscaped: designer.focusCanvas()
            }
          }

          Text {
            width: parent.width
            visible: designer.primary !== null && !D.isSized(designer.primary)
            text: "Set a width to make it wrap; leave it at 0 and it hugs its text."
            textFormat: Text.PlainText
            color: Qt.rgba(designer.foreground.r, designer.foreground.g, designer.foreground.b, 0.35)
            font.family: designer.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.Wrap
          }

          DesignerField {
            width: parent.width
            visible: designer.primary !== null && !D.isSized(designer.primary)
            label: "WIDTH (0 = FIT TEXT)"
            type: "number"
            minimum: 0
            maximum: 10000
            step: 10
            value: designer.primary ? designer.primary.w : 0
            foreground: designer.foreground
            accent: designer.accent
            onEdited: function(next) { designer.setGeometry("w", next) }
            onEscaped: designer.focusCanvas()
          }
        }

        Rectangle {
          width: parent.width
          height: 1
          color: designer.line
          visible: designer.primary !== null
        }

        // ---------------------------------------------------------- fields

        Repeater {
          model: designer.primaryKind ? designer.primaryKind.fields : []

          DesignerField {
            required property var modelData
            width: inspectorColumn.width
            label: modelData.label.toUpperCase()
            type: modelData.type
            options: modelData.options ? modelData.options : []
            minimum: modelData.min !== undefined ? modelData.min : 0
            maximum: modelData.max !== undefined ? modelData.max : 1
            step: modelData.step !== undefined ? modelData.step : 0.05
            value: {
              if (!designer.primary) return null
              var v = designer.primary.spec[modelData.key]
              return v === undefined ? null : v
            }
            foreground: designer.foreground
            accent: designer.accent
            onEdited: function(next) { designer.setProp(modelData.key, next) }
            onEscaped: designer.focusCanvas()
            onPickFileRequested: {
              designer.pendingFileKey = modelData.key
              designer.pickFileRequested()
            }
          }
        }

        // --------------------------------------------------------- actions

        Rectangle {
          width: parent.width
          height: 1
          color: designer.line
          visible: designer.selection.length > 0
        }

        Flow {
          width: parent.width
          spacing: Style.space(5)
          visible: designer.selection.length > 0

          DesignerButton {
            label: "Duplicate"
            foreground: designer.foreground
            accent: designer.accent
            onClicked: designer.duplicateSelected()
          }
          DesignerButton {
            label: "Delete"
            foreground: designer.foreground
            accent: designer.accent
            onClicked: designer.removeSelected()
          }
          DesignerButton {
            label: "Front"
            foreground: designer.foreground
            accent: designer.accent
            onClicked: designer.restack(2)
          }
          DesignerButton {
            label: "Forward"
            foreground: designer.foreground
            accent: designer.accent
            onClicked: designer.restack(1)
          }
          DesignerButton {
            label: "Back"
            foreground: designer.foreground
            accent: designer.accent
            onClicked: designer.restack(-1)
          }
          DesignerButton {
            label: "Bottom"
            foreground: designer.foreground
            accent: designer.accent
            onClicked: designer.restack(-2)
          }
        }

        DesignerButton {
          width: parent.width
          visible: designer.selection.length > 0 && !designer.namingComponent
          label: "Save as component"
          foreground: designer.foreground
          accent: designer.accent
          onClicked: {
            designer.namingComponent = true
            Qt.callLater(function() { componentName.forceFieldFocus() })
          }
        }

        Column {
          id: componentName
          width: parent.width
          spacing: Style.space(5)
          visible: designer.namingComponent

          function forceFieldFocus() { nameEntry.forceActiveFocus() }

          Text {
            text: "NAME IT"
            color: designer.muted
            font.family: designer.fontFamily
            font.pixelSize: Style.font.caption
            font.letterSpacing: 1
          }

          Rectangle {
            width: parent.width
            height: Style.space(28)
            radius: 4
            color: Qt.rgba(designer.foreground.r, designer.foreground.g, designer.foreground.b, 0.07)
            border.width: 1
            border.color: nameEntry.activeFocus ? designer.accent : designer.line
            TextInput {
              id: nameEntry
              anchors.fill: parent
              anchors.leftMargin: Style.space(8)
              anchors.rightMargin: Style.space(8)
              verticalAlignment: TextInput.AlignVCenter
              color: designer.foreground
              selectionColor: designer.accent
              selectByMouse: true
              font.family: designer.fontFamily
              font.pixelSize: Style.font.bodySmall
              onAccepted: if (text.trim().length > 0) designer.saveSelectionAsComponent(text.trim())
              Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) {
                  designer.namingComponent = false
                  designer.focusCanvas()
                  event.accepted = true
                }
              }
            }
          }

          Row {
            spacing: Style.space(5)
            DesignerButton {
              label: "Save"
              primary: true
              foreground: designer.foreground
              accent: designer.accent
              onClicked: if (nameEntry.text.trim().length > 0) designer.saveSelectionAsComponent(nameEntry.text.trim())
            }
            DesignerButton {
              label: "Cancel"
              foreground: designer.foreground
              accent: designer.accent
              onClicked: { designer.namingComponent = false; designer.focusCanvas() }
            }
          }
        }

        // ---------------------------------------------------------- layers

        Rectangle { width: parent.width; height: 1; color: designer.line }

        Text {
          text: "LAYERS  ·  TOP FIRST"
          color: designer.muted
          font.family: designer.fontFamily
          font.pixelSize: Style.font.caption
          font.letterSpacing: 1
        }

        Column {
          width: parent.width
          spacing: 1

          Repeater {
            // Top of the screen first, which is the end of the list.
            model: designer.nodes.slice().reverse()

            Rectangle {
              id: layerRow
              required property var modelData
              readonly property bool current: designer.selection.indexOf(modelData.nodeId) !== -1
              width: inspectorColumn.width
              height: Style.space(24)
              radius: 3
              color: current ? Qt.rgba(designer.accent.r, designer.accent.g, designer.accent.b, 0.25)
                : Qt.rgba(designer.foreground.r, designer.foreground.g, designer.foreground.b,
                          layerArea.containsMouse ? 0.1 : 0.0)

              Text {
                anchors.left: parent.left
                anchors.leftMargin: Style.space(6)
                anchors.verticalCenter: parent.verticalCenter
                text: D.kind(layerRow.modelData.kind).glyph
                color: layerRow.current ? designer.accent : designer.muted
                font.family: designer.fontFamily
                font.pixelSize: Style.font.bodySmall
              }

              Text {
                anchors.left: parent.left
                anchors.leftMargin: Style.space(26)
                anchors.right: parent.right
                anchors.rightMargin: Style.space(6)
                anchors.verticalCenter: parent.verticalCenter
                text: {
                  var name = D.kindName(layerRow.modelData.kind)
                  var body = String(layerRow.modelData.spec.text || "")
                  return body.length > 0 ? name + " · " + body : name
                }
                textFormat: Text.PlainText
                color: layerRow.current ? designer.foreground : designer.muted
                font.family: designer.fontFamily
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
              }

              MouseArea {
                id: layerArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: function(mouse) {
                  designer.nodePressed(layerRow.modelData.nodeId, (mouse.modifiers & Qt.ControlModifier) !== 0)
                  if (!(mouse.modifiers & Qt.ControlModifier)) designer.select([layerRow.modelData.nodeId])
                  designer.focusCanvas()
                }
              }
            }
          }
        }
      }
    }
  }

  // ---------------------------------------------------------------- footer

  Item {
    id: footer
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    height: Style.space(26)

    Text {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width - Style.space(20)
      text: {
        if (designer.hoverHint.length > 0) return designer.hoverHint
        if (designer.status.length > 0) return designer.status
        return "Drag pieces in   ·   arrows nudge (Shift: 10px)   ·   Ctrl+click multi-select   ·   Ctrl+D duplicate   ·   Del remove   ·   [ ] restack   ·   Ctrl+Z undo   ·   Ctrl+S save"
      }
      textFormat: Text.PlainText
      color: designer.status.length > 0 && designer.hoverHint.length === 0 ? designer.foreground : designer.muted
      font.family: designer.fontFamily
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
    }
  }

  // Drag ghosts fly here, above the panels and the canvas alike.
  Item {
    id: dragLayer
    anchors.fill: parent
    z: 100
  }
}
