import QtQuick
import QtQuick.Effects
import qs.Commons

// The round user picture. Shows the avatar set with `omarchy-shell lock
// pickAvatar` (A in the explorer) and falls back to the user's initial when
// there is none, or when the file cannot be read.
Item {
  id: avatar

  // Usually driven by a DesignBase (`lock: lock`), but source/initial can be
  // set directly, which is what the explorer does for its header button.
  property var lock: null
  property string source: lock ? lock.avatarUrl : ""
  property string initial: lock ? lock.userInitial : "?"
  property color fillColor: Color.lock.borderActive
  property color textColor: Color.background
  property real fontScale: 0.5
  property int fontSize: Math.round(height * fontScale)
  property int borderWidth: 0
  property color borderColor: "transparent"
  property bool shadow: true
  property color shadowColor: Qt.rgba(0, 0, 0, 0.5)
  property int shadowOffset: 8

  readonly property bool showsImage: source.length > 0 && picture.status === Image.Ready

  width: 130
  height: width

  Item {
    id: content
    anchors.fill: parent
    layer.enabled: avatar.shadow
    layer.effect: MultiEffect {
      shadowEnabled: true
      shadowColor: avatar.shadowColor
      shadowBlur: 1.0
      shadowVerticalOffset: avatar.shadowOffset
    }

    Rectangle {
      anchors.fill: parent
      radius: width / 2
      color: avatar.fillColor
      antialiasing: true

      Text {
        anchors.centerIn: parent
        visible: !avatar.showsImage
        text: avatar.initial
        color: avatar.textColor
        font.family: Style.font.family
        font.pixelSize: avatar.fontSize
        font.weight: Font.Bold
      }
    }

    // Both bindings track the source and nothing else. Gating them on
    // Image.status instead would flip a layer on and off while the window is
    // mapping, and the image would never load while its item stayed hidden.
    Item {
      anchors.fill: parent
      visible: avatar.source.length > 0
      layer.enabled: avatar.source.length > 0
      layer.smooth: true
      layer.effect: MultiEffect {
        maskEnabled: true
        maskSource: circleMask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 0.05
      }

      Image {
        id: picture
        anchors.fill: parent
        source: avatar.source
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        smooth: true
        mipmap: true
        sourceSize.width: Math.round(avatar.width * 2)
        sourceSize.height: Math.round(avatar.height * 2)
      }
    }

    Rectangle {
      anchors.fill: parent
      radius: width / 2
      color: "transparent"
      antialiasing: true
      visible: avatar.borderWidth > 0
      border.width: avatar.borderWidth
      border.color: avatar.borderColor
    }

    Item {
      id: circleMask
      anchors.fill: parent
      visible: false
      layer.enabled: true
      Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: "white"
        antialiasing: true
      }
    }
  }
}
