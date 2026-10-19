import QtQuick
import QtQuick.Effects
import qs.Commons
import qs.Commons as Commons

// Receipt: the lock screen printed on till paper, in the theme's colours
// turned inside out. The date, the time, the user and the host are the
// lines, the password is the PIN line, a barcode encodes the date, and a
// wrong password gets the receipt stamped DECLINED.
DesignBase {
  id: lock
  inputItem: input
  shakeOnFail: true
  flashOnFail: false

  readonly property color paper: lock.withAlpha(Commons.Color.lock.text, 1)
  readonly property color ink: lock.withAlpha(Commons.Color.background, 1)
  readonly property color faint: lock.withAlpha(ink, 0.45)
  // The theme's error colour, unless it would vanish on the paper, which is
  // the theme's text colour; then the red a till really stamps in.
  readonly property color stamp: {
    var e = Commons.Color.lock.textError
    var lum = function(c) { return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b }
    return Math.abs(lum(e) - lum(paper)) > 0.3 ? e : "#c1272d"
  }
  readonly property int lit: passwordText.length
  readonly property int paperW: 380
  readonly property int mono: Style.font.bodySmall

  function pad(s, n) { s = String(s); while (s.length < n) s = " " + s; return s }
  function row(left, right) {
    var width = 30
    var gap = Math.max(1, width - left.length - right.length)
    var out = left
    for (var i = 0; i < gap; i++) out += " "
    return out + right
  }

  Wallpaper { anchors.fill: parent; lock: lock; blur: 1; dim: 0.55 }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: { lock.wakeRequested(); lock.forcePasswordFocus() }
    onPositionChanged: lock.wakeRequested()
  }

  LockInput {
    id: input
    lock: lock
    width: 1; height: 1
    opacity: 0
    anchors.centerIn: parent
  }

  Item {
    id: slip
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
    anchors.verticalCenterOffset: -10
    width: lock.paperW
    height: body.implicitHeight + 70
    rotation: -1.4
    layer.enabled: true
    layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Qt.rgba(0, 0, 0, 0.6); shadowBlur: 1.0; shadowVerticalOffset: 14 }

    Rectangle {
      anchors.fill: parent
      anchors.bottomMargin: 14
      color: lock.paper
    }
    // The torn bottom edge.
    Canvas {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      height: 14
      onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        ctx.clearRect(0, 0, width, height)
        ctx.fillStyle = lock.paper
        ctx.beginPath()
        ctx.moveTo(0, 0)
        var teeth = Math.round(width / 12)
        for (var i = 0; i <= teeth; i++) {
          var x = i * width / teeth
          ctx.lineTo(x, i % 2 === 0 ? 0 : 12)
        }
        ctx.lineTo(width, 0)
        ctx.closePath()
        ctx.fill()
      }
    }

    Column {
      id: body
      anchors.top: parent.top
      anchors.topMargin: 34
      anchors.horizontalCenter: parent.horizontalCenter
      width: lock.paperW - 56
      spacing: 4

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "O M A R C H Y"
        color: lock.ink
        font.family: Style.font.family
        font.pixelSize: Style.font.title
        font.weight: Font.Bold
      }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: lock.hostName.toUpperCase()
        textFormat: Text.PlainText
        color: lock.faint
        font.family: Style.font.family
        font.pixelSize: lock.mono
        font.letterSpacing: 2
      }
      Item { width: 1; height: 6 }
      Repeater {
        model: [
          "------------------------------",
          lock.row("DATE", lock.date("yyyy-MM-dd")),
          lock.row("TIME", lock.clock("HH:mm")),
          lock.row("DAY", lock.date("dddd").toUpperCase()),
          lock.row("USER", lock.userName.toUpperCase()),
          "------------------------------",
          lock.row("ITEM", "QTY"),
          lock.row("SESSION LOCK", "1"),
          lock.row("SCREEN", String(lock.width) + "x" + String(lock.height)),
          lock.batteryPercent >= 0 ? lock.row("BATTERY", String(lock.batteryPercent) + "%") : lock.row("POWER", "MAINS"),
          "------------------------------"
        ]
        Text {
          text: modelData
          textFormat: Text.PlainText
          color: modelData.charAt(0) === "-" ? lock.faint : lock.ink
          font.family: Style.font.family
          font.pixelSize: lock.mono
        }
      }

      // The PIN line: the password as dots in the ink, the cursor an
      // underscore, the characters once revealed.
      Item {
        width: parent.width
        height: 28
        Text {
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          text: lock.authenticatingPassword ? "PIN   PROCESSING..." : (lock.errorState ? "PIN   DECLINED" : "PIN")
          textFormat: Text.PlainText
          color: lock.errorState ? lock.stamp : lock.ink
          font.family: Style.font.family
          font.pixelSize: lock.mono
          font.weight: Font.Bold
        }
        Row {
          anchors.right: eye.left
          anchors.rightMargin: 8
          anchors.verticalCenter: parent.verticalCenter
          spacing: 5
          visible: !lock.authenticatingPassword && !lock.errorState
          Repeater {
            model: lock.passwordVisible ? 0 : Math.min(lock.lit, 20)
            Rectangle {
              width: 8; height: 8; radius: 4
              color: lock.ink
              Component.onCompleted: { scale = 0.2; popIn.start() }
              NumberAnimation on scale { id: popIn; from: 0.2; to: 1; duration: 120; easing.type: Easing.OutBack; running: false }
            }
          }
          Text {
            visible: lock.passwordVisible
            text: lock.passwordText
            textFormat: Text.PlainText
            color: lock.ink
            font.family: Style.font.family
            font.pixelSize: lock.mono
          }
          Rectangle {
            width: 9; height: 2
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 6
            color: lock.ink
            visible: lock.inputEnabled
            SequentialAnimation on opacity {
              loops: Animation.Infinite
              running: true
              NumberAnimation { from: 1; to: 0; duration: 450 }
              NumberAnimation { from: 0; to: 1; duration: 450 }
            }
          }
        }
        EyeButton {
          id: eye
          lock: lock
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          opacity: 0.7
        }
      }

      Repeater {
        model: [
          "------------------------------",
          lock.row("ATTEMPTS", String(lock.failedAttempts)),
          lock.row("TOTAL", lock.clock("HH:mm")),
          "------------------------------"
        ]
        Text {
          text: modelData
          textFormat: Text.PlainText
          color: modelData.charAt(0) === "-" ? lock.faint : lock.ink
          font.family: Style.font.family
          font.pixelSize: lock.mono
          font.weight: modelData.indexOf("TOTAL") === 0 ? Font.Bold : Font.Normal
        }
      }

      Item { width: 1; height: 8 }
      // A barcode for the date: the digits set the bar widths.
      Canvas {
        id: barcode
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - 20
        height: 46
        Connections { target: lock; function onNowChanged() { if (barcode.lastDay !== lock.date("yyyyMMdd")) barcode.requestPaint() } }
        property string lastDay: ""
        onPaint: {
          var ctx = getContext("2d")
          ctx.reset()
          ctx.clearRect(0, 0, width, height)
          var digits = lock.date("yyyyMMdd") + lock.hostName
          lastDay = lock.date("yyyyMMdd")
          ctx.fillStyle = lock.ink
          var x = 0
          var i = 0
          while (x < width - 2) {
            var c = digits.charCodeAt(i % digits.length)
            var w = 1 + (c % 4)
            var gap = 1 + ((c >> 2) % 3)
            ctx.fillRect(x, 0, w, height)
            x += w + gap
            i++
          }
        }
      }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: lock.date("yyyyMMdd") + " " + lock.clock("HHmm")
        textFormat: Text.PlainText
        color: lock.faint
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        font.letterSpacing: 4
      }
      Item { width: 1; height: 6 }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: lock.fingerprintConfigured ? lock.fingerprintHint(lock.tr("Type your password or touch the sensor")).toUpperCase() : lock.tr("Type your password").toUpperCase()
        textFormat: Text.PlainText
        color: lock.faint
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        font.letterSpacing: 1
      }
    }

    // The stamp a wrong password earns.
    Text {
      anchors.centerIn: parent
      anchors.verticalCenterOffset: -20
      rotation: 16
      visible: lock.failedAttempts > 0
      opacity: 0.85
      text: lock.tr("DECLINED")
      color: lock.stamp
      font.family: Style.font.family
      font.pixelSize: Math.round(Style.font.baseSize * 3)
      font.weight: Font.Black
      font.letterSpacing: 6
      Rectangle {
        anchors.fill: parent
        anchors.margins: -10
        color: "transparent"
        border.width: 4
        border.color: lock.stamp
      }
    }
  }

  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 36
    opacity: lock.snapshotMode ? 0 : 1
    text: lock.errorState ? lock.failureMessage : (lock.authenticatingPassword ? lock.tr("Checking…") : "")
    textFormat: Text.PlainText
    color: lock.errorState ? Commons.Color.lock.textError : lock.withAlpha(Commons.Color.lock.text, 0.6)
    font.family: Style.font.family
    font.pixelSize: Style.font.bodySmall
    font.letterSpacing: 1
  }
}
