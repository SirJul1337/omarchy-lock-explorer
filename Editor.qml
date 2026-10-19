import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import "ExplorerStrings.js" as UiText
import "designs"

// Code on the left, live preview on the right. Ctrl+S saves and reloads the
// design everywhere (preview, thumbnails and the lock screen itself).
Item {
  id: editor

  property var service: null
  function tr(text) {
    return UiText.tr(editor.service && editor.service.language !== undefined ? String(editor.service.language) : "en", text)
  }
  property var design: null
  property color background: Commons.Color.menu.background
  property color foreground: Commons.Color.menu.text
  property color accent: Commons.Color.accent
  property string fontFamily: Style.font.menuFamily
  property real screenWidth: 1920
  property real screenHeight: 1080

  readonly property string path: design && design.path ? decodeURIComponent(String(design.path).replace(/^file:\/\//, "")) : ""
  readonly property color muted: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.55)
  property bool dirty: false
  property bool loadingText: false
  property bool confirmDiscard: false
  property string status: ""

  signal closeRequested()
  signal openExternalRequested(string path)

  function focusCode() { code.forceActiveFocus() }

  function load() {
    dirty = false
    confirmDiscard = false
    status = ""
    // After the bindings settle: the reader's path follows editor.path.
    Qt.callLater(reader.reload)
  }

  function save() {
    if (path.length === 0) return
    file.setText(code.text)
    dirty = false
    confirmDiscard = false
    status = editor.tr("Saving…")
  }

  function requestClose() {
    if (dirty && !confirmDiscard) {
      confirmDiscard = true
      status = editor.tr("Unsaved changes. Ctrl+S to save, Esc again to discard.")
      return
    }
    closeRequested()
  }

  onPathChanged: if (path.length > 0) load()

  // Reads go through CappedFile (a plain file, a link to one is fine, at most
  // 1 MiB). The FileView writes, and watches for changes made elsewhere, but
  // never reads the file itself.
  CappedFile {
    id: reader
    path: editor.path
    allowLinks: true
    maxBytes: 1048576
    preload: false
    onLoaded: {
      if (editor.dirty) return
      editor.loadingText = true
      var t = reader.text()
      if (code.text !== t) code.text = t
      editor.loadingText = false
      if (editor.service && typeof editor.service.reloadDesigns === "function") editor.service.reloadDesigns()
    }
  }

  FileView {
    id: file
    path: editor.path
    preload: false
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onSaved: {
      editor.status = editor.tr("Saved %1").arg(Qt.formatTime(new Date(), "HH:mm:ss"))
      if (editor.service && typeof editor.service.reloadDesigns === "function") editor.service.reloadDesigns()
    }
    onSaveFailed: function(error) { editor.status = editor.tr("Save failed: %1").arg(error) }
    onFileChanged: reader.reload()
  }

  Row {
    anchors.fill: parent
    spacing: Style.space(16)

    Rectangle {
      id: codePane
      width: Math.round(parent.width * 0.55)
      height: parent.height
      radius: Math.max(6, Style.cornerRadius)
      color: Qt.darker(editor.background, 1.25)
      border.width: 1
      border.color: Qt.rgba(editor.foreground.r, editor.foreground.g, editor.foreground.b, 0.12)
      clip: true

      Text {
        id: gutter
        x: Style.space(10)
        y: Style.space(10) - flick.contentY
        text: {
          var n = code.lineCount, out = ""
          for (var i = 1; i <= n; i++) out += i + "\n"
          return out
        }
        color: Qt.rgba(editor.foreground.r, editor.foreground.g, editor.foreground.b, 0.3)
        font.family: Style.font.family
        font.pixelSize: code.font.pixelSize
        horizontalAlignment: Text.AlignRight
        width: Style.space(34)
        lineHeight: code.lineHeightValue
        lineHeightMode: Text.FixedHeight
      }
      Rectangle { x: gutter.x + gutter.width + Style.space(8); width: 1; height: parent.height; color: Qt.rgba(editor.foreground.r, editor.foreground.g, editor.foreground.b, 0.1) }

      Flickable {
        id: flick
        anchors.fill: parent
        anchors.leftMargin: gutter.x + gutter.width + Style.space(18)
        anchors.topMargin: Style.space(10)
        anchors.bottomMargin: Style.space(10)
        anchors.rightMargin: Style.space(10)
        contentWidth: Math.max(width, code.contentWidth + Style.space(20))
        contentHeight: Math.max(height, code.contentHeight + Style.space(20))
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        function ensureVisible(r) {
          if (contentX >= r.x) contentX = r.x
          else if (contentX + width <= r.x + r.width) contentX = r.x + r.width - width
          if (contentY >= r.y) contentY = r.y
          else if (contentY + height <= r.y + r.height) contentY = r.y + r.height - height
        }

        TypedEdit {
          id: code
          readonly property real lineHeightValue: contentHeight > 0 && lineCount > 0 ? contentHeight / lineCount : font.pixelSize * 1.3
          width: Math.max(flick.width, contentWidth)
          textFormat: TextEdit.PlainText
          wrapMode: TextEdit.NoWrap
          selectByMouse: true
          persistentSelection: true
          color: editor.foreground
          selectionColor: editor.accent
          selectedTextColor: Commons.Color.background
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          tabStopDistance: font.pixelSize * 1.2
          onCursorRectangleChanged: flick.ensureVisible(cursorRectangle)
          onTextChanged: if (!editor.loadingText) { editor.dirty = true; editor.confirmDiscard = false }

          Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
              editor.requestClose(); event.accepted = true
            } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_S) {
              editor.save(); event.accepted = true
            } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_O) {
              editor.openExternalRequested(editor.path); event.accepted = true
            }
          }
        }
        MouseArea {
          anchors.fill: parent
          acceptedButtons: Qt.NoButton
          onWheel: function(wheel) {
            // Pixels from a touchpad, the angle from a wheel, same as the grid.
            var dy = wheel.pixelDelta.y !== 0 ? wheel.pixelDelta.y : wheel.angleDelta.y
            var next = flick.contentY - dy
            flick.contentY = Math.max(0, Math.min(Math.max(0, flick.contentHeight - flick.height), next))
          }
        }
      }
    }

    Column {
      width: parent.width - codePane.width - parent.spacing
      height: parent.height
      spacing: Style.space(10)

      Rectangle {
        id: previewFrame
        width: parent.width
        height: Math.round(width * editor.screenHeight / editor.screenWidth)
        radius: Math.max(6, Style.cornerRadius)
        color: Commons.Color.background
        border.width: 1
        border.color: Qt.rgba(editor.foreground.r, editor.foreground.g, editor.foreground.b, 0.18)
        clip: true
        Item {
          anchors.fill: parent
          anchors.margins: 1
          clip: true
          Item {
            width: editor.screenWidth
            height: editor.screenHeight
            scale: (previewFrame.width - 2) / editor.screenWidth
            transformOrigin: Item.TopLeft
            LockHost {
              id: preview
              anchors.fill: parent
              designId: editor.design ? editor.design.id : ""
              revision: editor.service ? editor.service.designsRevision : 0
              userDesigns: editor.service && editor.service.userDesigns ? editor.service.userDesigns : []
              backgroundPath: editor.service ? editor.service.backgroundPath : ""
              backgroundVersion: editor.service ? editor.service.backgroundVersion : 0
              wallpaperBlur: editor.service && editor.service.wallpaperBlurValue !== undefined ? editor.service.wallpaperBlurValue : -1
              wallpaperDim: editor.service && editor.service.wallpaperDimShift !== undefined ? editor.service.wallpaperDimShift : 0
              uiScale: editor.service && editor.service.uiScale !== undefined ? editor.service.uiScale : 1
              holdStill: editor.service ? editor.service.motionReduced === true : false
              language: editor.service && editor.service.language !== undefined ? editor.service.language : "en"
              fullName: editor.service && editor.service.accountName !== undefined ? editor.service.accountName : ""
              fingerprintConfigured: editor.service ? editor.service.fingerprintConfigured : false
              inputEnabled: false
              loadBackground: true
              passwordText: "omarchy"
            }
          }
        }
      }

      Rectangle {
        width: parent.width
        height: parent.height - previewFrame.height - parent.spacing
        radius: Math.max(6, Style.cornerRadius)
        color: Qt.darker(editor.background, 1.25)
        border.width: 1
        border.color: Qt.rgba(editor.foreground.r, editor.foreground.g, editor.foreground.b, 0.12)
        clip: true
        Column {
          anchors.fill: parent
          anchors.margins: Style.space(14)
          spacing: Style.space(8)
          Text {
            width: parent.width
            text: editor.path
            textFormat: Text.PlainText
            color: editor.muted
            font.family: editor.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideMiddle
          }
          Text {
            width: parent.width
            text: preview.loadError.length > 0 ? preview.loadError : (editor.status.length > 0 ? editor.status : editor.tr(editor.dirty ? "Unsaved changes" : "Saved. Preview updates on Ctrl+S."))
            textFormat: Text.PlainText
            color: preview.loadError.length > 0 ? Commons.Color.urgent : (editor.dirty ? editor.foreground : editor.muted)
            font.family: editor.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.Wrap
            maximumLineCount: 6
            elide: Text.ElideRight
          }
          Text {
            width: parent.width
            text: editor.tr("Ctrl+S save   Ctrl+O open in your editor   Esc back")
            color: editor.muted
            font.family: editor.fontFamily
            font.pixelSize: Style.font.caption
          }
        }
      }
    }
  }
}
