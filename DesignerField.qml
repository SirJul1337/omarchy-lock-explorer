import QtQuick
import qs.Commons
import "Designer.js" as D

// One row in the designer's inspector. The kind's field list (Designer.js)
// says which type to draw; every one of them reports back through edited().
Item {
  id: field

  property string label: ""
  property string type: "text"
  property var value: null
  property var options: []
  property real minimum: 0
  property real maximum: 1
  property real step: 0.05
  property color foreground: Color.menu.text
  property color accent: Color.accent
  readonly property color muted: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.55)
  readonly property color well: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.07)
  readonly property color line: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.16)

  signal edited(var next)
  signal pickFileRequested()
  signal drawArtRequested()
  // Esc in a field leaves it rather than closing the designer; the canvas
  // takes the keyboard back.
  signal escaped()

  implicitHeight: column.implicitHeight
  height: implicitHeight

  function optionName(id) {
    for (var i = 0; i < options.length; i++)
      if (String(options[i].id) === String(id)) return options[i].name
    return String(id)
  }

  Column {
    id: column
    width: field.width
    spacing: Style.space(4)

    Text {
      text: field.label
      textFormat: Text.PlainText
      color: field.muted
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.caption
      font.letterSpacing: 1
    }

    Loader {
      width: parent.width
      sourceComponent: {
        switch (field.type) {
        case "number": return numberC
        case "slider": return sliderC
        case "choice": return choiceC
        case "color": return colorC
        case "bool": return boolC
        case "file": return fileC
        case "art": return artC
        case "code": return codeC
        }
        return textC
      }
    }
  }

  // ------------------------------------------------------------------ text

  Component {
    id: textC
    Rectangle {
      implicitHeight: Style.space(28)
      radius: 4
      color: field.well
      border.width: 1
      border.color: entry.activeFocus ? field.accent : field.line

      TextInput {
        id: entry
        anchors.fill: parent
        anchors.leftMargin: Style.space(8)
        anchors.rightMargin: Style.space(8)
        verticalAlignment: TextInput.AlignVCenter
        text: String(field.value === null || field.value === undefined ? "" : field.value)
        color: field.foreground
        selectionColor: field.accent
        selectByMouse: true
        clip: true
        font.family: Style.font.menuFamily
        font.pixelSize: Style.font.bodySmall
        onTextEdited: field.edited(text)
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Escape) {
            entry.focus = false
            field.escaped()
            event.accepted = true
          }
        }
      }
    }
  }

  // ---------------------------------------------------------------- number

  Component {
    id: numberC
    Row {
      spacing: Style.space(4)

      Rectangle {
        width: field.width - Style.space(56)
        height: Style.space(28)
        radius: 4
        color: field.well
        border.width: 1
        border.color: numberEntry.activeFocus ? field.accent : field.line

        TextInput {
          id: numberEntry
          anchors.fill: parent
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(8)
          verticalAlignment: TextInput.AlignVCenter
          text: String(Math.round(Number(field.value) || 0))
          color: field.foreground
          selectionColor: field.accent
          selectByMouse: true
          inputMethodHints: Qt.ImhFormattedNumbersOnly
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.bodySmall
          onTextEdited: {
            var n = parseFloat(text)
            if (isFinite(n)) field.edited(Math.max(field.minimum, Math.min(field.maximum, n)))
          }
          Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Escape) {
              numberEntry.focus = false
              field.escaped()
              event.accepted = true
            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
              var d = (event.key === Qt.Key_Up ? 1 : -1) * (event.modifiers & Qt.ShiftModifier ? 10 : 1) * field.step
              field.edited(Math.max(field.minimum, Math.min(field.maximum, (Number(field.value) || 0) + d)))
              event.accepted = true
            }
          }
        }
      }

      Repeater {
        model: ["−", "+"]
        Rectangle {
          required property string modelData
          required property int index
          width: Style.space(24)
          height: Style.space(28)
          radius: 4
          color: stepArea.containsMouse ? Qt.rgba(field.foreground.r, field.foreground.g, field.foreground.b, 0.16) : field.well
          border.width: 1
          border.color: field.line
          Text {
            anchors.centerIn: parent
            text: parent.modelData
            color: field.foreground
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.bodySmall
          }
          MouseArea {
            id: stepArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
              var d = (parent.index === 1 ? 1 : -1) * field.step
              field.edited(Math.max(field.minimum, Math.min(field.maximum, (Number(field.value) || 0) + d)))
            }
          }
        }
      }
    }
  }

  // ---------------------------------------------------------------- slider

  Component {
    id: sliderC
    Item {
      implicitHeight: Style.space(24)
      readonly property real fraction: {
        var span = field.maximum - field.minimum
        if (span <= 0) return 0
        return Math.max(0, Math.min(1, ((Number(field.value) || 0) - field.minimum) / span))
      }

      Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: field.width - Style.space(44)
        height: Style.space(6)
        radius: height / 2
        color: field.well
        border.width: 1
        border.color: field.line

        Rectangle {
          width: Math.round(parent.width * parent.parent.fraction)
          height: parent.height
          radius: parent.radius
          color: field.accent
        }

        Rectangle {
          x: Math.round(parent.width * parent.parent.fraction) - width / 2
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(12)
          height: width
          radius: width / 2
          color: field.accent
          border.width: 1
          border.color: Qt.rgba(0, 0, 0, 0.4)
        }

        MouseArea {
          anchors.fill: parent
          anchors.margins: -Style.space(8)
          function apply(mx) {
            var f = Math.max(0, Math.min(1, (mx - Style.space(8)) / track.width))
            var raw = field.minimum + f * (field.maximum - field.minimum)
            var snapped = field.step > 0 ? Math.round(raw / field.step) * field.step : raw
            field.edited(Math.round(Math.max(field.minimum, Math.min(field.maximum, snapped)) * 1000) / 1000)
          }
          onPressed: function(mouse) { apply(mouse.x) }
          onPositionChanged: function(mouse) { if (pressed) apply(mouse.x) }
        }
      }

      Text {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: (Math.round((Number(field.value) || 0) * 100) / 100).toFixed(2)
        color: field.muted
        font.family: Style.font.menuFamily
        font.pixelSize: Style.font.caption
      }
    }
  }

  // ---------------------------------------------------------------- choice

  Component {
    id: choiceC
    Flow {
      spacing: Style.space(4)
      Repeater {
        model: field.options
        Rectangle {
          required property var modelData
          readonly property bool current: String(modelData.id) === String(field.value)
          width: choiceLabel.implicitWidth + Style.space(14)
          height: Style.space(24)
          radius: 4
          color: current ? field.accent
            : Qt.rgba(field.foreground.r, field.foreground.g, field.foreground.b, choiceArea.containsMouse ? 0.16 : 0.07)
          border.width: 1
          border.color: current ? field.accent : field.line
          Text {
            id: choiceLabel
            anchors.centerIn: parent
            text: parent.modelData.name
            textFormat: Text.PlainText
            color: parent.current ? Color.background : field.foreground
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.caption
          }
          MouseArea {
            id: choiceArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: field.edited(parent.modelData.id)
          }
        }
      }
    }
  }

  // ----------------------------------------------------------------- color

  Component {
    id: colorC
    Column {
      spacing: Style.space(5)

      Flow {
        width: field.width
        spacing: Style.space(5)
        Repeater {
          model: D.COLOR_ROLES
          Rectangle {
            required property var modelData
            readonly property bool current: String(modelData.id) === String(field.value)
            width: Style.space(22)
            height: Style.space(22)
            radius: 4
            color: swatch.roleColor(modelData.id)
            border.width: current ? 2 : 1
            border.color: current ? field.accent : field.line
            DesignerSwatch { id: swatch }
            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              onClicked: field.edited(parent.modelData.id)
            }
          }
        }
      }

      Rectangle {
        width: field.width
        height: Style.space(24)
        radius: 4
        color: field.well
        border.width: 1
        border.color: hexEntry.activeFocus ? field.accent : field.line
        TextInput {
          id: hexEntry
          anchors.fill: parent
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(8)
          verticalAlignment: TextInput.AlignVCenter
          text: String(field.value || "").charAt(0) === "#" ? String(field.value) : ""
          color: field.foreground
          selectionColor: field.accent
          selectByMouse: true
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.caption
          onTextEdited: if (/^#[0-9A-Fa-f]{6}$/.test(text)) field.edited(text)
          Text {
            anchors.fill: parent
            verticalAlignment: Text.AlignVCenter
            visible: hexEntry.text.length === 0
            text: "or #rrggbb"
            color: field.muted
            font: hexEntry.font
          }
        }
      }
    }
  }

  // ------------------------------------------------------------------ bool

  Component {
    id: boolC
    // The switch keeps its own size; the Item around it takes the width the
    // Loader hands down.
    Item {
      implicitHeight: toggle.height

      Rectangle {
        id: toggle
        width: Style.space(46)
        height: Style.space(24)
        radius: height / 2
        color: field.value === true ? field.accent : field.well
        border.width: 1
        border.color: field.value === true ? field.accent : field.line
        Behavior on color { ColorAnimation { duration: 100 } }

        Rectangle {
          x: field.value === true ? parent.width - width - Style.space(3) : Style.space(3)
          anchors.verticalCenter: parent.verticalCenter
          width: parent.height - Style.space(6)
          height: width
          radius: width / 2
          color: field.value === true ? Color.background : field.foreground
          Behavior on x { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
        }

        MouseArea {
          anchors.fill: parent
          onClicked: field.edited(field.value !== true)
        }
      }
    }
  }

  // ------------------------------------------------------------------ file

  // ------------------------------------------------------------------- art

  // The drawing itself is block characters, so the row can show it as it is.
  Component {
    id: artC
    Row {
      spacing: Style.space(6)
      Rectangle {
        width: Style.space(70)
        height: Style.space(26)
        radius: 4
        color: drawArea.containsMouse ? Qt.rgba(field.foreground.r, field.foreground.g, field.foreground.b, 0.16) : field.well
        border.width: 1
        border.color: field.line
        Text {
          anchors.centerIn: parent
          text: "Draw…"
          color: field.foreground
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.caption
        }
        MouseArea {
          id: drawArea
          anchors.fill: parent
          hoverEnabled: true
          onClicked: field.drawArtRequested()
        }
      }

      Rectangle {
        width: field.width - Style.space(82)
        height: Style.space(48)
        radius: 4
        color: field.well
        border.width: 1
        border.color: field.line
        clip: true

        Text {
          id: artPreview
          anchors.centerIn: parent
          readonly property var lines: String(field.value || "").split("
")
          readonly property int cols: {
            var w = 0
            for (var i = 0; i < lines.length; i++) w = Math.max(w, lines[i].length)
            return Math.max(1, w)
          }
          text: String(field.value || "")
          textFormat: Text.PlainText
          color: field.foreground
          font.family: "monospace"
          // Shrunk to fit the row, whatever the drawing's size.
          font.pixelSize: Math.max(2, Math.min(
            Math.floor((parent.height - 6) / Math.max(1, lines.length) * 1.35),
            Math.floor((parent.width - 8) / cols * 1.9)))
          lineHeight: 0.74
          visible: String(field.value || "").length > 0
        }

        Text {
          anchors.centerIn: parent
          text: "nothing drawn yet"
          color: field.muted
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.caption
          visible: !artPreview.visible
        }
      }
    }
  }

  Component {
    id: fileC
    Row {
      spacing: Style.space(6)
      Rectangle {
        width: Style.space(70)
        height: Style.space(26)
        radius: 4
        color: browseArea.containsMouse ? Qt.rgba(field.foreground.r, field.foreground.g, field.foreground.b, 0.16) : field.well
        border.width: 1
        border.color: field.line
        Text {
          anchors.centerIn: parent
          text: "Choose…"
          color: field.foreground
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.caption
        }
        MouseArea {
          id: browseArea
          anchors.fill: parent
          hoverEnabled: true
          onClicked: field.pickFileRequested()
        }
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        width: field.width - Style.space(82)
        text: String(field.value || "").length > 0 ? String(field.value).split("/").pop() : "none"
        textFormat: Text.PlainText
        color: field.muted
        font.family: Style.font.menuFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideMiddle
      }
    }
  }

  // ------------------------------------------------------------------ code

  Component {
    id: codeC
    Rectangle {
      implicitHeight: Style.space(190)
      radius: 4
      color: field.well
      border.width: 1
      border.color: codeEdit.activeFocus ? field.accent : field.line
      clip: true

      Flickable {
        anchors.fill: parent
        anchors.margins: Style.space(8)
        contentWidth: Math.max(width, codeEdit.contentWidth)
        contentHeight: Math.max(height, codeEdit.contentHeight)
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        TextEdit {
          id: codeEdit
          width: Math.max(parent.width, contentWidth)
          text: String(field.value || "")
          textFormat: TextEdit.PlainText
          wrapMode: TextEdit.NoWrap
          selectByMouse: true
          color: field.foreground
          selectionColor: field.accent
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          tabStopDistance: font.pixelSize * 1.2
          // Rebuilding the snippet on every keystroke would flood the canvas
          // with half-typed QML; it goes in when the box is left, or on
          // Ctrl+Enter.
          onActiveFocusChanged: if (!activeFocus && text !== String(field.value || "")) field.edited(text)
          Keys.onPressed: function(event) {
            if ((event.modifiers & Qt.ControlModifier)
                && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
              field.edited(codeEdit.text)
              event.accepted = true
            } else if (event.key === Qt.Key_Tab) {
              codeEdit.insert(codeEdit.cursorPosition, "  ")
              event.accepted = true
            }
          }
        }
      }

      Text {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Style.space(6)
        text: "Ctrl+Enter applies"
        color: field.muted
        font.family: Style.font.menuFamily
        font.pixelSize: Style.font.caption
      }
    }
  }
}
